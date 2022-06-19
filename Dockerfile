FROM alpine:3.16

ARG VCS_REF
ARG MANIFEST_VER="2.0.3"

LABEL maintainer="Spritsail <docker-plugin@spritsail.io>" \
      org.label-schema.vendor="Spritsail" \
      org.label-schema.name="docker-multiarch-publish" \
      org.label-schema.description="A Drone CI plugin for tagging and pushing built multiarch Docker images" \
      org.label-schema.version=${VCS_REF} \
      io.spritsail.version.manifest-tool=${MANIFEST_VER}

ADD *.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh \
 && apk --no-cache add curl jq skopeo pwgen \
 && wget -O - https://github.com/estesp/manifest-tool/releases/download/v${MANIFEST_VER}/binaries-manifest-tool-${MANIFEST_VER}.tar.gz | tar -xz -C /usr/local/bin manifest-tool-linux-amd64 \
 && mv /usr/local/bin/manifest-tool-linux-amd64 /usr/local/bin/manifest-tool

ENTRYPOINT [ "/usr/local/bin/publish.sh" ]
