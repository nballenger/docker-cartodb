#!/bin/bash -e
SCRIPT_NAME=$0
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

DOCKER_BUILD_DIR="${SCRIPT_DIR}/docker"

docker build --tag env-aware-sver:NICKTEST \
    --build-arg CRANKSHAFT_VERSION="0.8.2" \
    --build-arg SQLAPI_VERSION="3.0.0" \
    --build-arg WINDSHAFT_VERSION="7.1.0" \
    --build-arg CARTODB_VERSION="v4.29.0" \
    --build-arg DATASERVICES_VERSION="0.0.2" \
    --build-arg DATASERVICES_API_SERVER_VERSION="0.35.1-server" \
    --build-arg DATASERVICES_API_CLIENT_VERSION="0.26.2-client" \
    --build-arg OBSERVATORY_VERSION="1.9.0" \
    --build-arg CARTO_ENV="development" \
    --build-arg USER_ACCOUNT_USER_NAME="dev" \
    --build-arg USER_ACCOUNT_EMAIL="nballeng+user@gmail.com" \
    --build-arg USER_ACCOUNT_PASSWORD="pass1234" \
    --build-arg USER_ADMIN_PASSWORD="pass1234" \
    --build-arg ORG_ACCOUNT_ORG_NAME="example" \
    --build-arg ORG_ACCOUNT_USER_NAME="admin4example" \
    --build-arg ORG_ACCOUNT_EMAIL="nballeng+org@gmail.com" \
    --build-arg ORG_ACCOUNT_PASSWORD="pass1234" \
    --build-arg GEOCODER_PG_ROLE_NAME="geocoder_api" \
    --build-arg GEOCODER_DB_NAME="dataservices_db" \
    --build-arg VARNISH_HTTP_PORT="6081" \
    --build-arg CARTODB_LISTEN_PORT="3000" \
    --build-arg STACK_SCHEME="http" \
    --build-arg STACK_FQDN="cartodb.localhost" \
    $DOCKER_BUILD_DIR
