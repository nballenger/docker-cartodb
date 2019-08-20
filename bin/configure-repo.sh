#!/bin/bash
SCRIPT_NAME=$0
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(dirname ${SCRIPT_DIR})"

function display_help() {
    local help_text=""
    IFS='' read -r -d '' help_text <<EOF
    
Usage: $SCRIPT_NAME [-h|--help] [-c|--conf CONF_NAME]

Purpose: Looks for a file at 'build-configurations/CONF_NAME.json', and uses
         the values defined there to populate the Mustache templates in the
         templates directory, with output going to files in docker/config,
         and the docker-build-command.sh script in the repo root.

Options:    -h|--help           Display this message and exit.

            -c|--conf CONF_NAME Specify the build configuration file to use.
                                If none is specified, the DEFAULT.json file is
                                used. Note that you do not need to include the
                                .json file extension.

EOF

    printf "$help_text"
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

# Remove .json extension if present
BUILD_CONF=$(echo $BUILD_CONF | sed 's/.json$//')

TEMPLATES_DIR="${REPO_ROOT}/templates"
DOCKER_CONF_DIR="${REPO_ROOT}/docker/config"
BUILD_CONF_DIR="${REPO_ROOT}/build-configurations"
BUILD_CONF_FILE="${BUILD_CONF_DIR}/${BUILD_CONF}.json"
RENDER_SCRIPT="${REPO_ROOT}/bin/render-template.js"
GENERATED_SCRIPTS_DIR="${REPO_ROOT}/bin/generated"

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
BUILD_CMD_TEMPLATE="${TEMPLATES_DIR}/${BUILD_CMD_SCRIPT}.mustache"

printf "\n    Generating docker build command script from build conf..."
node $RENDER_SCRIPT $BUILD_CONF_FILE $BUILD_CMD_TEMPLATE > ${GENERATED_SCRIPTS_DIR}/$BUILD_CMD_SCRIPT
chmod 755 ${GENERATED_SCRIPTS_DIR}/$BUILD_CMD_SCRIPT
if [[ $BUILD_CONF != 'DEFAULT' ]]; then
    sed -i "s/BUILD_CONF=\"DEFAULT\"/BUILD_CONF=\"$BUILD_CONF\"/" ${GENERATED_SCRIPTS_DIR}/$BUILD_CMD_SCRIPT
fi
printf "DONE\n"

RUN_CMD_SCRIPT="docker-run-command.sh"
RUN_CMD_TEMPLATE="${TEMPLATES_DIR}/${RUN_CMD_SCRIPT}.mustache"

printf "\n    Generating docker run command script from build conf..."
node $RENDER_SCRIPT $BUILD_CONF_FILE $RUN_CMD_TEMPLATE > ${GENERATED_SCRIPTS_DIR}/$RUN_CMD_SCRIPT
chmod 755 ${GENERATED_SCRIPTS_DIR}/$RUN_CMD_SCRIPT
if [[ $BUILD_CONF != 'DEFAULT' ]]; then
    sed -i "s/BUILD_CONF=\"DEFAULT\"/BUILD_CONF=\"$BUILD_CONF\"/" ${GENERATED_SCRIPTS_DIR}/$RUN_CMD_SCRIPT
fi
printf "DONE\n"

EXEC_CMD_SCRIPT="docker-exec-shell.sh"
EXEC_CMD_TEMPLATE="${TEMPLATES_DIR}/${EXEC_CMD_SCRIPT}.mustache"

printf "\n    Generating docker exec command script to open bash shell..."
node $RENDER_SCRIPT $BUILD_CONF_FILE $EXEC_CMD_TEMPLATE > ${GENERATED_SCRIPTS_DIR}/$EXEC_CMD_SCRIPT
chmod 755 ${GENERATED_SCRIPTS_DIR}/$EXEC_CMD_SCRIPT
if [[ $BUILD_CONF != 'DEFAULT' ]]; then
    sed -i "s/BUILD_CONF=\"DEFAULT\"/BUILD_CONF=\"$BUILD_CONF\"/" ${GENERATED_SCRIPTS_DIR}/$EXEC_CMD_SCRIPT
fi
printf "DONE\n"

STOP_CMD_SCRIPT="docker-stop-command.sh"
STOP_CMD_TEMPLATE="${TEMPLATES_DIR}/${STOP_CMD_SCRIPT}.mustache"

printf "\n    Generating docker stop command script..."
node $RENDER_SCRIPT $BUILD_CONF_FILE $STOP_CMD_TEMPLATE > ${GENERATED_SCRIPTS_DIR}/$STOP_CMD_SCRIPT
chmod 755 ${GENERATED_SCRIPTS_DIR}/$STOP_CMD_SCRIPT
if [[ $BUILD_CONF != 'DEFAULT' ]]; then
    sed -i "s/BUILD_CONF=\"DEFAULT\"/BUILD_CONF=\"$BUILD_CONF\"/" ${GENERATED_SCRIPTS_DIR}/$STOP_CMD_SCRIPT
fi
printf "DONE\n"

