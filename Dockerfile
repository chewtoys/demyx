FROM msoap/shell2http AS demyx_api
FROM docker:cli

LABEL sh.demyx.image demyx/demyx
LABEL sh.demyx.maintainer Demyx <info@demyx.sh>
LABEL sh.demyx.url https://demyx.sh
LABEL sh.demyx.github https://github.com/demyxsh
LABEL sh.demyx.registry https://hub.docker.com/u/demyx

# Set default environment variables
ENV DEMYX                               /demyx
ENV DEMYX_CONFIG                        /etc/demyx
ENV DEMYX_LOG                           /var/log/demyx
ENV DEMYX_APP                           "${DEMYX}/app"
ENV DEMYX_CODE                          "${DEMYX_APP}/code"
ENV DEMYX_TRAEFIK                       "${DEMYX_APP}/traefik"
ENV DEMYX_WP                            "${DEMYX_APP}/wp"
ENV DEMYX_PHP                           "${DEMYX_APP}/php"
ENV DEMYX_HTML                          "${DEMYX_APP}/html"
ENV DEMYX_BACKUP                        "${DEMYX}/backup"
ENV DEMYX_BACKUP_WP                     "${DEMYX_BACKUP}/wp"
ENV DEMYX_FUNCTION                      "${DEMYX_CONFIG}/function"
ENV DEMYX_TMP                           "${DEMYX}/tmp"
ENV DEMYX_API                           false
ENV DEMYX_AUTH_USERNAME                 demyx
ENV DEMYX_AUTH_PASSWORD                 demyx
ENV DEMYX_BACKUP_ENABLE                 true
ENV DEMYX_BACKUP_LIMIT                  7
ENV DEMYX_CODE_DOMAIN                   code
ENV DEMYX_CODE_ENABLE                   false
ENV DEMYX_CODE_PASSWORD                 demyx
ENV DEMYX_CODE_SSL                      false
ENV DEMYX_CF_KEY                        false
ENV DEMYX_CPU                           0
ENV DEMYX_DOMAIN                        localhost
ENV DEMYX_EMAIL                         info@localhost
ENV DEMYX_HEALTHCHECK                   true
ENV DEMYX_HEALTHCHECK_DISK              /demyx
ENV DEMYX_HEALTHCHECK_DISK_THRESHOLD    80
ENV DEMYX_HEALTHCHECK_LOAD              10
ENV DEMYX_HOSTNAME                      demyx
ENV DEMYX_IP                            false
ENV DEMYX_LOGROTATE                     daily
ENV DEMYX_LOGROTATE_INTERVAL            7
ENV DEMYX_LOGROTATE_SIZE                10M
ENV DEMYX_MATRIX                        false
ENV DEMYX_MATRIX_KEY                    false
ENV DEMYX_MATRIX_URL                    false
ENV DEMYX_MEM                           0
ENV DEMYX_MODE                          stable
ENV DEMYX_SERVER_IP                     false
ENV DEMYX_SMTP                          false
ENV DEMYX_SMTP_HOST                     false
ENV DEMYX_SMTP_FROM                     false
ENV DEMYX_SMTP_PASSWORD                 false
ENV DEMYX_SMTP_USERNAME                 false
ENV DEMYX_SMTP_TO                       false
ENV DEMYX_TELEMETRY                     true
ENV DEMYX_TRAEFIK_LOG                   INFO
ENV DEMYX_TRAEFIK_SSL                   false
ENV DEMYX_VERSION                       1.9.1
ENV DOCKER_HOST                         tcp://demyx_socket:2375
ENV TZ                                  America/Los_Angeles

# Install custom packages
RUN set -ex; \
    apk add --no-cache --update \
    apache2-utils \
    bash \
    bind-tools \
    curl \
    jq \
    htop \
    logrotate \
    nano \
    ssmtp \
    sudo \
    tzdata \
    util-linux

# Copy files and binaries
COPY . /etc/demyx
COPY --from=demyx_api /app/shell2http /usr/local/bin/shell2http

