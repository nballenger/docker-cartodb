#!/bin/bash

#### Values from environment variables #######################################

CARTO_ENV="${CARTO_ENV}"
GEOCODER_ACCOUNT_NAME=${GEOCODER_ACCOUNT_NAME}

REQUIRED_ENV_VARS=(CARTO_ENV GEOCODER_ACCOUNT_NAME)

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

#### Imputed variables #######################################################

METADATA_DB_FOR_ENV="carto_db_${CARTO_ENV}"
QUERY="SELECT database_name FROM users WHERE username='${GEOCODER_ACCOUNT_NAME}';"
GEOCODER_DB=$(echo $QUERY | psql -U postgres -t $METADATA_DB_FOR_ENV)

#### Geocoder changes ########################################################

# See https://github.com/CartoDB/data-services/issues/228#issuecomment-280037353
# Not run during Docker build phase as it would make the image too big
cd /data-services/geocoder
./geocoder_download_dumps

./geocoder_restore_dump postgres $GEOCODER_DB db_dumps/*.sql
rm -r db_dumps
chmod +x geocoder_download_patches.sh geocoder_apply_patches.sh
./geocoder_download_patches.sh
./geocoder_apply_patches.sh postgres $GEOCODER_DB data_patches/*.sql
rm -r data_patches
