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


TIMESTAMP="$(date +%Y-%m-%d-%H-%M)"


printf "${GREEN}Configuring OpenText Directory Services...${NC}\n"
# Configure admin password
cd /usr/local/OTDS/install/
java -jar otds-deploy.jar -resetpassword "$OTDS_ADMIN_PASSWORD" # Per https://knowledge.opentext.com/knowledge/cs.dll?func=ll&objId=62146476&objAction=viewincontainer&ShowReplyEntry=62182218#forum_topic_62182218
cd $CATALINA_HOME

# If we’re creating an installed files archive, start OpenText Directory Services so that OpenText Media Management can install itself; but then once OTMM is up and running, stop OpenText Directory Services to create an archive of this container’s files
if [ "$DOCKER_MODE" = 'install-on-start' ] && [ "${CREATE_INSTALLED_FILES_ARCHIVE:-}" = true ]; then
	exec /docker/create-installed-files-archive.sh

elif [ "${CREATE_TEST_DATA_ARCHIVE:-}" = true ]; then
	exec /docker/create-test-data-archive.sh

else
	# A background script will wait for OpenText Directory Services to be running, then it will hit some endpoints to configure it
	( source /docker/configure.sh ) &
fi


if [ "$#" -eq 0 ]; then # No CMD defined in Dockerfile
	printf "${GREEN}Starting OpenText Directory Services...${NC}\n"
	cd $CATALINA_HOME
	exec catalina.sh run
else # Docker CMD provided, so run it
	exec "$@"
fi
