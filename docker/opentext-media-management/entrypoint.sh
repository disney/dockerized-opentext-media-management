#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# Inspired by https://github.com/docker-library/wordpress/blob/master/docker-entrypoint.sh and https://github.com/jboss-dockerfiles/wildfly/pull/40/files


# Some colors, per http://stackoverflow.com/a/5947802/223225
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color


TIMESTAMP="$(date +%Y-%m-%d-%H-%M)"


if [ "$DOCKER_MODE" = 'install-on-start' ] && [ "$OTMM_MODE" = 'indexer' ]; then
	printf "${GREEN}The indexer must be started in “use installed files” mode, exiting${NC}\n"
	exit 1
fi

#
# Connect to required services
#
printf "${GREEN}Connecting to Postgres...${NC}\n"
if [ "$DOCKER_MODE" = 'install-on-start' ]; then
	for i in {1..100}; do (echo > /dev/tcp/postgres/5432) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to Postgres, exiting${NC}\n" && exit 1; fi; done
else
	# Per http://superuser.com/a/806331/138751 and http://unix.stackexchange.com/a/82610/44496
	for i in {1..100}; do (PGPASSWORD=$POSTGRES_PASSWORD psql --host=$POSTGRES_SERVER --username $POSTGRES_USER --tuples-only --command "SELECT 1 FROM pg_database WHERE datname = 'otmm'" | grep 1) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to Postgres, exiting${NC}\n" && exit 1; fi; done
fi

#
# Install OpenText Media Management, or use installed files already in container
#
# If install files are in the container, run the installer and then delete it
if [ -d /opt/opentext-media-management-installer ]; then
	source /docker/install.sh
else
	set +o nounset
	source /opt/jboss/.bash_profile
	set -o nounset
fi

source /docker/patch.sh


#
# DEBUG: this block creates a fresh bundle of “post-installation” files to use in the `use-installed-files` Dockerfile; see docker/README.md
#
if [ "$OTMM_MODE" = 'core-app' ]; then
	if [ "${CREATE_INSTALLED_FILES_ARCHIVE:-}" = true ]; then
		source /docker/create-installed-files-archive.sh
	fi
	if [ "${CREATE_TEST_DATA_ARCHIVE:-}" = true ]; then
		source /docker/create-test-data-archive.sh
	fi
fi


#
# Configure OpenText Media Management and Wildfly/JBoss
#
printf "${GREEN}Configuring OpenText Media Management...${NC}\n"
source /docker/configure.sh


#
# Deploy our customizations
#
if [ "$DEPLOY_CUSTOMIZATIONS" = true ] && [ "$OTMM_MODE" = 'core-app' ]; then
	printf "${GREEN}Deploying customizations...${NC}\n"
	source /docker/deploy.sh
fi


#
# Start
#
su jboss # Run as jboss user
set +o nounset
source /opt/jboss/.bash_profile
set -o nounset

