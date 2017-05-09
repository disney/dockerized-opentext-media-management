#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context


# A background script will wait for OpenText Directory Services to be running, then it will hit some endpoints to configure it
( source /docker/configure.sh ) &

printf "${GREEN}Starting OpenText Directory Services...${NC}\n"
cd $CATALINA_HOME
( catalina.sh run ) &
export CATALINA_PID=$!

printf "${GREEN}Connecting to OpenText Media Management...${NC}\n" # Poll until port 11099 is open, and therefore OpenText Media Management is ready
for i in {1..100}; do (echo > /dev/tcp/opentext-media-management-core-app/11099) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to OpenText Media Management, exiting${NC}\n" && exit 1; fi; done

# Stop OpenText Directory Services
kill $CATALINA_PID # Regular `catalina.sh stop` doesn’t work for some reason
printf "${GREEN}OpenText Directory Services stopped${NC}\n"

printf "${GREEN}Creating archive of OpenText Directory Services files added or updated by OpenText Media Management installation...${NC}\n"
tar --create --verbose --file /opentext-directory-services-installed-files-$TIMESTAMP.tar \
	/etc/opentext/ \
	/usr/local/OTDS/ \
	/usr/local/tomcat/conf/Catalina/localhost \
	/usr/local/tomcat/logs/
if [ -f /usr/local/tomcat/OTDSJMSBroker.ks ]; then
	tar --append --verbose --file /opentext-directory-services-installed-files-$TIMESTAMP.tar /usr/local/tomcat/OTDSJMSBroker.ks
fi
gzip /opentext-directory-services-installed-files-$TIMESTAMP.tar

printf "${GREEN}Archive ready! Copy it out of the repo via:${NC}\n"
printf "${YELLOW}docker cp otmm_opentext-directory-services_1:/opentext-directory-services-installed-files-$TIMESTAMP.tar.gz ~/Downloads/new-snapshots\n"


printf "${GREEN}Starting OpenText Directory Services...${NC}\n"
cd $CATALINA_HOME
exec catalina.sh run
