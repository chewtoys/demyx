# Demyx
# https://demyx.sh
#
#   demyx log <app> <args>
#
demyx_log() {
    DEMYX_ARG_2="${1:-$DEMYX_ARG_2}"
    local DEMYX_LOG_FLAG=
    local DEMYX_LOG_FLAG_CRON=
    local DEMYX_LOG_FLAG_DATABASE=
    local DEMYX_LOG_FLAG_ERROR=
    local DEMYX_LOG_FLAG_FOLLOW=
    local DEMYX_LOG_TAIL_FLAG=-200
    local DEMYX_LOG_STDOUT_FLAG=

    while :; do
        DEMYX_LOG_FLAG="${2:-}"
        case "$DEMYX_LOG_FLAG" in
            -c|-cf|-fc)
                DEMYX_LOG_FLAG_CRON=true

                if [[ "$DEMYX_LOG_FLAG" = -cf || "$DEMYX_LOG_FLAG" = -fc ]]; then
                    DEMYX_LOG_FLAG_FOLLOW=true
                fi
            ;;
            -d|-df|-fd)
                DEMYX_LOG_FLAG_DATABASE=true

                if [[ "$DEMYX_LOG_FLAG" = -df || "$DEMYX_LOG_FLAG" = -fd ]]; then
                    DEMYX_LOG_FLAG_FOLLOW=true
                fi
                ;;
            -e|-ef|-fe)
                DEMYX_LOG_FLAG_ERROR=true

            if [[ "$DEMYX_LOG_FLAG" = -ef || "$DEMYX_LOG_FLAG" = -fe ]]; then
                DEMYX_LOG_FLAG_FOLLOW=true
            fi
                ;;
            -f)
                DEMYX_LOG_FLAG_FOLLOW=true
                ;;
            -s|-sf|-fs)
                DEMYX_LOG_STDOUT_FLAG=true

                if [[ "$DEMYX_LOG_FLAG" = -sf || "$DEMYX_LOG_FLAG" = -fs ]]; then
                    DEMYX_LOG_FLAG_FOLLOW=true
                fi
                ;;
            --)
                shift
                break
                ;;
            -?*)
                demyx_error flag "$DEMYX_LOG_FLAG"
                ;;
            *)
                break
        esac
        shift
    done

    if [[ "$DEMYX_LOG_FLAG_FOLLOW" = true ]]; then
        DEMYX_LOG_TAIL_FLAG=-f
        DEMYX_LOG_FLAG_FOLLOW=-f
    fi

    case "$DEMYX_ARG_2" in
        cron)
            demyx_log_cron
        ;;
        main)
            demyx_log_main
        ;;
        traefik)
            demyx_log_traefik
        ;;
        *)
            if [[ -n "$DEMYX_ARG_2" ]]; then
                demyx_arg_valid
                demyx_log_app "$DEMYX_ARG_2"
            else
                demyx_help log
            fi
        ;;
    esac
}
        else
            tail -200 $DEMYX_LOG_FOLLOW /var/log/demyx/traefik.access.log
        fi
    elif [[ "$DEMYX_APP_TYPE" = wp ]]; then
        if [[ -n "$DEMYX_LOG_ROTATE" ]]; then
            demyx_echo "Rotating $DEMYX_APP_DOMAIN log"
            demyx_execute docker run -t --rm --user=root --volumes-from="$DEMYX_APP_WP_CONTAINER" demyx/logrotate
        else
            DEMYX_LOG_WP=access
            if [[ -n "$DEMYX_LOG_DATABASE" ]]; then
                docker exec -it "$DEMYX_APP_DB_CONTAINER" tail -200 $DEMYX_LOG_FOLLOW /var/log/demyx/"$DEMYX_APP_DOMAIN".mariadb.log
            elif [[ -n "$DEMYX_LOG_ERROR" ]]; then
                docker exec -it "$DEMYX_APP_WP_CONTAINER" tail -200 $DEMYX_LOG_FOLLOW /var/log/demyx/"$DEMYX_APP_DOMAIN".error.log
            else
                docker exec -it "$DEMYX_APP_WP_CONTAINER" tail -200 $DEMYX_LOG_FOLLOW /var/log/demyx/"$DEMYX_APP_DOMAIN".access.log
            fi
        fi
    fi
}
