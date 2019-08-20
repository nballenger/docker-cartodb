#!/bin/bash -e
SCRIPT_NAME=$0
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(dirname ${SCRIPT_DIR})"

function display_help() {
    local help_text=""
    IFS='' read -r -d '' help_text <<EOF
    
Usage: $SCRIPT_NAME
EOF
}

BUILD_CONF="DEFAULT"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            display_help
            exit 0
            ;;
        -c|--conf)
            shift
            BUILD_CONF=$1
            shift
            ;;
        *)
            break
            ;;
    esac
done

TEMPLATES_DIR="${REPO_ROOT}/templates"
DOCKER_CONF_DIR="${REPO_ROOT}/docker/config"
BUILD_CONF_DIR="${REPO_ROOT}/build-configurations"
BUILD_CONF_FILE="${BUILD_CONF_DIR}/${BUILD_CONF}.json"
RENDER_SCRIPT="${REPO_ROOT}/bin/render-template.js"

if [[ ! -f $BUILD_CONF_FILE ]]; then
    echo "Build configuration '${BUILD_CONF}' did not resolve to a real file at $BUILD_CONF_FILE"
    exit 1
fi

printf "\n$0: Using build configuration: $BUILD_CONF (build-configurations/$BUILD_CONF.json)\n\n"

CONF_TEMPLATES=(cartodb-app_config.yml cartodb-database.yml nginx.conf
                sqlapi-config.js varnish.vcl windshaft-config.js)

for template in ${CONF_TEMPLATES[@]}; do
    printf "    Writing config file docker/config/${template}..."
    node $RENDER_SCRIPT $BUILD_CONF_FILE ${TEMPLATES_DIR}/${template}.mustache > ${DOCKER_CONF_DIR}/${template}
    printf "DONE\n"
done

BUILD_CMD_SCRIPT="docker-build-command.sh"
BUILD_CMD_TEMPLATE="${REPO_ROOT}/templates/${BUILD_CMD_SCRIPT}.mustache"

printf "\n    Generating docker build command from build conf..."
node $RENDER_SCRIPT $BUILD_CONF_FILE $BUILD_CMD_TEMPLATE > ${REPO_ROOT}/$BUILD_CMD_SCRIPT
chmod 755 ${REPO_ROOT}/$BUILD_CMD_SCRIPT
printf "DONE\n"

printf "\nConfig complete for $BUILD_CONF. To build with this configuration, use\n\n    ./docker-build-command.sh -t env-aware-sver:$BUILD_CONF\n\n"
