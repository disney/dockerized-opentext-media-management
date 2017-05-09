#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context


# Move licenses into place
if [ -f /opt/license ]; then
	rm $TEAMS_HOME/servers/license
	mv /opt/license $TEAMS_HOME/servers/
fi
if [ -f /opt/license.dat ]; then
	rm $TEAMS_HOME/servers/license.dat
	mv /opt/license.dat $TEAMS_HOME/servers/
fi


#
# Update system settings
#

# PROVIDER_HOST must resolve to the same IP address as OTMM_JBOSS_BIND_ADDRESS below, per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-igd/en/html/jsframe.htm?updt-prvdr-hst
if [ "$OTMM_MODE" = 'core-app' ]; then
	OTMM_JBOSS_BIND_ADDRESS=$(hostname -i)
else
	# Get the IP address of the OTMM core app server; http://unix.stackexchange.com/a/20793/44496
	OTMM_JBOSS_BIND_ADDRESS=$(getent hosts opentext-media-management-core-app | awk '{ print $1 ; exit }')
fi
sed --in-place "s/\"PROVIDER_HOST\"=\"remote:\/\/localhost:11099\"/\"PROVIDER_HOST\"=\"remote:\/\/$OTMM_JBOSS_BIND_ADDRESS:11099\"/" $TEAMS_HOME/data/cs/global/Tresource

if [ "$OTMM_MODE" = 'core-app' ]; then
	# Configure VIDEO_BASE_URL to point to Nginx container serving the repository assets; must do this via a direct database query unfortunately
	PGPASSWORD=$DATABASE_USER_PASSWORD psql --host=$POSTGRES_SERVER --dbname=otmm --username=tsuper --command="UPDATE otmm_sys_config_settings SET config_value = '$APP_ROOT_URL/media-vault/repository' WHERE name = 'VIDEO_BASE_URL'"

	# Configure TRANSCODE_HOST to point to ffmpeg container and port, per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160001/medmgt-igd/en/html/jsframe.htm?run-ffmpeg-external
	PGPASSWORD=$DATABASE_USER_PASSWORD psql --host=$POSTGRES_SERVER --dbname=otmm --username=tsuper --command="UPDATE otmm_sys_config_settings SET config_value = 'ffmpeg:9000' WHERE name = 'TRANSCODE_HOST'"

	# Configure ALLOW_REMOTE_USER_LOGIN to 'Y' to allow remote user headers (see section 7.1.3.1 of
	# https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-ain/en/html/_manual.htm)
	PGPASSWORD=$DATABASE_USER_PASSWORD psql --host=$POSTGRES_SERVER --dbname=otmm --username=tsuper --command="UPDATE otmm_sys_config_settings SET config_value = 'Y' WHERE name = 'ALLOW_REMOTE_USER_LOGIN'"

	# By default, if a user tries to download asset larger than 25 MB, the user is prompted to use “Share” to export the asset
	# If the setting that controls this is still set to the default 25 MB, crank it up to 25 GB
	PGPASSWORD=$DATABASE_USER_PASSWORD psql --host=$POSTGRES_SERVER --dbname=otmm --username=tsuper --command="UPDATE otmm_sys_config_settings SET config_value = '26843545600' WHERE name = 'MAX_CONTENT_VIEW_SIZE' AND config_value = '26214400'"

	# Increase logging
	sed --in-place 's|<root-logger>|\n<logger category="com.disney"><level name="TRACE"/></logger>\n\n<logger category="com.opentext.mediamanager.restapi.disney.resource"><level name="TRACE"/></logger>\n            <root-logger>|g' $JBOSS_HOME/standalone/configuration/otmm.xml

	# Change from 24-hour log rotation to size based
	sed --in-place 's/periodic-size-rotating-file-handler/size-rotating-file-handler/g' $JBOSS_HOME/standalone/configuration/otmm.xml

	# Increase default log rotation size
	sed --in-place 's/rotate-size value="50m"/rotate-size value="10000g"/' $JBOSS_HOME/standalone/configuration/otmm.xml

	# Patch OTMM’s JavaScript so that the call to /systemdetails returns the correct hostname for OTDS, so that redirects for logout/new session/etc. work
	# Replace in `a.fetchSystemDetails=function r(b){var c=a.service+"/systemdetails";$.ajax({type:"GET",url:c,success:function(a){var c=(((a||{}).system_details_resource||{}).system_details_map||{}).entry||{};b(c)},error:function(a){b({})}})}`
	sed --in-place "s~a\.fetchSystemDetails=function r(b){var c=a\.service+\"/systemdetails\";\$\.ajax({type:\"GET\",url:c,success:function(a){var c=(((a||{})~a.fetchSystemDetails=function r(b){var c=a.service+\"/systemdetails\";$.ajax({type:\"GET\",url:c,success:function(a){var c=(((JSON.parse(JSON.stringify(a||{}).replace('http://opentext-directory-services:8080','$APP_ROOT_URL'))||{})~" $TEAMS_HOME/ear/artesia.ear/otmmux.war/ux-html/dist/ui.min.js
