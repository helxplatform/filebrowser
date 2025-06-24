#########################
# Go base builder stage #
#########################
FROM golang:1.24-bookworm as builder

WORKDIR /src

COPY filebrowser /src/filebrowser
COPY docker/common/ /src/common
COPY docker/debian /src/debian

# Possibly build from source here...

##########################
# Production image stage #
##########################
FROM debian:bookworm-slim

# Copy files and set permissions
COPY --from=builder /src/filebrowser /bin/filebrowser
COPY --from=builder /src/filebrowser /filebrowser
COPY --from=builder /src/common/ /
COPY --from=builder /src/debian/ /

RUN chmod +x /bin/filebrowser /filebrowser /healthcheck.sh /init.sh

# Update package list and install required packages
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates \
    media-types \
    wget \
    tini \
    libnss-ldap && \
  apt-get clean


HEALTHCHECK --start-period=2s --interval=5s --timeout=3s CMD /healthcheck.sh || exit 1

VOLUME /srv /config /database

EXPOSE 80

ENTRYPOINT [ "tini", "--", "/init.sh" ]
CMD [ "/filebrowser", "--config", "/config/settings.json" ]
