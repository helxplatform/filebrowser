# Use Go base image
FROM golang:1.24-bookworm

# Make user and create necessary directories
ENV UID=1000
ENV GID=1000

RUN groupadd -g $GID user && \
  useradd -m -u $UID -g user user && \
  mkdir -p /config /database /srv && \
  chown -R user:user /config /database /srv

# Copy files and set permissions
COPY filebrowser /bin/filebrowser
COPY filebrowser /filebrowser
COPY docker/common/ /
COPY docker/debian/ /

RUN chmod +x /bin/filebrowser /filebrowser /healthcheck.sh /init.sh && \
  chown -R user:user /bin/filebrowser /defaults /healthcheck.sh /init.sh

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs

# Verify Node.js installation
RUN node -v && npm -v

# Update package list and install required packages
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates mailcap curl jq tini libnss-ldap


HEALTHCHECK --start-period=2s --interval=5s --timeout=3s CMD /healthcheck.sh || exit 1

USER user

VOLUME /srv /config /database

EXPOSE 80

ENTRYPOINT [ "tini", "--", "/init.sh" ]
CMD [ "/filebrowser", "--config", "/config/settings.json" ]
