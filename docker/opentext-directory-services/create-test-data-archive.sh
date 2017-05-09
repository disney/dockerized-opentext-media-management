#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context

# First start up OpenText Directory Services and run the configuration script; then stop OTDS to take the backup; then start OTDS again

printf "${GREEN}Starting OpenText Directory Services...${NC}\n"
cd $CATALINA_HOME
( catalina.sh run ) &
export CATALINA_PID=$!

source /docker/configure.sh

# Stop OpenText Directory Services
kill $CATALINA_PID # Regular `catalina.sh stop` doesn’t work for some reason
printf "${GREEN}OpenText Directory Services stopped${NC}\n"

printf "${GREEN}Creating test data archive...${NC}\n"
tar --gzip --create --verbose --file /opentext-directory-services-test-data-$TIMESTAMP.tar.gz \
	/usr/local/OTDS/ \
	/usr/local/tomcat/conf/Catalina/localhost/ \
	/usr/local/tomcat/logs/ \
	/usr/local/tomcat/OTDSJMSBroker.ks
printf "${GREEN}Test data archive ready! Copy it out of the repo via:${NC}\n"
printf "${YELLOW}docker cp otmm_opentext-directory-services_1:/opentext-directory-services-test-data-$TIMESTAMP.tar.gz ~/Downloads/new-snapshots${NC}\n"


printf "${GREEN}Starting OpenText Directory Services...${NC}\n"
cd $CATALINA_HOME
exec catalina.sh run
