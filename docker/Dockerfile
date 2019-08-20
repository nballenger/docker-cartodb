#
# Cartodb container
#
FROM ubuntu:18.04
LABEL maintainer="Stefan Verhoeven <s.verhoeven@esciencecenter.nl>"

# Configuring locales
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
 && apt-get install -y -q --no-install-recommends \
    apt-utils \
    software-properties-common \
    locales \
 && dpkg-reconfigure locales \
 && locale-gen en_US.UTF-8 \
 && update-locale LANG=en_US.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

##############################################################################
# BASE DEPENDENCIES FOR ALL CARTO PACKAGES                                   #
##############################################################################

RUN useradd -m -d /home/cartodb -s /bin/bash cartodb \
 && apt-get update \
 && apt-get install -y -q --no-install-recommends \
    build-essential \
    autoconf \
    automake \
    libtool \
    checkinstall \
    unp \
    zip \
    unzip \
    git-core \
    git \
    subversion \
    curl \
    libgeos-c1v5 \
    libgeos-dev \
    libjson-c-dev \
    python-simplejson \
    proj-bin \
    proj-data \
    libproj-dev \
    gdal-bin \
    libgdal-dev \
    postgresql-10 \
    postgresql-client-10 \
    postgresql-contrib-10 \
    postgresql-server-dev-10 \
    postgresql-plpython-10 \
    postgresql-10-plproxy \
    postgresql-10-postgis-2.4 \
    postgresql-10-postgis-scripts \
    postgis \
    liblwgeom-2.4-0 \
    ca-certificates \
    redis-server \
    python2.7-dev \
    python-setuptools \
    imagemagick \
    libmapnik-dev \
    mapnik-utils \
    python-mapnik \
    python-argparse \
    python-gdal \
    python-chardet \
    python-all-dev \
    python-docutils \
    openssl \
    libreadline7 \
    zlib1g \
    zlib1g-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    sqlite3 \
    libxml2-dev \
    libxslt-dev \
    libc6-dev \
    ncurses-dev \
    bison \
    pkg-config \
    libpq5 \
    libpq-dev \
    libcurl4-gnutls-dev \
    libffi-dev \
    libgdbm-dev \
    gnupg \
    libreadline6-dev \
    libcairo2-dev \
    libjpeg8-dev \
    libpango1.0-dev \
    libgif-dev \
    libgmp-dev \
    libicu-dev \
    nginx-light \
    net-tools \
    ruby2.5-dev \
    xz-utils \
