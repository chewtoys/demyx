# Demyx
# https://demyx.sh
# shellcheck shell=bash

#
#   demyx cron <args>
#
demyx_cron() {
    demyx_event
    demyx_source "
        backup
        log
        healthcheck
        monitor
        update
        wp
    "

    case "$DEMYX_ARG_2" in
        daily)
            demyx_cron_daily
        ;;
        five-minute)
            demyx_cron_five_minute
        ;;
        hourly)
            demyx_cron_hourly
        ;;
        minute)
            demyx_cron_minute
        ;;
        six-hour)
            demyx_cron_six_hour
        ;;
        weekly)
            demyx_cron_weekly
        ;;
        *)
            demyx_help cron
        ;;
    esac
}
#
#   Daily cron.
#
demyx_cron_daily() {
    demyx_event
    local DEMYX_CRON_DAILY_I=
    local DEMYX_CRON_DAILY_WP_CHECK=

    if [[ "$DEMYX_TELEMETRY" = true ]]; then
        demyx_execute "[CROND DAILY] Pinging home" \
            "curl -s \"https://demyx.sh/?action=active&version=${DEMYX_VERSION}&token=V1VpdGNPcWNDVlZSUDFQdFBaR0Zhdz09OjrnA1h6ZbDFJ2T6MHOwg3p4\" -o /dev/null -w \"%{http_code}\""
    fi

    # Backup demyx system and configs
    demyx_execute "[CROND DAILY] Backing up system" \
        "mkdir -p ${DEMYX_TMP}/system; \
        cp -pr $DEMYX_APP ${DEMYX_TMP}/system; \
        docker cp demyx_traefik:/demyx ${DEMYX_TMP}/system/traefik; \
        demyx_proper ${DEMYX_TMP}/system; \
        tar -czf ${DEMYX_BACKUP}/system-${DEMYX_HOSTNAME}.tgz -C ${DEMYX_TMP} system; \
        rm -rf ${DEMYX_TMP}/system"

    if [[ "$DEMYX_BACKUP_ENABLE" = true ]]; then
        # Backup WordPress sites at midnight
        demyx_backup all

        # Delete backups older than X amounts of days
        find "$DEMYX_BACKUP_WP" -name "*.tgz" -type f -mtime +"${DEMYX_BACKUP_LIMIT}" -delete
    fi

    # WP auto update
    cd "$DEMYX_WP" || exit

    for DEMYX_CRON_DAILY_I in *; do
        DEMYX_ARG_2="$DEMYX_CRON_DAILY_I"

        demyx_app_env wp "
            DEMYX_APP_STACK
            DEMYX_APP_TYPE
            DEMYX_APP_WP_CONTAINER
            DEMYX_APP_WP_UPDATE
        "

        if [[ "$DEMYX_APP_WP_UPDATE" = true ]]; then
            if [[ "$DEMYX_APP_STACK" = bedrock || "$DEMYX_APP_STACK" = ols-bedrock ]]; then
                demyx_execute "[CROND DAILY - ${DEMYX_CRON_DAILY_I}] Executing composer update" \
                    "docker exec -t $DEMYX_APP_WP_CONTAINER composer update --no-interaction"
            else
                demyx_execute "[CROND DAILY - ${DEMYX_CRON_DAILY_I}] Updating WordPress core, themes, and plugins" \
                    "demyx_wp $DEMYX_CRON_DAILY_I core update; \
                    demyx_wp $DEMYX_CRON_DAILY_I plugin update --all"

                # A roundabout way to handle wp-cli nonexistent error
                DEMYX_CRON_DAILY_WP_CHECK="$(docker exec "$DEMYX_APP_WP_CONTAINER" wp theme update --all 2>&1 || true)"
                if [[ "$DEMYX_CRON_DAILY_WP_CHECK" == *"Success"* || "$DEMYX_CRON_DAILY_WP_CHECK" == *"No themes updated"* ]]; then
                    docker exec "$DEMYX_APP_WP_CONTAINER" wp theme update --all
                else
                    docker exec "$DEMYX_APP_WP_CONTAINER" wp theme update --all
                fi
            fi
        fi
    done

    # Rotate demyx logs
    demyx_execute "[CROND DAILY] Rotating logs" \
        "logrotate --log=${DEMYX_LOG}/logrotate.log ${DEMYX_CONFIG}/logrotate.conf"

    # Execute custom cron
    if [[ -f "$DEMYX"/custom/cron/daily.sh ]]; then
        demyx_execute "[CROND DAILY] Executing ${DEMYX}/custom/cron/daily.sh" \
            "bash ${DEMYX}/custom/cron/daily.sh"
    fi
}
#
#   Every five minute cron.
#
demyx_cron_five_minute() {
    demyx_event
    # Healthchecks
    demyx_execute "[CROND FIVE-MINUTE] Healthcheck - App" \
        "demyx_healthcheck app"
    demyx_execute "[CROND FIVE-MINUTE] Healthcheck - Load" \
        "demyx_healthcheck load"

    # Execute custom cron
    if [[ -f "$DEMYX"/custom/cron/five-minute.sh ]]; then
        demyx_execute "[CROND FIVE-MINUTE] Executing ${DEMYX}/custom/cron/five-minute.sh" \
            "bash ${DEMYX}/custom/cron/five-minute.sh"
    fi
}
#
#   Hourly cron.
#
demyx_cron_hourly() {
    demyx_event

    # Disk healthcheck
    demyx_execute "[CROND DAILY] Healthcheck - Disk" \
        "demyx_healthcheck disk"

    # Execute custom cron
    if [[ -f "$DEMYX"/custom/cron/hourly.sh ]]; then
        demyx_execute "[CROND HOURLY] Executing ${DEMYX}/custom/cron/hourly.sh" \
            "bash ${DEMYX}/custom/cron/hourly.sh"
    fi
}
#
#   Every minute cron.
#
demyx_cron_minute() {
    demyx_event
    # Execute custom cron
    if [[ -f "$DEMYX"/custom/cron/minute.sh ]]; then
        demyx_execute "[CROND MINUTE] Executing ${DEMYX}/custom/cron/minute.sh" \
            "bash ${DEMYX}/custom/cron/minute.sh"
    fi
}
#
#   Every six hour cron.
#
demyx_cron_six_hour() {
    demyx_event
    # Execute custom cron
    if [[ -f "$DEMYX"/custom/cron/six-hour.sh ]]; then
        demyx_execute "[CROND SIX-HOUR] Executing ${DEMYX}/custom/cron/six-hour.sh" \
            "bash ${DEMYX}/custom/cron/six-hour.sh"
    fi
}
#
#   Every week cron.
#
demyx_cron_weekly() {
    demyx_event

    if [[ "${DEMYX_MODE}" = stable ]]; then
        # Check for updates
        demyx_execute "[CROND WEEKLY] Updating cache" \
            "demyx_update"
    fi

    # Execute custom cron
    if [[ -f "$DEMYX"/custom/cron/weekly.sh ]]; then
        demyx_execute "[CROND WEEKLY] Executing ${DEMYX}/custom/cron/weekly.sh" \
            "bash ${DEMYX}/custom/cron/weekly.sh"
    fi
}