fi


#
# Update passwords
#

# Update OTMM `tsuper` Postgres user password, per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-agd/en/html/jsframe.htm?change-db-info
cat >$TEAMS_HOME/servers/TEAMS_SEC_Srv.cfg <<EOF
$DATABASE_USER_PASSWORD
tsuper
EOF
cd $TEAMS_HOME/bin
crypt.sh ef $TEAMS_HOME/servers/TEAMS_SEC_Srv.cfg

# Update Indexer `tsuper` OTMM user login, per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-agd/en/html/jsframe.htm?indexer-login-73forward
cat >$TEAMS_HOME/servers/index_SEC.cfg <<EOF
tsuper
$OTMM_ADMIN_PASSWORD
EOF
cd $TEAMS_HOME/install/ant
ant encrypt-indexer-login

# Update OTDS login, per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-agd/en/html/jsframe.htm?changing-otds-login
cat >$TEAMS_HOME/servers/OTDS_SEC_Srv.cfg <<EOF
otadmin@otds.admin
$OTDS_ADMIN_PASSWORD
EOF
cd $TEAMS_HOME/install/ant
ant encrypt-otds-login

# TODO: Update JBoss admin user password? https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-agd/en/html/jsframe.htm?jboss-pswrd


#
# Activate resource IDs, so that OTMM and OTDS know how to communicate with each other
# Only run this on the core app server, so that we don’t have both the core app server and indexer trying to activate resources at the same time
#

if [ "$OTMM_MODE" = 'core-app' ] && [ ! "$DOCKER_MODE" = 'install-on-start' ]; then
	jar=/opt/utilities/opentext-directory-services-http-endpoints-bridge/opentext-directory-services-http-endpoints-bridge-1.0.0-SNAPSHOT.jar

	printf "${GREEN}Deactivating the “OTMM” resource...${NC}\n"
	java -jar $jar deactivate-resource OTMM

	printf "${GREEN}Deleting the resource IDs from the OTMM database...${NC}\n"
	PGPASSWORD=$DATABASE_USER_PASSWORD psql --host=$POSTGRES_SERVER --dbname=otmm --username=tsuper --command="TRUNCATE TABLE otds_resources"

	printf "${GREEN}Activating the “OTMM” resource...${NC}\n"
	# First we need to get the resource ID
	resource_id=$(java -jar $jar get-resource-by-name OTMM resourceID)
	# Based on $TEAMS_HOME/bin/ActivateResource.sh
	(
		# Run this in a subshell to avoid clobbering the parent shell’s environment variables
		set +o nounset
		source $TEAMS_HOME/bin/setupOtdsEnv
		$JAVACMD com.opentext.mediamanager.otds.OtdsServices http://opentext-directory-services:8080 $resource_id
	)
fi


printf "${GREEN}Configuring jboss user...${NC}\n"
# Fix 'account is currently not available' per https://geekpeek.net/this-account-is-currently-not-available-login-problems/
chsh -s /bin/bash jboss


printf "${GREEN}Mapping app logs to Docker logs...${NC}\n"
# Based on https://github.com/nginxinc/docker-nginx/blob/1f7e3c6473c2c6211c305d85cdfcfd733fe1b348/mainline/jessie/Dockerfile
if [ "$OTMM_MODE" = 'core-app' ]; then
	ln --symbolic --force /dev/stdout $TEAMS_HOME/logs/mediamanager-appserver.log
elif [ "$OTMM_MODE" = 'indexer' ]; then
	ln --symbolic --force /dev/stdout $TEAMS_HOME/logs/indexer-service.log
	ln --symbolic --force /dev/stdout $TEAMS_HOME/logs/indexer.log
fi
