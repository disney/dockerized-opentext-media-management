#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context


printf "${GREEN}Creating archive of files added or updated by OpenText Media Management installation...${NC}\n"
cd /
tar -zcf opentext-media-management-installed-files-$TIMESTAMP.tar.gz \
	opt/jboss/.bash_profile \
	opt/jboss/wildfly/bin/otmm-standalone.bat \
	opt/jboss/wildfly/bin/otmm-standalone.conf \
	opt/jboss/wildfly/bin/otmm-standalone.conf.bat \
	opt/jboss/wildfly/bin/otmm-standalone.sh \
	opt/jboss/wildfly/java.policy \
	opt/jboss/wildfly/modules/otmm-postgresql-driver/ \
	opt/jboss/wildfly/modules/system/layers/base/com/sun/xml/bind/main/jaxb-xjc-2.2.11.jar \
	opt/jboss/wildfly/standalone/configuration/mgmt-groups.properties \
	opt/jboss/wildfly/standalone/configuration/mgmt-users.properties \
	opt/jboss/wildfly/standalone/configuration/otmm.xml \
	opt/jboss/wildfly/standalone/log/ \
	opt/jboss/wildfly/welcome-content/favicon.ico \
	opt/opentext-media-management \
	root/.bash_profile \
	var/.com.zerog.registry.xml
printf "${GREEN}Archive ready! Copy it out of the repo via:${NC}\n"
printf "${YELLOW}docker cp otmm_opentext-media-management-core-app_1:/opentext-media-management-installed-files-$TIMESTAMP.tar.gz ~/Downloads/new-snapshots\n"

printf "${GREEN}Creating dump of database after OpenText Media Management installation...${NC}\n"
PGPASSWORD=$POSTGRES_PASSWORD pg_dumpall --host=$POSTGRES_SERVER --username=$POSTGRES_USER | gzip > /database-post-opentext-media-management-installation-$TIMESTAMP.sql.gz
printf "${GREEN}Database dump ready! Copy it out of the repo via:${NC}\n"
printf "${YELLOW}docker cp otmm_opentext-media-management-core-app_1:/database-post-opentext-media-management-installation-$TIMESTAMP.sql.gz ~/Downloads/new-snapshots\n"
