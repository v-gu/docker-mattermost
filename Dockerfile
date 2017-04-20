# TODO maybe base on the official go image
FROM alpine:3.5

ENV MATTERMOST_VERSION=3.8.1 \
    MATTERMOST_DATA_DIR="/opt/mattermost/data" \
    MATTERMOST_BUILD_DIR="/opt/mattermost/build" \
    MATTERMOST_RUNTIME_DIR="/opt/mattermost/runtime" \
    MATTERMOST_INSTALL_DIR="/opt/mattermost/mattermost" \
    MATTERMOST_CONF_DIR="/opt/mattermost/config" \
    \
    MM_SERVICESETTINGS_LISTENADDRESS=:80 \
    MM_LOGSETTINGS_CONSOLE_LEVEL=INFO \
    MM_LOGSETTINGS_ENABLEFILE=false \
    MM_PASSWORDSETTINGS_MINIMUMLENGTH=12

RUN apk --no-cache add \
    bash gettext mysql-client postgresql-client ca-certificates tini

# TODO include build procedure here
COPY assets/build/ ${MATTERMOST_BUILD_DIR}/
RUN bash ${MATTERMOST_BUILD_DIR}/install.sh

COPY entrypoint.sh /

EXPOSE 80/tcp

VOLUME ["${MATTERMOST_DATA_DIR}"]
WORKDIR ${MATTERMOST_INSTALL_DIR}
ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
CMD ["server"]
