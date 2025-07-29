# Demyx
# https://demyx.sh
# shellcheck shell=bash

#
#   demyx pull <args>
#
demyx_pull() {
    demyx_event
    DEMYX_ARG_2="${1:-$DEMYX_ARG_2}"

    case "$DEMYX_ARG_2" in
        all)
            demyx_pull_all
        ;;
        *)
            if [[ -n "$DEMYX_ARG_2" ]]; then
                demyx_pull_image
            else
                demyx_help pull
            fi
        ;;
    esac
}
#
#   Smart pull all demyx images.
#
demyx_pull_all() {
    demyx_event
    local DEMYX_PULL_ALL="
        demyx/browsersync
        demyx/code-server:bedrock
        demyx/code-server:browse
        demyx/code-server:openlitespeed
        demyx/code-server:openlitespeed-bedrock
        demyx/code-server:wp
        demyx/demyx
        demyx/docker-socket-proxy
        demyx/mariadb
        demyx/nginx
        demyx/openlitespeed
        demyx/ssh
        demyx/traefik
        demyx/utilities
        demyx/wordpress
        demyx/wordpress:bedrock
        docker:cli
        phpmyadmin/phpmyadmin
        quay.io/vektorlab/ctop
        redis:alpine3.18
    "
    local DEMYX_PULL_ALL_CHECK=
    local DEMYX_PULL_ALL_I=
    local DEMYX_PULL_ALL_PATH=
    DEMYX_PULL_ALL_PATH="$(demyx_images path)"

    for DEMYX_PULL_ALL_I in $DEMYX_PULL_ALL; do
        DEMYX_PULL_ALL_CHECK="$(grep "$DEMYX_PULL_ALL_I" "$DEMYX_PULL_ALL_PATH" || true)"

        if [[ -n "${DEMYX_PULL_ALL_CHECK}" ]]; then
            if [[ "${DEMYX_PULL_ALL_I}" == *"demyx"* ]]; then
                docker pull "$(demyx_image_tag "${DEMYX_PULL_ALL_I}")"
            else
                docker pull "${DEMYX_PULL_ALL_I}"
            fi
        fi

        echo "$DEMYX_PULL_ALL_CHECK"
    done
}
#
#   Pull specific demyx images.
#
demyx_pull_image() {
    demyx_event
    local DEMYX_PULL_IMAGE=demyx/"$DEMYX_ARG_2"

    if [[ "$DEMYX_ARG_2" = ctop ]]; then
        DEMYX_PULL_IMAGE="quay.io/vektorlab/ctop"
    elif [[   "$DEMYX_ARG_2" = pma ||
            "$DEMYX_ARG_2" = phpmyadmin ]]; then
        DEMYX_PULL_IMAGE=phpmyadmin/phpmyadmin
    elif [[   "$DEMYX_ARG_2" = redis ]]; then
        DEMYX_PULL_IMAGE=redis:alpine3.18
    fi

    docker pull "$(demyx_image_tag "${DEMYX_PULL_IMAGE}")"
}
