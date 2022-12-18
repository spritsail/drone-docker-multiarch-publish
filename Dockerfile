FROM alpine:3.17

ARG VCS_REF
ARG MANIFEST_VER="2.0.3"

LABEL org.opencontainers.image.authors="Spritsail <docker-plugin@spritsail.io>" \
      org.opencontainers.image.title="docker-multiarch-publish" \
      org.opencontainers.image.description="A Drone CI plugin for tagging and pushing built multiarch Docker images" \
      org.opencontainers.image.version=${VCS_REF} \
      io.spritsail.version.manifest-tool=${MANIFEST_VER}

ADD *.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh \
 && apk --no-cache add curl jq skopeo pwgen \
 && wget -O - https://github.com/estesp/manifest-tool/releases/download/v${MANIFEST_VER}/binaries-manifest-tool-${MANIFEST_VER}.tar.gz | tar -xz -C /usr/local/bin manifest-tool-linux-amd64 \
 && mv /usr/local/bin/manifest-tool-linux-amd64 /usr/local/bin/manifest-tool

ENTRYPOINT [ "/usr/local/bin/publish.sh" ]
