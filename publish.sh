#!/bin/sh
set -e
set -o pipefail

if [ -n "$DEBUG$PLUGIN_DEBUG" ]; then
    set -x
fi

source tags.sh

if [ "$1" = "--tags" ]; then
    >&2 echo -e "Running in --tags test mode"
    shift
    printf "%s\n" "$@" | parse_tags | xargs -n 1 | sort -u
    exit 0
fi

if echo "$DRONE_COMMIT_MESSAGE" | grep -qiF -e "[PUBLISH SKIP]" -e "[SKIP PUBLISH]"; then
    >&2 echo -e "Skipping publish"
    exit 0
fi

# $PLUGIN_SRC_TEMPLATE Template to match the architecture images
# $PLUGIN_SRC_REGISTRY source registry to pull the image from
# $PLUGIN_SRC_USERNAME username of the source repository
# $PLUGIN_SRC_PASSWORD password of the source repository
# $PLUGIN_PLATFORMS Architectures to publish
# $PLUGIN_DEST_REPO  tag to this repo/repo to push to
# $PLUGIN_DEST_REGISTRY destination registry to push the image to
# $PLUGIN_DEST_USERNAME username of the push repository
# $PLUGIN_DEST_PASSWORD password of the push repository
# $PLUGIN_TAGS  newline or comma separated list of tags to push images with
# $PLUGIN_INSECURE allow plain http requests to either registry


# Set up the credential strings if present
if [ -n "${PLUGIN_DEST_USERNAME}" ]; then
    if [ -z "${PLUGIN_DEST_PASSWORD}" ]; then
      error "Missing password for 'to' username"
    fi

    DEST_CREDS="--dest-creds ${PLUGIN_DEST_USERNAME}:${PLUGIN_DEST_PASSWORD}"
fi

if [ -n "${PLUGIN_SRC_USERNAME}" ]; then
    if [ -z "${PLUGIN_SRC_PASSWORD}" ]; then
      error "Missing password for 'from' username"
    fi

    SRC_CREDS="--src-creds ${PLUGIN_SRC_USERNAME}:${PLUGIN_SRC_PASSWORD}"
fi

# Check for the rest of the required env vars
if [ -z "${PLUGIN_SRC_TEMPLATE}" ]; then
    error "Missing required templated repo names for pushing"
fi
if [ -n "${PLUGIN_SRC_REGISTRY}" ]; then
    PLUGIN_SRC_TEMPLATE="$PLUGIN_SRC_REGISTRY/$PLUGIN_SRC_TEMPLATE"
fi

if [ -z "${PLUGIN_DEST_REPO}" ]; then
    error "missing 'repo' argument required for publishing"
fi
if [ -n "${PLUGIN_DEST_REGISTRY}" ]; then
    PLUGIN_DEST_REPO="$PLUGIN_DEST_REGISTRY/$PLUGIN_DEST_REPO"
fi

if [ -z "${PLUGIN_PLATFORMS}" ]; then
  # Default to x86 & arm64 if not specified
  PLUGIN_PLATFORMS="linux/amd64,linux/arm64"
fi

if [ -n "${PLUGIN_INSECURE}" ]; then
  MT_INSECURE="--plain-http"
  SKOPEO_INSECURE="--src-tls-verify=false --dest-tls-verify=false"
fi

# Generate a random image name with latest tag to temporarily hold the manifest
MANIFEST_REPO="${PLUGIN_SRC_TEMPLATE//ARCH/$(uuidgen)}"
# Append a default tag if one isn't specified. manifest-tool requires a tag
if echo "${MANIFEST_REPO##*/}" | grep -qv ':'; then
    MANIFEST_REPO="$MANIFEST_REPO:latest"
fi

# Combine the architecture specific images with manifest-tool
printf "Combining into '%s' with manifest-tool...\n" "${MANIFEST_REPO}"
manifest-tool $MT_INSECURE push from-args \
    --platforms ${PLUGIN_PLATFORMS} \
    --template ${PLUGIN_SRC_TEMPLATE} \
    --target "${MANIFEST_REPO}"

# Ensure at least one tag exists
if [ -z "${PLUGIN_TAGS}" ]; then
    # Take into account the case where the repo already has the tag appended
    if echo "${PLUGIN_DEST_REPO}" | grep -q ':'; then
        TAGS="${PLUGIN_DEST_REPO#*:}"
        PLUGIN_DEST_REPO="${PLUGIN_DEST_REPO%:*}"
    else
        # If none specified, assume 'latest'
        TAGS="latest"
    fi
else
    # Parse and process dynamic tags
    TAGS="$(echo "${PLUGIN_TAGS}" | tr ',' '\n' | parse_tags | xargs -n 1 | sort -u | xargs)"
fi

# Push all images with scopeo
for tag in $TAGS; do
    printf "Pushing manifest with tag '%s'...\n" "$tag"
    skopeo copy \
        --multi-arch all \
        ${SKOPEO_INSECURE} \
        ${DEST_CREDS} ${SRC_CREDS} \
        "docker://${MANIFEST_REPO}" \
        "docker://${PLUGIN_DEST_REPO}:$tag"
    printf "\n"
done

docker rmi "${MANIFEST_REPO}" >/dev/null 2>/dev/null || true
