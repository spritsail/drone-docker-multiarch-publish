#!/bin/sh
set -ex
set -o pipefail

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

# $PLUGIN_FROM_REPO name of the private combined repo
# $PLUGIN_FROM_TEMPLATE Template to match the architecture images
# $PLUGIN_FROM_USERNAME username of the source repository
# $PLUGIN_FROM_PASSWORD password of the source repository
# $PLUGIN_PLATFORMS Architectures to publish
# $PLUGIN_TO_REPO  tag to this repo/repo to push to
# $PLUGIN_TO_USERNAME username of the push repository
# $PLUGIN_TO_PASSWORD password of the push repository
# $PLUGIN_TAGS  newline or comma separated list of tags to push images with
# $PLUGIN_INSECURE allow plain http requests to either registry


# Set up the credential strings if present
if [ -n "${PLUGIN_TO_USERNAME}" ]; then
    if [ -z "${PLUGIN_TO_PASSWORD}" ]; then
      error "Missing password for 'to' username"
    fi

    TO_CREDS="--dest-creds ${PLUGIN_TO_USERNAME}:${PLUGIN_TO_PASSWORD}"
fi

if [ -n "${PLUGIN_FROM_USERNAME}" ]; then
    if [ -z "${PLUGIN_FROM_PASSWORD}" ]; then
      error "Missing password for 'from' username"
    fi

    FROM_CREDS="--src-creds ${PLUGIN_FROM_USERNAME}:${PLUGIN_FROM_PASSWORD}"
fi

# Check for the rest of the required env vars
if [ -z "${PLUGIN_FROM_REPO}" ]; then
    error "Missing required manifested repo name for pushing"
fi

if [ -z "${PLUGIN_FROM_TEMPLATE}" ]; then
    error "Missing required templated repo names for pushing"
fi

if [ -z "${PLUGIN_TO_REPO}" ]; then
    error "missing 'repo' argument required for publishing"
fi

if [ -z "${PLUGIN_PLATFORMS}" ]; then
  # Default th x86 & arm64 if not specified
  PLUGIN_PLATFORMS="linux/amd64,linux/arm64"
fi

if [ -n "${PLUGIN_INSECURE}" ]; then
  MT_INSECURE="--plain-http"
  SKOPEO_INSECURE="--src-tls-verify=false --dest-tls-verify=false"
fi

SRC_REPO="$PLUGIN_FROM_REPO"
export SRC_REPO

# Combine the architecture specific images with manifest-tool
printf "Combining into '%s' with manifest-tool...\n" "${SRC_REPO}"
manifest-tool $MT_INSECURE push from-args --platforms ${PLUGIN_PLATFORMS} --template ${PLUGIN_FROM_TEMPLATE} --target "${SRC_REPO}:latest"

# Ensure at least one tag exists
if [ -z "${PLUGIN_TAGS}" ]; then
    # Take into account the case where the repo already has the tag appended
    if echo "${PLUGIN_TO_REPO}" | grep -q ':'; then
        TAGS="${PLUGIN_TO_REPO#*:}"
        PLUGIN_TO_REPO="${PLUGIN_TO_REPO%:*}"
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
    printf "Pushing tag '%s'...\n" "$tag"
    skopeo copy --multi-arch all $SKOPEO_INSECURE ${TO_CREDS} ${FROM_CREDS} "docker://${SRC_REPO}:latest" "docker://${PLUGIN_TO_REPO}:$tag"
    printf "\n"
done
docker rmi "${SRC_REPO}" >/dev/null 2>/dev/null || true
