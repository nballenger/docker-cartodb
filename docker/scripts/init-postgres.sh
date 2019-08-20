#!/bin/bash -e
SCRIPT_NAME=$0

#### Variables from environment vars #########################################

# Required
CARTO_ENV="${CARTO_ENV}"
USER_ACCOUNT_USER_NAME="${USER_ACCOUNT_USER_NAME}"
ORG_ACCOUNT_USER_NAME="${ORG_ACCOUNT_USER_NAME}"
GEOCODER_PG_ROLE_NAME="${GEOCODER_PG_ROLE_NAME}"
GEOCODER_DB_NAME="${GEOCODER_DB_NAME}"

# Optional with defaults
DB_ADMIN="${PGUSER:-postgres}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
REDIS_METADATA_DB="5"

# Composite
PG_METADATA_DB="carto_db_${CARTO_ENV}"
PG_CONN="-U ${DB_ADMIN} -h ${PG_HOST} -p ${PG_PORT}"

#### Env var validation ######################################################

REQUIRED_ENV_VARS=(CARTO_ENV USER_ACCOUNT_USER_NAME ORG_ACCOUNT_USER_NAME
                   GEOCODER_PG_ROLE_NAME GEOCODER_DB_NAME)

REQS_MET="yes"
for var in ${REQUIRED_ENV_VARS[@]}; do
    if [[ -z ${!var} ]]; then
        echo "CRITICAL: In script ${0}, ${var} not found in environment."
        REQS_MET="no"
    fi
done

if [[ $REQS_MET != "yes" ]]; then
    echo "${0} exiting, insufficient info from env."; exit 1
fi

#### Create the publicuser and tileuser roles ################################
createuser $PG_CONN publicuser
createuser $PG_CONN tileuser

#### Create the postgis template database ####################################

TEMPLATE_DB="template_postgis"

createdb $PG_CONN -E UTF8 -T template0 "$TEMPLATE_DB"

cat <<EOF | psql $PG_CONN -d postgres -e
UPDATE pg_database SET datistemplate='true' WHERE datname='$TEMPLATE_DB';
CREATE EXTENSION IF NOT EXISTS plpythonu;
EOF

cat <<EOF | psql $PG_CONN -d $TEMPLATE_DB -e
CREATE EXTENSION IF NOT EXISTS plpgsql;
CREATE EXTENSION IF NOT EXISTS plproxy;
CREATE EXTENSION IF NOT EXISTS plpythonu;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS crankshaft VERSION 'dev';
GRANT ALL ON geometry_columns TO PUBLIC;
GRANT ALL ON spatial_ref_sys TO PUBLIC;
EOF

#### Create geocoder database ################################################

# Create role and database
createuser $PG_CONN $GEOCODER_PG_ROLE_NAME
createdb $PG_CONN -T $TEMPLATE_DB -E UTF8 --lc-collate='en_US.UTF-8' \
    --lc-ctype='en_US.UTF-8' $GEOCODER_DB_NAME

# Install extensions
cat <<EOF | psql $PG_CONN -d $GEOCODER_DB_NAME -e
CREATE EXTENSION IF NOT EXISTS plproxy;
CREATE EXTENSION IF NOT EXISTS plpythonu;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS cartodb;
CREATE EXTENSION IF NOT EXISTS cdb_geocoder;
CREATE EXTENSION IF NOT EXISTS cdb_dataservices_server;
CREATE EXTENSION IF NOT EXISTS cdb_dataservices_client;
CREATE EXTENSION IF NOT EXISTS observatory VERSION 'dev';
EOF

# Set configuration values per the README from the dataservices-api repo.

cat <<EOF | psql $PG_CONN -d $GEOCODER_DB_NAME -e
SELECT CDB_Conf_SetConf(
    'redis_metadata_config',
    '{"redis_host": "${REDIS_HOST}", "redis_port": ${REDIS_PORT}, "sentinel_master_id": "", "timeout": 0.1, "redis_db": $REDIS_METADATA_DB}'
);
SELECT CDB_Conf_SetConf(
    'redis_metrics_config',
    '{"redis_host": "${REDIS_HOST}", "redis_port": ${REDIS_PORT}, "sentinel_master_id": "", "timeout": 0.1, "redis_db": $REDIS_METADATA_DB}'
);