# Configure Demyx
RUN set -ex; \
    addgroup -g 1000 -S demyx; \
    adduser -u 1000 -D -S -G demyx demyx; \
    \
    install -d -m 0755 -o demyx -g demyx "$DEMYX"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_BACKUP"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_BACKUP_WP"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_CODE"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_CONFIG"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_HTML"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_LOG"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_PHP"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_TMP"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_TRAEFIK"; \
    install -d -m 0755 -o demyx -g demyx "$DEMYX_WP"; \
    \
    # Update .bashrc
    echo 'PS1="$(whoami)@\h:\w \$ "' > /home/demyx/.bashrc; \
    echo 'PS1="$(whoami)@\h:\w \$ "' > /root/.bashrc; \
    \
    echo "$DEMYX_HOSTNAME" /etc/hostname; \
    \
    ln -s "$DEMYX" /home/demyx; \
    ln -s "$DEMYX_LOG" "$DEMYX"/log

# Configure sudo
RUN set -ex; \
    echo -e "demyx ALL=(ALL) NOPASSWD:SETENV: /etc/demyx/bin/demyx.sh, /usr/local/bin/demyx-entrypoint, /etc/demyx/bin/demyx-yml.sh" > /etc/sudoers.d/demyx; \
    \
    echo '#!/bin/bash' > /usr/local/bin/demyx; \
    echo 'sudo -E /etc/demyx/bin/demyx.sh "$@"' >> /usr/local/bin/demyx; \
    chmod +x /usr/local/bin/demyx; \
    \
    echo '#!/bin/bash' > /usr/local/bin/demyx-yml; \
    echo 'sudo -E /etc/demyx/bin/demyx-yml.sh "$@"' >> /usr/local/bin/demyx-yml; \
    chmod +x /usr/local/bin/demyx-yml; \
    \
    # Supresses the sudo warning for now
    echo "Set disable_coredump false" > /etc/sudo.conf

# Set cron and log
RUN set -ex; \
    echo -e "SHELL=/bin/bash\n\
        * * * * * demyx cron minute\n\
        */5 * * * * demyx cron five-minute\n\
        0 * * * * demyx cron hourly\n\
        0 */6 * * * demyx cron six-hour\n\
        0 0 * * * demyx cron daily\n\
        0 0 * * 0 demyx cron weekly\n\
    " | sed "s|    ||g" > /etc/crontabs/demyx; \
    \
    echo -e "${DEMYX_LOG}/*.log {\n\
        create\n\
        missingok\n\
        notifempty\n\
        ${DEMYX_LOGROTATE}\n\
        rotate ${DEMYX_LOGROTATE_INTERVAL}\n\
        compress\n\
        delaycompress\n\
        size ${DEMYX_LOGROTATE_SIZE}\n\
        postrotate\n\
            /usr/local/bin/docker kill --signal=USR1 demyx_traefik\n\
        endscript\n\
    }" | sed "s|    ||g" > "$DEMYX_CONFIG"/logrotate.conf

# Finalize
RUN set -ex; \
    # Lockdown
    chmod o-x /bin/busybox; \
    chmod o-x /bin/echo; \
    chmod o-x /usr/bin/curl; \
    chmod o-x /usr/bin/nano; \
    chmod o-x /usr/local/bin/docker; \
    \
    # Copy custom directory
    cp -r "$DEMYX_CONFIG"/custom "$DEMYX"; \
    \
    # Entrypoint
    mv "$DEMYX_CONFIG"/bin/demyx-entrypoint.sh /usr/local/bin/demyx-entrypoint; \
    \
    # Set ownership
    chown -R demyx:demyx "$DEMYX"; \
    chown -R root:root /usr/local/bin

EXPOSE 8080

WORKDIR "$DEMYX"

USER demyx

ENTRYPOINT ["sudo", "-E", "demyx-entrypoint"]

# Build date
ARG DEMYX_BUILD
ENV DEMYX_BUILD "$DEMYX_BUILD"