&& rm -rf /var/lib/apt/lists/*


##############################################################################
# NON-APT DEPENDENCIES                                                       #
##############################################################################

WORKDIR /

#### VARNISH HTTP CACHE ######################################################
# This is Varnish 3. Ubuntu:18.04 comes with Varnish 5.1, which can't run 
# with anonymous telnet, which Carto can fall back to for cache invalidation.
RUN apt-get update \
 && apt-get install -y -q --no-install-recommends wget \
 && cd /opt \
 && wget http://varnish-cache.org/_downloads/varnish-3.0.7.tgz \
 && tar -zxf varnish-3.0.7.tgz \
 && cd varnish-3.0.7 \
 && ./configure --prefix=/opt/varnish \
 && make \
 && make install \
 && apt-get purge -y wget \
 && rm -rf /opt/varnish-3.0.7* /var/lib/apt/lists/*

#### NODEJS ##################################################################
ARG NODE_TARBALL="https://nodejs.org/dist/v10.15.3/node-v10.15.3-linux-x64.tar.xz"
RUN curl $NODE_TARBALL |tar -Jxf - --strip-components=1 -C /usr \
 && npm install -g grunt-cli \
 && npm install -g npm@6 \
 && rm -r /tmp/npm-* /root/.npm


##############################################################################
# DEPENDENCY CONFIGURATION                                                   #
##############################################################################

#### POSTGRESQL ##############################################################
# The stack relies on being able to connect to Postgres without auth, so
# we have to update the pg_hba.conf file to use trust authentication.
RUN sed -i 's/\(peer\|md5\)/trust/' /etc/postgresql/10/main/pg_hba.conf

#### GIT #####################################################################
ARG GIT_USER_EMAIL="you@example.com"
ARG GIT_USER_NAME="Your Name"

RUN git config --global user.email $GIT_USER_EMAIL \
 && git config --global user.name $GIT_USER_NAME


##############################################################################
# CARTO PACKAGE INSTALLATION                                                 #
##############################################################################

#### CRANKSHAFT PG EXTENSION #################################################
ARG CRANKSHAFT_VERSION="master"

# Note that Numpy gets upgraded after scikit-learn is installed, so sklearn
# must be explicitly reinstalled to ensure compatability.
RUN curl https://bootstrap.pypa.io/get-pip.py | python \
 && git clone --recursive https://github.com/CartoDB/crankshaft.git \
 && cd /crankshaft \
 && git checkout $CRANKSHAFT_VERSION \
 && make install \
 && pip install --force-reinstall --no-cache-dir scikit-learn==0.17.0

#### SQL API NODE APPLICATION ################################################
ARG SQLAPI_VERSION="master"

# Note the double install is not typo, this is necessary or some packages
# are not correctly installed. :/
RUN git clone --recursive git://github.com/CartoDB/CartoDB-SQL-API.git \
 && cd CartoDB-SQL-API \
 && git checkout $SQLAPI_VERSION \
 && npm install \
 && npm install

#### WINDSHAFT (MAPS API) NODE APPLICATION ###################################
ARG WINDSHAFT_VERSION="master"

RUN git clone --recursive git://github.com/CartoDB/Windshaft-cartodb.git \
 && cd Windshaft-cartodb \
 && git checkout $WINDSHAFT_VERSION \
 && npm install \
 && mkdir logs


#### CARTODB RAILS APP / RESQUE JOB RUNNER ###################################
ARG CARTODB_VERSION="master"

RUN git clone --recursive git://github.com/CartoDB/cartodb.git \
 && cd cartodb \
 && git checkout $CARTODB_VERSION \
 && git submodule update --recursive \
 && cd lib/sql \
 && PGUSER=postgres make install \
 && cd - \
 && npm install \
 && rm -r /tmp/npm-* /root/.npm \
 && perl -pi -e 's/gdal==1\.10\.0/gdal==2.2.2/' python_requirements.txt \
 && pip install --no-binary :all: -r python_requirements.txt \
 && gem install bundler --version=1.17.3 \
 && gem install compass archive-tar-minitar rack \
 && bundle update thin \
 && /bin/bash -l -c 'bundle install' \
 && cp config/grunt_development.json ./config/grunt_true.json \
 && /bin/bash -l -c 'bundle exec grunt'

#### DATASERVICES / GEOCODER POSTGRES EXTENSIONS #############################
ARG DATASERVICES_VERSION="master"
ARG DATASERVICES_API_SERVER_VERSION="master"
ARG DATASERVICES_API_CLIENT_VERSION="master"

RUN git clone --recursive https://github.com/CartoDB/data-services.git \
 && cd /data-services/geocoder/extension \
 && git checkout $DATASERVICES_VERSION \
 && PGUSER=postgres make all install \
 && cd / \
 && git clone --recursive https://github.com/CartoDB/dataservices-api.git \
 && cd /dataservices-api/server/extension \
 && git checkout $DATASERVICES_API_SERVER_VERSION \
 && PGUSER=postgres make install \
 && cd ../lib/python/cartodb_services \
 && pip install -r requirements.txt \
 && pip install . \
 && cd /dataservices-api/client \
 && git checkout $DATASERVICES_API_CLIENT_VERSION \
 && PGUSER=postgres make install

#### OBSERVATORY POSTGRES EXTENSION ##########################################
ARG OBSERVATORY_VERSION="master"

RUN git clone --recursive https://github.com/CartoDB/observatory-extension.git \
 && cd observatory-extension \
 && git checkout $OBSERVATORY_VERSION \
 && PGUSER=postgres make deploy


##############################################################################
# STACK CONFIGURATION                                                        #
##############################################################################

ARG CARTO_ENV="development"
ENV CARTO_ENV=$CARTO_ENV

#### SERVICE CONFIG FILES ####################################################
COPY ./config/sqlapi-config.js /CartoDB-SQL-API/config/environments/$CARTO_ENV.js
COPY ./config/windshaft-config.js /Windshaft-cartodb/config/environments/$CARTO_ENV.js
COPY ./config/cartodb-app_config.yml /cartodb/config/app_config.yml
COPY ./config/cartodb-database.yml /cartodb/config/database.yml
COPY ./config/nginx.conf /etc/nginx/nginx.conf
COPY ./config/varnish.vcl /etc/varnish.vcl

#### CONTAINER SCRIPTS #######################################################
WORKDIR /opt/bin

COPY ./scripts/create-user-and-org.sh ./
COPY ./scripts/init-postgres.sh ./
COPY ./scripts/fill-geocoder.sh ./
COPY ./scripts/entrypoint.sh ./

#### ENVIRONMENT VARIABLES FROM BUILD ARGS ###################################
ENV PATH /usr/local/rvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ARG CARTODB_LISTEN_PORT="3000"
ENV CARTODB_LISTEN_PORT=$CARTODB_LISTEN_PORT

ARG STACK_FQDN="cartodb.localhost"
ENV STACK_FQDN=$STACK_FQDN

ARG USER_ACCOUNT_USER_NAME="dev"
ENV USER_ACCOUNT_USER_NAME=$USER_ACCOUNT_USER_NAME

ARG USER_ACCOUNT_EMAIL
ENV USER_ACCOUNT_EMAIL=$USER_ACCOUNT_EMAIL

ARG USER_ACCOUNT_PASSWORD="pass1234"
ENV USER_ACCOUNT_PASSWORD=$USER_ACCOUNT_PASSWORD

ARG USER_ADMIN_PASSWORD="pass1234"
ENV USER_ADMIN_PASSWORD=$USER_ADMIN_PASSWORD

ARG ORG_ACCOUNT_ORG_NAME="example"
ENV ORG_ACCOUNT_ORG_NAME=$ORG_ACCOUNT_ORG_NAME

ARG ORG_ACCOUNT_USER_NAME="admin4example"
ENV ORG_ACCOUNT_USER_NAME=$ORG_ACCOUNT_USER_NAME

ARG ORG_ACCOUNT_EMAIL
ENV ORG_ACCOUNT_EMAIL=$ORG_ACCOUNT_EMAIL

ARG ORG_ACCOUNT_PASSWORD="pass1234"
ENV ORG_ACCOUNT_PASSWORD=$ORG_ACCOUNT_PASSWORD

ARG GEOCODER_PG_ROLE_NAME="geocoder_api"
ENV GEOCODER_PG_ROLE_NAME=$GEOCODER_PG_ROLE_NAME

ARG GEOCODER_DB_NAME="dataservices_db"
ENV GEOCODER_DB_NAME=$GEOCODER_DB_NAME

ARG VARNISH_HTTP_PORT="6081"
ENV VARNISH_HTTP_PORT=$VARNISH_HTTP_PORT

ARG VARNISH_TELNET_PORT="6082"
ENV VARNISH_TELNET_PORT=$VARNISH_TELNET_PORT

ARG STACK_SCHEME="http"
ENV STACK_SCHEME=$STACK_SCHEME

#### INITIALIZE PG DATA CLUSTER AND REBIND REDIS SERVER ######################
RUN service postgresql start \
 && /opt/bin/init-postgres.sh \
 && service postgresql stop \
 && perl -pi.bak -e 's/^bind 127.0.0.1 ::1$/bind 0.0.0.0/' /etc/redis/redis.conf

COPY ./ssl/* /etc/ssl/
COPY ./ssl/*CA.pem /usr/local/share/ca-certificates/osscartoCA.crt

RUN chmod 644 /etc/ssl/*.crt \
 && chmod 640 /etc/ssl/*.key \
 && update-ca-certificates

EXPOSE 80
EXPOSE 443

ENV GDAL_DATA /usr/share/gdal/2.2

ENTRYPOINT ["/bin/bash", "/opt/bin/entrypoint.sh"]