SELECT CDB_Conf_SetConf(
    'user_config',
    '{"is_organization": false, "entity_name": "${USER_ACCOUNT_USER_NAME}"}'
);

SELECT CDB_Conf_SetConf(
    'user_config',
    '{"is_organization": true, "entity_name": "${ORG_ACCOUNT_USER_NAME}"}'
);

SELECT CDB_Conf_SetConf(
    'server_conf',
    '{"environment": "${CARTO_ENV}"}'
);

SELECT cartodb.cdb_conf_setconf(
    'logger_conf', 
    '{"geocoder_log_path": "/tmp/geocodings.log"}'
);

SELECT cartodb.cdb_conf_setconf(
    'heremaps_conf', 
    '{"geocoder": {"app_id": "dummy_id", "app_code": "dummy_code", "geocoder_cost_per_hit": 1}, "isolines": {"app_id": "dummy_id", "app_code": "dummy_code"}}'
);

SELECT cartodb.cdb_conf_setconf(
    'mapzen_conf', 
    '{"routing": {"api_key": "routing_dummy_api_key", "monthly_quota": 1500000}, "geocoder": {"api_key": "geocoder_dummy_api_key", "monthly_quota": 1500000}, "matrix": {"api_key": "matrix_dummy_api_key", "monthly_quota": 1500000}}'
);

SELECT cartodb.cdb_conf_setconf(
    'mapbox_conf', 
    '{"routing": {"api_keys": ["routing_dummy_api_key"], "monthly_quota": 1500000}, "geocoder": {"api_keys": ["geocoder_dummy_api_key"], "monthly_quota": 1}, "matrix": {"api_keys": ["matrix_dummy_api_key"], "monthly_quota": 1500000}}'
);

SELECT cartodb.cdb_conf_setconf(
    'tomtom_conf', 
    '{"routing": {"api_keys": ["routing_dummy_api_key"], "monthly_quota": 1500000}, "geocoder": {"api_keys": ["geocoder_dummy_api_key"], "monthly_quota": 1500000}, "isolines": {"api_keys": ["matrix_dummy_api_key"], "monthly_quota": 1500000}}'
);

SELECT cartodb.cdb_conf_setconf(
    'data_observatory_conf', 
    '{"connection": {"whitelist": ["ethervoid"], "production": "host=${PG_HOST} port=${PG_PORT} dbname=${GEOCODER_DB_NAME} user=${GEOCODER_PG_ROLE_NAME}", "staging": "host=${PG_HOST} port=${PG_PORT} dbname=${GEOCODER_DB_NAME} user=${GEOCODER_PG_ROLE_NAME}", "development": "host=${PG_HOST} port=${PG_PORT} dbname=${GEOCODER_DB_NAME} user=${GEOCODER_PG_ROLE_NAME}", "monthly_quota": 100000}}'
);
EOF

# Load fixtures data for Geocoder
FIXTURES_FILE="/observatory-extension/src/pg/test/fixtures/load_fixtures.sql"
psql $PG_CONN -d $GEOCODER_DB_NAME -f $FIXTURES_FILE

# Set permissions for the observatory extension
cat <<EOF | psql $PG_CONN -d $GEOCODER_DB_NAME -e
GRANT SELECT ON ALL TABLES IN SCHEMA cdb_observatory TO $GEOCODER_PG_ROLE_NAME;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cdb_observatory TO $GEOCODER_PG_ROLE_NAME;
GRANT SELECT ON ALL TABLES IN SCHEMA observatory TO $GEOCODER_PG_ROLE_NAME;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA observatory TO $GEOCODER_PG_ROLE_NAME;
EOF
