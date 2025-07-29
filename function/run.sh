# Demyx
# https://demyx.sh
# shellcheck shell=bash

#
#   demyx run <app> <args>
#
demyx_run() {
    demyx_event
    DEMYX_ARG_2="${1:-$DEMYX_ARG_2}"
    local DEMYX_RUN="DEMYX - RUN"
    local DEMYX_RUN_FLAG=
    local DEMYX_RUN_FLAG_AUTH=
    local DEMYX_RUN_FLAG_CACHE=
    local DEMYX_RUN_FLAG_CLONE=
    local DEMYX_RUN_FLAG_EMAIL=
    local DEMYX_RUN_FLAG_FORCE=
    local DEMYX_RUN_FLAG_PASSWORD=
    local DEMYX_RUN_FLAG_PHP=
    local DEMYX_RUN_FLAG_REDIS=
    local DEMYX_RUN_FLAG_SSL=
    local DEMYX_RUN_FLAG_SSL_WILDCARD=
    local DEMYX_RUN_FLAG_STACK=
    local DEMYX_RUN_FLAG_TYPE=
    local DEMYX_RUN_FLAG_USERNAME=
    local DEMYX_RUN_FLAG_WHITELIST=
    local DEMYX_RUN_FLAG_WWW=
    local DEMYX_RUN_TRANSIENT="$DEMYX_TMP"/demyx_transient

    demyx_source "
        compose
        config
        env
        rm
        yml
    "

    while :; do
        DEMYX_RUN_FLAG="${2:-}"
        case "$DEMYX_RUN_FLAG" in
            --auth)
                DEMYX_RUN_FLAG_AUTH=true
            ;;
            --cache)
                DEMYX_RUN_FLAG_CACHE=true
            ;;
            --clone=?*)
                DEMYX_RUN_FLAG_CLONE="${DEMYX_RUN_FLAG#*=}"
            ;;
            --email=?*)
                DEMYX_RUN_FLAG_EMAIL="${DEMYX_RUN_FLAG#*=}"
            ;;
            -f)
                DEMYX_RUN_FLAG_FORCE=true
            ;;
            --pass=?*|--password=?*)
                DEMYX_RUN_FLAG_PASSWORD="${DEMYX_RUN_FLAG#*=}"
            ;;
            --php=8.1|--php=8.2)
                DEMYX_RUN_FLAG_PHP="${DEMYX_RUN_FLAG#*=}"
            ;;
            --redis)
                DEMYX_RUN_FLAG_REDIS=true
            ;;
            --ssl|--ssl=true)
                DEMYX_RUN_FLAG_SSL=true
            ;;
            --ssl-wildcard|--ssl-wildcard=true)
                DEMYX_RUN_FLAG_SSL_WILDCARD=true
            ;;
            --stack=bedrock|--stack=nginx-php|--stack=ols|--stack=ols-bedrock)
                DEMYX_RUN_FLAG_STACK="${DEMYX_RUN_FLAG#*=}"
            ;;
            --type=wp|--type=php|--type=html)
                DEMYX_RUN_FLAG_TYPE="${DEMYX_RUN_FLAG#*=}"
            ;;
            --user=?*|--username=?*)
                DEMYX_RUN_FLAG_USERNAME="${DEMYX_RUN_FLAG#*=}"
            ;;
            --whitelist)
                DEMYX_RUN_FLAG_WHITELIST=all
            ;;
            --whitelist=all|--whitelist=login)
                DEMYX_RUN_FLAG_WHITELIST="${DEMYX_RUN_FLAG#*=}"
            ;;
            --www)
                DEMYX_RUN_FLAG_WWW=true
            ;;
            --) shift
                break
            ;;
            -?*)
                demyx_error flag "$DEMYX_RUN_FLAG"
            ;;
            *) break
        esac
        shift
    done

    if [[ -n "$DEMYX_ARG_2" ]]; then
        demyx_arg_valid
        demyx_run_soon
        demyx_run_init

        if [[ -n "$DEMYX_RUN_FLAG_CLONE" ]]; then
            demyx_run_clone
        else
            demyx_run_app
        fi

        demyx_run_extras
        demyx_run_table
    else
        demyx_help run
    fi
}
#
#   Main run function.
#
demyx_run_app() {
    demyx_event
    demyx_execute "Creating app" \
        "demyx_run_directory; \
        demyx_env; \
        demyx_yml ${DEMYX_APP_STACK}; \
        demyx_run_volumes"

    demyx_app_env wp DEMYX_APP_DOMAIN

    demyx_config "$DEMYX_APP_DOMAIN" --healthcheck=false
    demyx_compose "$DEMYX_APP_DOMAIN" -d up -d

    demyx_execute "Installing MariaDB" \
        "demyx_mariadb_ready"

    demyx_compose "$DEMYX_APP_DOMAIN" up -d
    demyx_config "$DEMYX_APP_DOMAIN" --healthcheck
}
#
#   Main run clone function.
#
demyx_run_clone() {
    demyx_event
    local DEMYX_RUN_CLONE_APP=
    DEMYX_RUN_CLONE_APP="$(find "$DEMYX_APP" -name "$DEMYX_RUN_FLAG_CLONE")"
    local DEMYX_RUN_CLONE_WP_CONTAINER=

    if [[ -n "$DEMYX_RUN_CLONE_APP" ]]; then
        DEMYX_RUN_CLONE_WP_CONTAINER="$(grep DEMYX_APP_WP_CONTAINER "$DEMYX_RUN_CLONE_APP"/.env | awk -F '=' '{print $2}')"
    else
        demyx_error app "$DEMYX_RUN_FLAG_CLONE"
    fi

    demyx_execute "Creating app" \
        "demyx_run_directory; \
        demyx_env; \
        demyx_yml ${DEMYX_APP_STACK}; \
        demyx_run_volumes"

    demyx_app_env wp "
        DEMYX_APP_DOMAIN
        DEMYX_APP_DOMAIN_WWW
        DEMYX_APP_ID
        DEMYX_APP_DB_CONTAINER
        DEMYX_APP_NX_CONTAINER
        DEMYX_APP_VOLUME_PREFIX
        DEMYX_APP_WP_CONTAINER
        WORDPRESS_DB_HOST
        WORDPRESS_DB_NAME
        WORDPRESS_DB_PASSWORD
        WORDPRESS_DB_USER
        WORDPRESS_URL
        WORDPRESS_USER
        WORDPRESS_USER_EMAIL
        WORDPRESS_USER_PASSWORD
    "

    demyx_config "$DEMYX_APP_DOMAIN" --healthcheck=false
    demyx_compose "$DEMYX_APP_DOMAIN" -d up -d

    demyx_execute "Installing MariaDB" \
        "demyx_mariadb_ready"

    demyx_execute "Cloning app" \
        "docker run -dt --rm \
            --entrypoint=bash \
            --name=$DEMYX_APP_WP_CONTAINER \
            --network=demyx \
            -v ${DEMYX_APP_VOLUME_PREFIX}:/demyx \
            demyx/wordpress; \
        demyx_wp $DEMYX_RUN_FLAG_CLONE db export /demyx/${DEMYX_APP_ID}.sql; \
        mkdir -p ${DEMYX_TMP}/run-${DEMYX_APP_ID}; \
        docker cp ${DEMYX_RUN_CLONE_WP_CONTAINER}:/demyx ${DEMYX_TMP}/run-${DEMYX_APP_ID}; \
        demyx_proper ${DEMYX_TMP}/run-${DEMYX_APP_ID}; \
        rm -f ${DEMYX_TMP}/run-${DEMYX_APP_ID}/demyx/wp-content/object-cache.php; \
        docker cp ${DEMYX_TMP}/run-${DEMYX_APP_ID}/demyx ${DEMYX_APP_WP_CONTAINER}:/; \
        demyx_wp $DEMYX_APP_DOMAIN config create \
            --dbhost=$WORDPRESS_DB_HOST \
            --dbname=$WORDPRESS_DB_NAME \
            --dbuser=$WORDPRESS_DB_USER \
            --dbpass=$WORDPRESS_DB_PASSWORD \
            --force; \
        docker stop $DEMYX_APP_WP_CONTAINER"

    DEMYX_RUN_FLAG_AUTH="$(grep DEMYX_APP_AUTH= "$DEMYX_RUN_CLONE_APP"/.env | awk -F '=' '{print $2}')"
    DEMYX_RUN_FLAG_CACHE="$(grep DEMYX_APP_CACHE= "$DEMYX_RUN_CLONE_APP"/.env | awk -F '=' '{print $2}')"
    DEMYX_RUN_FLAG_REDIS="$(grep DEMYX_APP_REDIS= "$DEMYX_RUN_CLONE_APP"/.env | awk -F '=' '{print $2}')"
    DEMYX_RUN_FLAG_SSL="$(grep DEMYX_APP_SSL= "$DEMYX_RUN_CLONE_APP"/.env | awk -F '=' '{print $2}')"
    DEMYX_RUN_FLAG_SSL_WILDCARD="$(grep DEMYX_APP_SSL_WILDCARD= "$DEMYX_RUN_CLONE_APP"/.env | awk -F '=' '{print $2}')"
    DEMYX_RUN_FLAG_WHITELIST="$(grep DEMYX_APP_IP_WHITELIST= "$DEMYX_RUN_CLONE_APP"/.env | awk -F '=' '{print $2}')"
    DEMYX_RUN_FLAG_WWW="$(grep DEMYX_APP_DOMAIN_WWW= "$DEMYX_RUN_CLONE_APP"/.env | awk -F '=' '{print $2}')"

    demyx_execute "Syncing configs" \
        "demyx_app_env_update DEMYX_APP_AUTH=${DEMYX_RUN_FLAG_AUTH}; \
            demyx_app_env_update DEMYX_APP_CACHE=${DEMYX_RUN_FLAG_CACHE}; \
            demyx_app_env_update DEMYX_APP_REDIS=${DEMYX_RUN_FLAG_REDIS}; \
            demyx_app_env_update DEMYX_APP_SSL=${DEMYX_RUN_FLAG_SSL}; \
            demyx_app_env_update DEMYX_APP_SSL_WILDCARD=${DEMYX_RUN_FLAG_SSL_WILDCARD}; \
            demyx_app_env_update DEMYX_APP_IP_WHITELIST=${DEMYX_RUN_FLAG_WHITELIST}; \
            demyx_app_env_update DEMYX_APP_DOMAIN_WWW=${DEMYX_RUN_FLAG_WWW}"

    demyx_compose "$DEMYX_APP_DOMAIN" up -d

    demyx_execute "Installing WordPress" \
        "demyx_wp $DEMYX_APP_DOMAIN db import /demyx/${DEMYX_APP_ID}.sql; \
        demyx_wp $DEMYX_APP_DOMAIN user create $WORDPRESS_USER $WORDPRESS_USER_EMAIL \
            --role=administrator \
            --user_pass=${WORDPRESS_USER_PASSWORD}; \
        demyx_wp $DEMYX_APP_DOMAIN search-replace --precise --all-tables $(demyx_app_domain "$DEMYX_RUN_FLAG_CLONE") $(demyx_app_domain "$DEMYX_APP_DOMAIN"); \
        demyx_wp $DEMYX_APP_DOMAIN rewrite structure '/%category%/%postname%/'"

    demyx_execute "Cleaning up" \
        "docker exec -t $DEMYX_RUN_CLONE_WP_CONTAINER rm -f /demyx/${DEMYX_APP_ID}.sql; \
        rm -rf ${DEMYX_TMP}/run-*"

    demyx_config "$DEMYX_APP_DOMAIN" --healthcheck
}
#
#   Create app directory based on --type.
#
demyx_run_directory() {
    demyx_event
    case "$DEMYX_APP_TYPE" in
        html)
            mkdir -p "$DEMYX_HTML"/"$DEMYX_ARG_2"
        ;;
        php)
            mkdir -p "$DEMYX_PHP"/"$DEMYX_ARG_2"
        ;;
        *)
            mkdir -p "$DEMYX_WP"/"$DEMYX_ARG_2"
        ;;
    esac
}
#
#   Initialize commands before main run function.
#
demyx_run_init() {
    demyx_event
    local DEMYX_APP_RUN_INIT_CHECK=
    DEMYX_APP_RUN_INIT_CHECK="$(demyx_app_path "$DEMYX_ARG_2")"
    local DEMYX_RUN_APP_INIT_CONFIRM=

    # Execute first if there's already an existing app.
    if [[ -d "$DEMYX_APP_RUN_INIT_CHECK" ]]; then
        # Make a copy of .env.
        cp "$DEMYX_APP_RUN_INIT_CHECK"/.env "$DEMYX_LOG"/"$DEMYX_ARG_2".env

        # Prompt to delete.
        if [[ "$DEMYX_RUN_FLAG_FORCE" = true ]]; then
            demyx_rm "$DEMYX_ARG_2" -f
        else
            echo -en "\e[33m"
            read -rep "[WARNING] Delete $DEMYX_ARG_2? [yY]: " DEMYX_RUN_APP_INIT_CONFIRM
            echo -en "\e[39m"

            if [[ "$DEMYX_RUN_APP_INIT_CONFIRM" != [yY] ]]; then
                demyx_error cancel
            else
                demyx_rm "$DEMYX_ARG_2" -f
            fi
        fi

        # Clear out environment variables in the scope.
        sed -i 's|=.*|=|g' "$DEMYX_LOG"/"$DEMYX_ARG_2".env
        . "$DEMYX_LOG"/"$DEMYX_ARG_2".env
        rm -f "$DEMYX_LOG"/"$DEMYX_ARG_2".env
    fi

    # Define stack.
    case "$DEMYX_RUN_FLAG_STACK" in
        bedrock)
            DEMYX_APP_STACK=bedrock
            DEMYX_RUN_FLAG_STACK=bedrock
        ;;
        ols)
            DEMYX_APP_STACK=ols
            DEMYX_RUN_FLAG_STACK=ols
        ;;
        ols-bedrock)
            DEMYX_APP_STACK=ols-bedrock
            DEMYX_RUN_FLAG_STACK=ols-bedrock
        ;;
        *)
            DEMYX_APP_STACK=nginx-php
            DEMYX_RUN_FLAG_STACK=nginx-php
        ;;
    esac

    # Define SSL.
    DEMYX_APP_SSL="${DEMYX_RUN_FLAG_SSL:-false}"

    # Define wildcard SSL.
    DEMYX_APP_SSL_WILDCARD="${DEMYX_RUN_FLAG_SSL_WILDCARD:-false}"

    # Define type.
    DEMYX_APP_TYPE="${DEMYX_RUN_FLAG_TYPE:-wp}"

    # Define basic auth.
    DEMYX_APP_AUTH="${DEMYX_RUN_FLAG_AUTH:-false}"

    # Define cache.
    DEMYX_APP_CACHE="${DEMYX_RUN_FLAG_CACHE:-false}"

    # Define whitelist.
    DEMYX_APP_IP_WHITELIST="${DEMYX_RUN_FLAG_WHITELIST:-false}"

    # Define php version.
    DEMYX_APP_PHP="${DEMYX_RUN_FLAG_PHP:-8.1}"

    # Define redis value
    DEMYX_APP_REDIS=${DEMYX_RUN_FLAG_REDIS:-false}

    # Define WordPress admin credentials.
    WORDPRESS_USER="${WORDPRESS_USER:-$DEMYX_RUN_FLAG_USERNAME}"
    WORDPRESS_USER_EMAIL="${WORDPRESS_USER_EMAIL:-$DEMYX_RUN_FLAG_EMAIL}"
    WORDPRESS_USER_PASSWORD="${WORDPRESS_USER_PASSWORD:-$DEMYX_RUN_FLAG_PASSWORD}"

    if [[ "$DEMYX_RUN_FLAG_WWW" = true ]]; then
        # shellcheck disable=2034
        DEMYX_APP_DOMAIN_WWW=true
    fi

    # Require specific variables to be set for SSL
    if [[ "$DEMYX_RUN_FLAG_SSL" = true || "$DEMYX_RUN_FLAG_SSL_WILDCARD" = true ]]; then
        if [[ "$DEMYX_DOMAIN" = localhost || "$DEMYX_EMAIL" = info@localhost ]]; then
            demyx_error custom "Please update DEMYX_DOMAIN and DEMYX_EMAIL on the host"
        elif [[ "$DEMYX_RUN_FLAG_SSL_WILDCARD" = true && "$DEMYX_CF_KEY" = false ]]; then
            demyx_error custom "Please update DEMYX_CF_KEY on the host"
        fi
    fi

    # Can't use --ssl and --ssl-wildcard together
    if [[ "$DEMYX_RUN_FLAG_SSL" = true && "$DEMYX_RUN_FLAG_SSL_WILDCARD" = true ]]; then
        demyx_error custom "You can only use one SSL flag"
    fi

    # Can't clone itself
    if [[ "$DEMYX_ARG_2" = "$DEMYX_RUN_FLAG_CLONE" ]]; then
        demyx_error custom "You can't clone itself"
    fi
}
#
#   Execute extra commands.
#
demyx_run_extras() {
    demyx_event
    demyx_wordpress_ready

    local DEMYX_RUN_EXTRAS=

    if [[ "$DEMYX_RUN_FLAG_AUTH" = true ]]; then
        DEMYX_RUN_EXTRAS+="--auth "
    fi

    if [[ "$DEMYX_RUN_FLAG_CACHE" = true ]]; then
        DEMYX_RUN_EXTRAS+="--cache "
    fi

    if [[ "$DEMYX_RUN_FLAG_REDIS" = true ]]; then
        DEMYX_RUN_EXTRAS+="--redis "
    fi

    if [[ -n "$DEMYX_RUN_FLAG_WHITELIST" ]]; then
        DEMYX_RUN_EXTRAS+="--whitelist=$DEMYX_RUN_FLAG_WHITELIST "
    fi

    if [[ "$DEMYX_RUN_FLAG_WWW" = true ]]; then
        DEMYX_RUN_EXTRAS+="--www "
    fi

    if [[ -n "$DEMYX_RUN_EXTRAS" ]]; then
        eval demyx_config "$DEMYX_APP_DOMAIN" "$DEMYX_RUN_EXTRAS" --no-compose
        demyx_compose "$DEMYX_APP_DOMAIN" up -d
    fi
}
#
#   Feature coming soon.
#
demyx_run_soon() {
    demyx_event
    if [[ "$DEMYX_RUN_FLAG_TYPE" = html || "$DEMYX_RUN_FLAG_TYPE" = php ]]; then
        demyx_error custom "Coming Soon™"
    fi
}
#
#   Output run table.
#
demyx_run_table() {
    demyx_event
    demyx_app_env wp "
        DEMYX_APP_AUTH
        DEMYX_APP_CACHE
        DEMYX_APP_DB_CONTAINER
        DEMYX_APP_IP_WHITELIST
        DEMYX_APP_NX_CONTAINER
        DEMYX_APP_OLS_ADMIN_PASSWORD
        DEMYX_APP_OLS_ADMIN_USERNAME
        DEMYX_APP_OLS_LSPHP
        DEMYX_APP_PHP
        DEMYX_APP_REDIS
        DEMYX_APP_SSL
        DEMYX_APP_SSL_WILDCARD
        DEMYX_APP_WP_CONTAINER
        WORDPRESS_USER
        WORDPRESS_USER_EMAIL
        WORDPRESS_USER_PASSWORD
    "

    local DEMYX_RUN_TABLE_SSL="SSL                      "
    local DEMYX_RUN_TABLE_SSL_VALUE="$DEMYX_APP_SSL"

    {
        if [[ "$DEMYX_APP_TYPE" = wp ]]; then
            echo "WordPress Login           $(demyx_app_login)"
            echo "Username                  $WORDPRESS_USER"
            echo "Password                  $WORDPRESS_USER_PASSWORD"
            echo "Email                     $WORDPRESS_USER_EMAIL"
            echo

            echo "MariaDB Container         $DEMYX_APP_DB_CONTAINER"

            if [[ "$DEMYX_APP_STACK" = nginx-php || "$DEMYX_APP_STACK" = bedrock ]]; then
                echo "Nginx Container           $DEMYX_APP_NX_CONTAINER"
            fi

            echo "WordPress Container       $DEMYX_APP_WP_CONTAINER"

            if [[ "$DEMYX_APP_STACK" = ols || "$DEMYX_APP_STACK" = ols-bedrock ]]; then
                echo
                echo "OLS Admin Login           $(demyx_app_proto)://$(demyx_app_domain "$DEMYX_APP_DOMAIN")/demyx/ols/"
                echo "OLS Admin Username        $DEMYX_APP_OLS_ADMIN_USERNAME"
                echo "OLS Admin Password        $DEMYX_APP_OLS_ADMIN_PASSWORD"
            fi
        fi

        echo
        echo "Stack                     $DEMYX_APP_STACK"

        # TODO
        if [[ "$DEMYX_APP_STACK" = nginx-php || "$DEMYX_APP_STACK" = bedrock ]]; then
            echo "PHP                       $DEMYX_APP_PHP"
        elif [[ "$DEMYX_APP_STACK" = ols || "$DEMYX_APP_STACK" = ols-bedrock ]]; then
            echo "LSPHP                     $DEMYX_APP_OLS_LSPHP"
        fi

        if [[ "$DEMYX_APP_SSL_WILDCARD" = true ]]; then
            DEMYX_RUN_TABLE_SSL="Wildcard SSL             "
            DEMYX_RUN_TABLE_SSL_VALUE="$DEMYX_APP_SSL_WILDCARD"
        fi

        echo "$DEMYX_RUN_TABLE_SSL $DEMYX_RUN_TABLE_SSL_VALUE"
        echo "Basic Auth                $DEMYX_APP_AUTH"
        echo "Cache                     $DEMYX_APP_CACHE"
        echo "Whitelist                 $DEMYX_APP_IP_WHITELIST"
        echo "Redis                     $DEMYX_APP_REDIS"
    } > "$DEMYX_RUN_TRANSIENT"

    demyx_divider_title "$DEMYX_RUN" "App Credentials"
    cat < "$DEMYX_RUN_TRANSIENT"
}
#
#   Create app's volumes.
#
demyx_run_volumes() {
    demyx_event
    demyx_app_env wp "
        DEMYX_APP_ID
        DEMYX_APP_STACK
        DEMYX_APP_VOLUME_PREFIX
    "

    docker volume create "$DEMYX_APP_VOLUME_PREFIX"
    docker volume create "$DEMYX_APP_VOLUME_PREFIX"_code
    docker volume create "$DEMYX_APP_VOLUME_PREFIX"_custom
    docker volume create "$DEMYX_APP_VOLUME_PREFIX"_db
    docker volume create "$DEMYX_APP_VOLUME_PREFIX"_log
    docker volume create "$DEMYX_APP_VOLUME_PREFIX"_sftp
}
