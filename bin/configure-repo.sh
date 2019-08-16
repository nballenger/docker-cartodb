#!/bin/bash -e
SCRIPT_NAME=$0
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(dirname ${SCRIPT_DIR})"

BUILD_CONF="NICKTEST"

TEMPLATES_DIR="${REPO_ROOT}/templates"
DOCKER_CONF_DIR="${REPO_ROOT}/docker/config"
BUILD_CONF_DIR="${REPO_ROOT}/build-configurations"
BUILD_CONF_FILE="${BUILD_CONF_DIR}/${BUILD_CONF}.json"
RENDER_SCRIPT="${REPO_ROOT}/bin/render-template.js"

CONF_TEMPLATES=(cartodb-app_config.yml cartodb-database.yml nginx.conf
                sqlapi-config.js varnish.vcl windshaft-config.js)

for template in ${CONF_TEMPLATES[@]}; do
    echo "Writing config file ${DOCKER_CONF_DIR}/${template}..."
    node $RENDER_SCRIPT $BUILD_CONF_FILE ${TEMPLATES_DIR}/${template}.mustache > ${DOCKER_CONF_DIR}/${template}
done

BUILD_CMD_SCRIPT="docker-build-command.sh"
BUILD_CMD_TEMPLATE="${REPO_ROOT}/templates/${BUILD_CMD_SCRIPT}.mustache"

echo "Generating docker build command from build conf..."
node $RENDER_SCRIPT $BUILD_CONF_FILE $BUILD_CMD_TEMPLATE > ${REPO_ROOT}/$BUILD_CMD_SCRIPT
chmod 755 ${REPO_ROOT}/$BUILD_CMD_SCRIPT
