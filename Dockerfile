FROM debian:trixie-slim

USER root

# Set filebrowser env vars:
ENV FB_AUTH_METHOD="noauth"
ENV FB_NOAUTH=true

# Copy the filebrowser binary, scripts, and settings
COPY --chmod=0755 filebrowser /
COPY --chmod=0755 docker/debian/ /
COPY --chmod=0755 docker/common/healthcheck.sh /
COPY --chmod=0666 docker/common/defaults/settings.json /

# Update package list and install required packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
       ca-certificates \
       media-types \
       wget \
       ldap-utils \
       libnss-ldapd \
       procps \
       curl \
       jq \
       tini \
       trash-cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# NSS LDAP resolution is provided by the injected nslcd sidecar (nss-pam-ldapd):
# this image only needs the thin libnss-ldapd client (installed above), which
# talks to the sidecar over the shared /var/run/nslcd/socket. The retired
# libnss-ldap (EOL, hand-pulled deb11 .debs) is no longer used.

HEALTHCHECK --start-period=2s --interval=5s --timeout=3s CMD /healthcheck.sh || exit 1

VOLUME /srv /database

EXPOSE 80

ENTRYPOINT [ "tini", "--", "/init.sh" ]
CMD [ "/filebrowser", "--root=$ROOT_DIR", "--address=0.0.0.0", "--port=8080", "-d=$HOME/.filebrowser/filebrowser.db", "-c=/settings.json" ]