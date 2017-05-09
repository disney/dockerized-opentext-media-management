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
YELLOW='\033[0;33m'
NC='\033[0m' # No Color


# This file is run in a background process from entrypoint.sh, so it doesn’t know about any environment variables declared in that context


# Poll until port 8080 is open, and therefore OpenText Directory Services is ready
for i in {1..100}; do (echo > /dev/tcp/opentext-directory-services/8080) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to OpenText Directory Services, exiting${NC}\n" && exit 1; fi; done


# Get the filename of the compiled jar for our OTDS Services Bridge code
jar=/opt/utilities/opentext-directory-services-http-endpoints-bridge/opentext-directory-services-http-endpoints-bridge-1.0.0-SNAPSHOT.jar


# Change the passwords if they’re not already what the environment variables expect them to be
if ! java -jar $jar get-authentication-ticket otadmin@otds.admin $OTDS_ADMIN_PASSWORD; then
	printf "${GREEN}Changing otadmin@otds.admin password...${NC}\n"
	old_password='MediaVault1!' # OpenText Directory Services was installed with `MediaVault1!` as the otadmin@otds.admin password
	new_password="$OTDS_ADMIN_PASSWORD"
	OTDS_ADMIN_PASSWORD=$old_password java -jar $jar change-password otadmin@otds.admin $new_password
fi

if [ ! "$DOCKER_MODE" = 'install-on-start' ]; then
	# The tsuper user doesn’t exist in OTDS until the OTMM installer creates it
	if ! java -jar $jar get-authentication-ticket tsuper $OTMM_ADMIN_PASSWORD; then
		printf "${GREEN}Changing tsuper password...${NC}\n"
		java -jar $jar change-password tsuper $OTMM_ADMIN_PASSWORD
	fi
fi


# Don’t think we need to consolidate, actually; but in case it becomes necessary in the future, uncomment this block:
# printf "${GREEN}Consolidating user accounts with OpenText Media Management...${NC}\n"
# java -jar $jar consolidate OTMM


printf "${GREEN}Adding login trust site referring addresses...${NC}\n"
java -jar $jar whitelist-trusted-site "$APP_ROOT_URL/otds-admin/"
java -jar $jar whitelist-trusted-site "$APP_ROOT_URL/otmm/"
java -jar $jar whitelist-trusted-site "$APP_ROOT_URL/teams/Admin.do"


printf "${GREEN}Setting “Synchronization Master Host” system setting...${NC}\n"
java -jar $jar set-synchronization-master-host
