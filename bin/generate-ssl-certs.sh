#!/bin/bash

# Script location variables
SCRIPT_NAME=$0
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(dirname ${SCRIPT_DIR})"

#### HELP DOCUMENTATION ######################################################

function display_help() {
    local help_text=""
    IFS='' read -r -d '' help_text <<EOF

Usage: $SCRIPT_NAME [<OPTIONS>]

Purpose: Generates certificates for configuring the stack to use HTTPS locally.

Options:    -h|--help
            -f|--force
            -q|--quiet

            --subdomain <STRING>
            --domain <STRING>
            --country <STRING>
            --state <STRING>
            --locality <STRING>
            --organization <STRING>
            --org-unit <STRING>
            --email <EMAIL>
EOF

    printf "$help_text"
}

#### VARIABLES AND CLI ARGS ##################################################

# CLI arg defaults
FORCE="no"
QUIET="no"

SUBDOMAIN="cartodb"
DOMAIN="localhost"
COUNTRY="US"
STATE="Vermont"
LOCALITY="Hartland"
ORGANIZATION="OSS-Carto-Org"
ORG_UNIT="Engineering"
EMAIL="noreply@example.com"

# Set values from CLI args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            display_help; exit 0; ;;
        -f|--force)
            FORCE="yes"; shift; ;;
        -q|--quiet)
            QUIET="yes"; shift; ;;
        --subdomain)
            shift; SUBDOMAIN="$1"; shift; ;;
        --domain)
            shift; DOMAIN="$1"; shift; ;;
        --country)
            shift; COUNTRY="$1"; shift; ;;
        --state)
            shift; STATE="$1"; shift; ;;
        --locality)
            shift; LOCALITY="$1"; shift; ;;
        --organization)
            shift; ORGANIZATION="$1"; shift; ;;
        --org-unit)
            shift; ORG_UNIT="$1"; shift; ;;
        --email)
            shift; EMAIL="$1"; shift; ;;
        *)
            break; ;;
    esac
done

# Imputed values
FQDN="${SUBDOMAIN}.${DOMAIN}"
COMMON_NAME="${FQDN}"
PASSWORD="abc123def"

SSL_DIRECTORY="${REPO_ROOT}/docker/ssl"
mkdir -p $SSL_DIRECTORY

SSL_BASE_NAME="${FQDN}"
SSL_KEYFILE="${SSL_DIRECTORY}/${SSL_BASE_NAME}.key"
SSL_CSRFILE="${SSL_DIRECTORY}/${SSL_BASE_NAME}.csr"
SSL_CERTFILE="${SSL_DIRECTORY}/${SSL_BASE_NAME}.crt"

# Certificate authority info variables
CA_BASE_NAME="${SUBDOMAIN}CA"
CA_KEYFILE="${SSL_DIRECTORY}/${CA_BASE_NAME}.key"
CA_ROOTCERT="${SSL_DIRECTORY}/${CA_BASE_NAME}.pem"

# Echo function
function echo_if_unquiet() {
    if [ "$QUIET" != "yes" ]; then
        printf "$1\n"
    fi
}

if [ ! -f ${CA_KEYFILE} ] || [ ! -f ${CA_ROOTCERT} ] || [ "$FORCE" == "yes" ]; then
    echo_if_unquiet "Generating private key for CA root certificate..."
    openssl genrsa -des3 -passout pass:${PASSWORD} -out ${CA_KEYFILE} 2048

    echo_if_unquiet "Removing passphrase from CA root cert key..."
    openssl rsa -in ${CA_KEYFILE} -passin pass:${PASSWORD} -out ${CA_KEYFILE}

    echo_if_unquiet "Generating root certificate from CA root cert key..."
    openssl req -x509 -new -nodes -key ${CA_KEYFILE} -sha256 -days 1825 -out ${CA_ROOTCERT} \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=$ORG_UNIT/CN=${COMMON_NAME}/emailAddress=${EMAIL}"
else
    echo_if_unquiet "\n*******\n\nSkipping generation of CA root cert key and root cert, as they already exist. Use --force to force regeneration of the .key and .pem files for the CA. You will have to reinstall the .pem file to your local trusted CAs if you do so.\n\n*******\n"
fi

echo_if_unquiet "Generating private key for SSL certificate..."
openssl genrsa -out ${SSL_KEYFILE} 2048

CSR_SUBJ="/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${FQDN}/emailAddress=${EMAIL}"

echo_if_unquiet "Creating certificate signing request for SSL cert, against CA root cert..."
openssl req -new -key ${SSL_KEYFILE} -out ${SSL_CSRFILE} -subj "${CSR_SUBJ}" 

SSL_CONFIG=""
IFS='' read -r -d '' SSL_CONFIG <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints = CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName=DNS:${FQDN}
EOF

openssl x509 -req -in ${SSL_CSRFILE} -CA ${CA_ROOTCERT} -CAkey ${CA_KEYFILE} -CAcreateserial \
    -out ${SSL_CERTFILE} -days 1825 -sha256 -extfile <(printf "$SSL_CONFIG")
