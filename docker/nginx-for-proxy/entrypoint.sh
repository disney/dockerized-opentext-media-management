#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# Some colors, per http://stackoverflow.com/a/5947802/223225
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


printf "${GREEN}Configuring Nginx...${NC}\n"
mkdir --parents /opt/ssl
echo "$SSL_CERTIFICATE" >> /opt/ssl/ssl.pem
echo "$SSL_CERTIFICATE_KEY" >> /opt/ssl/ssl.key
echo "$SSL_DHPARAM" >> /opt/ssl/dhparam.pem


sed --in-place "s|\$DOCKER_MACHINE|$DOCKER_MACHINE|g" /etc/nginx/conf.d/default.conf
sed --in-place "s|\$APP_SERVER|$APP_SERVER|g" /etc/nginx/conf.d/default.conf

if [ "$APP_SERVER" = "localhost" ]; then
	# Disable HSTS for localhost; http://stackoverflow.com/a/28586593/223225
	sed --in-place "s|add_header Strict-Transport-Security|# add_header Strict-Transport-Security|g" /etc/nginx/conf.d/default.conf
fi


printf "${GREEN}Adding authentication for Solr when accessed from outside the Docker network...${NC}\n"
# Based on https://www.digitalocean.com/community/tutorials/how-to-set-up-password-authentication-with-nginx-on-ubuntu-14-04
echo -n 'solr:' >> /etc/nginx/.htpasswd
echo -n "$SOLR_ADMIN_PASSWORD" | openssl passwd -apr1 -stdin >> /etc/nginx/.htpasswd


# From https://github.com/nginxinc/docker-nginx/blob/master/mainline/jessie/Dockerfile and https://github.com/marcopompili/docker-nginx-cors/blob/master/startup
printf "${GREEN}Starting Nginx...${NC}\n"
exec nginx -g "daemon off;"
