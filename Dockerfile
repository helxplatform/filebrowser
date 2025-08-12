FROM debian:bullseye-slim

# Copy files and set permissions
COPY filebrowser /bin/filebrowser
RUN chmod +x /bin/filebrowser && cp /bin/filebrowser /filebrowser

COPY docker/common/ /tmp/common/
COPY docker/debian/ /tmp/debian/
RUN find /tmp/common /tmp/debian -type f -name "*.sh" -exec chmod +x {} \; && \
  cp -r /tmp/common/* / && \
  cp -r /tmp/debian/* /

# Update package list and install required packages
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates \
    media-types \
    wget \
    tini \
    trash-cli

# Libnss-ldap removed on bookworm, manually install from archive
RUN wget https://ftp.debian.org/debian/pool/main/libn/libnss-ldap/libnss-ldap_265-6_amd64.deb && \
  wget https://ftp.debian.org/debian/pool/main/o/openldap/libldap-2.4-2_2.4.47+dfsg-3+deb10u7_amd64.deb && \
  apt-get install -y "./libldap-2.4-2_2.4.47+dfsg-3+deb10u7_amd64.deb" "./libnss-ldap_265-6_amd64.deb"


HEALTHCHECK --start-period=2s --interval=5s --timeout=3s CMD /healthcheck.sh || exit 1

VOLUME /srv /config /database

EXPOSE 80

ENTRYPOINT [ "tini", "--", "/init.sh" ]
CMD [ "/filebrowser", "--config", "/config/settings.json" ]
