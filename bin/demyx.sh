#!/bin/bash
# Demyx
# https://demyx.sh
set -eEuo pipefail
# shellcheck disable=SC2034,SC1091
#
#   demyx <command> <args>
#
demyx() {
    local DEMYX_ARGS="${*:-}"
    local DEMYX_ARG_1="${1:-}"
    local DEMYX_ARG_2="${2:-}"
    . "$DEMYX_FUNCTION"/global.sh
    . "$DEMYX_FUNCTION"/help.sh
    . "$DEMYX_FUNCTION"/smtp.sh
    trap 'demyx_trap "${BASH_LINENO[*]}" "$LINENO" "${FUNCNAME[*]:-script}" "$?" "$BASH_COMMAND"' ERR

    demyx_source "$DEMYX_ARG_1"
    case "$DEMYX_ARG_1" in
        backup) shift
            demyx_backup "$@"
        ;;
        compose) shift
            demyx_compose "$@"
        ;;
        config) shift
            demyx_config "$@"
        ;;
        cp) shift
            demyx_cp "$@"
        ;;
        cron) shift
            demyx_cron "$@"
        ;;
        down) shift
            . "${DEMYX_FUNCTION}"/compose.sh
            demyx_compose "${DEMYX_ARG_2}" down
        ;;
        edit) shift
            demyx_edit "$@"
        ;;
        exec) shift
            demyx_exec "$@"
        ;;
        healthcheck) shift
            demyx_healthcheck "$@"
        ;;
        help) shift
            demyx_help "$@"
        ;;
        info) shift
            demyx_info "$@"
        ;;
        log) shift
            demyx_log "$@"
        ;;
        motd) shift
            demyx_motd "$@"
        ;;
        pull) shift
            demyx_pull "$@"
        ;;
        refresh) shift
            demyx_refresh "$@"
        ;;
        restore) shift
            demyx_restore "$@"
        ;;
        rm) shift
            demyx_rm "$@"
        ;;
        run) shift
            demyx_run "$@"
        ;;
        smtp) shift
            demyx_smtp "$@"
        ;;
        up) shift
            . "${DEMYX_FUNCTION}"/compose.sh
            demyx_compose "${DEMYX_ARG_2}" up -d
        ;;
        update) shift
            demyx_update "$@"
        ;;
        utility) shift
            demyx_utility "$@"
        ;;
        -v|--version|version)
            echo "$DEMYX_VERSION"
        ;;
        wp) shift
            demyx_wp "$@"
        ;;
        *)
            demyx_help "$@"
        ;;
    esac

    demyx_proper
}
#
#   Init.
#
demyx "$@" 2>&1 | tee "$DEMYX_TMP"/demyx_trap
