FROM alpine:3.22

ARG VCS_REF

LABEL org.opencontainers.image.authors="Spritsail <docker-plugin@spritsail.io>" \
      org.opencontainers.image.title="docker-multiarch-publish" \
      org.opencontainers.image.description="A Drone CI plugin for tagging and pushing built multiarch Docker images" \
      org.opencontainers.image.version=${VCS_REF}

ADD --chmod=755 *.sh /usr/local/bin/
RUN apk --no-cache add curl jq pwgen skopeo \
 && apk --no-cache add --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing manifest-tool

ENTRYPOINT [ "/usr/local/bin/publish.sh" ]