printf "${GREEN}Waiting for OpenText Directory Services endpoint to be ready...${NC}\n"
# Poll until OpenText Media Management returns a nonerror status, and therefore the app has fully loaded
for i in {1..100}; do (curl --silent --fail --output /dev/null --head http://opentext-directory-services:8080/otds-v2/services/authentication?wsdl) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to OpenText Directory Services, exiting${NC}\n" && exit 1; fi; done
printf "${GREEN}OpenText Directory Services endpoint ready!${NC}\n"

if [ ! "$DOCKER_MODE" = 'install-on-start' ]; then
	printf "${GREEN}Waiting for OpenText Directory Services password to be set...${NC}\n"
	# Poll until we can get an OpenText Directory Services authentication ticket for tsuper using what the password should be, to verify that the password is correct
	for i in {1..100}; do (java -jar /opt/utilities/opentext-directory-services-http-endpoints-bridge/opentext-directory-services-http-endpoints-bridge-1.0.0-SNAPSHOT.jar get-authentication-ticket tsuper $OTMM_ADMIN_PASSWORD) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to verify OpenText Directory Services superuser password, exiting${NC}\n" && exit 1; fi; done
	printf "${GREEN}OpenText Directory Services password ready!${NC}\n"
fi


if [ "$#" -eq 0 ]; then # No CMD defined in Dockerfile
	printf "${GREEN}Starting OpenText Media Management...${NC}\n"
	cd $TEAMS_HOME/bin

	if [ "$OTMM_MODE" = 'core-app' ]; then
		# The indexer service only starts in 'use-installed-files' mode, so run it as a background process if we’re in 'install-on-start' mode
		if [ "$DOCKER_MODE" = 'install-on-start' ]; then
			(
				printf "${GREEN}Waiting for OpenText Media Management app to load...${NC}\n"
				# Poll until OpenText Media Management returns 403, not 404, and therefore the app has fully loaded
				for i in {1..100}; do ([ $(curl --silent --output /dev/null --head http://opentext-media-management-core-app:11090/otmm/ux-html/index.html --write-out '%{http_code}') = '403' ]) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to OpenText Media Management, exiting${NC}\n" && exit 1; fi; done
				printf "${GREEN}OpenText Media Management core app started!${NC}\n"
				printf "${GREEN}Starting OpenText Media Management indexer service...${NC}\n"
				indexer-process-manager start
			) &
		fi

		# Instead of `mediamanagement-process-manager start`, which runs `JBOSS_PIDFILE=$JBOSS_HOME/otmm-jboss.pid $JBOSS_HOME/bin/otmm-standalone.sh -c otmm.xml`, run the command that determines should run, so that the process stays in the foreground:
		export JBOSS_PIDFILE=$JBOSS_HOME/otmm-jboss.pid
		exec java -D[Standalone] ${JAVA_OPTS:-} -server -XX:+UseCompressedOops -Djboss.node.name=node1 -Djava.net.preferIPv4Stack=true -Djava.security.policy=${JBOSS_HOME}/java.policy -Xms2G -Xmx4G -Dartesia.use_local_interfaces=Y -Dfile.encoding=ISO8859_1 -DTEAMS_HOME=${TEAMS_HOME} -d64 -Dorg.apache.catalina.STRICT_SERVLET_COMPLIANCE=false -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -Duser.language=en -Duser.region=US -DTEAMS_REPOSITORY_HOME=${TEAMS_REPOSITORY_HOME} -Djava.awt.headless=true -Dorg.jboss.boot.log.file=${JBOSS_HOME}/standalone/log/server.log -Dlogging.configuration=file:${JBOSS_HOME}/standalone/configuration/logging.properties -jar ${JBOSS_HOME}/jboss-modules.jar -secmgr -mp ${JBOSS_HOME}/modules:${TEAMS_HOME}:${TEAMS_HOME} org.jboss.as.standalone -Djboss.home.dir=${JBOSS_HOME} -Djboss.server.base.dir=${JBOSS_HOME}/standalone -c otmm.xml -b ${OTMM_JBOSS_BIND_ADDRESS}

	elif [ "$OTMM_MODE" = 'indexer' ]; then

		printf "${GREEN}Waiting for OpenText Media Management app to load...${NC}\n"
		# Poll until OpenText Media Management returns 403, not 404, and therefore the app has fully loaded
		for i in {1..100}; do ([ $(curl --silent --output /dev/null --head http://opentext-media-management-core-app:11090/otmm/ux-html/index.html --write-out '%{http_code}') = '403' ]) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to OpenText Media Management, exiting${NC}\n" && exit 1; fi; done
		printf "${GREEN}OpenText Media Management core app started!${NC}\n"

		printf "${GREEN}Starting OpenText Media Management indexer service...${NC}\n"
		# Instead of `indexer-process-manager start`, which insists on running in the background, run the command-line version of what gets eventually run via `ant start-indexer-unix` per $TEAMS_HOME/install/ant/index.xml:
		exec java ${JAVA_OPTS:-} -Xms128m -Xmx512m -d64 -DTEAMS_HOME=${TEAMS_HOME} -Dlog4j.configuration=file:${TEAMS_HOME}/indexer/log4j.xml -classpath ${TEAMS_HOME}/deploy/*:${TEAMS_HOME}/deploy/artesia/*:${TEAMS_HOME}/deploy/commons/*:${TEAMS_HOME}/deploy/legacy/*:${TEAMS_HOME}/deploy/solrj/*:${JBOSS_HOME}/bin/client/*:${TEAMS_HOME}/jars/* com.artesia.indexer.IndexAssets -fi flat.txt

		# # Alternatively, run as a background process and keep this shell script alive with an infinite loop that breaks if the background process dies:
		# indexer-process-manager start
		# sleep 10
		# while indexer-process-manager status > /dev/null 2>&1; do
		# 	# Still running! Wait a bit, then check again
		# 	sleep 10
		# done
	fi

	# tail -f /dev/null # DEBUGGING: Uncomment this line to keep this container alive if Wildfly or the indexer exits or fails to start
else # Docker CMD provided, so run it
	exec "$@"
fi
