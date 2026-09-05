FROM docker.io/searxng/searxng:latest

USER root

COPY --chown=977:977 index.html /usr/local/searxng/searx/templates/simple/index.html
COPY --chown=977:977 searxng/settings.yml /etc/searxng/settings.yml
COPY --chmod=755 docker/interkid-entrypoint.sh /usr/local/bin/interkid-entrypoint

ENV SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/interkid-entrypoint"]
