#!/bin/bash -e

JSON_FILE="./stack_values.json"

CONF_TEMPLATES=(cartodb-app_config.yml cartodb-database.yml nginx.conf
                sqlapi-config.js varnish.vcl windshaft-config.js)

for template in ${CONF_TEMPLATES[@]}; do
    echo "Writing ${template}..."
    ./bin/write-config.js ${JSON_FILE} ./templates/${template}.mustache > ./docker/config/${template}
done
