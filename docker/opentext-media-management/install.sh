#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport
# set -o xtrace


# This file assumes it is being sourced from entrypoint.sh, including the environment variables available from that context


printf "${GREEN}Installing OpenText Media Management...${NC}\n"
mkdir -p /opt/opentext-media-management
# Per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-igd/en/html/jsframe.htm?aid-32 and “silent” per https://knowledge.opentext.com/knowledge/cs.dll/open/62770001
/opt/opentext-media-management-installer/OTMM/Disk1/InstData/NoVM/install.sh -i silent -f /opt/mediamanagement_config.txt


printf "${GREEN}Removing install files...${NC}\n"
rm -rf /opt/mediamanagement_config.txt /opt/opentext-media-management-installer


# Copy root .bash_profile to jboss user .bash_profile per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-igd/en/html/jsframe.htm?set-user-env
/bin/cp ~/.bash_profile /opt/jboss/.bash_profile
set +o nounset
source /opt/jboss/.bash_profile # Load new environment variables created by installation
set -o nounset


printf "${GREEN}Configuring OpenText Media Management...${NC}\n"
# Add settings for Solr, per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-igd/en/html/jsframe.htm?inst-solr-sep-srv-unix
sed --in-place 's|"SOLR_HOST"=""|"SOLR_HOST"="solr"|' $TEAMS_HOME/data/cs/global/Tresource
sed --in-place 's|"SOLR_URL"=""|"SOLR_URL"="http://solr:8983/solr"|' $TEAMS_HOME/data/cs/global/Tresource

sed --in-place 's|<property name="solr.host" value=""/>|<property name="solr.host" value="solr"/>|' $TEAMS_HOME/install/ant/build.cfg
sed --in-place 's|<property name="solr.url" value=""/>|<property name="solr.url" value="http://solr:8983/solr"/>|' $TEAMS_HOME/install/ant/build.cfg
# TODO: Maybe edit ${TEAMS_HOME}/bin/artesia-process-manager-wrapper-unix.conf per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-igd/en/html/jsframe.htm?edit-srvc-cfg? Seems okay by default


printf "${GREEN}Configuring Wildfly...${NC}\n"
# Tell Wildfly to bind to the host IP address, since binding to all (like the `-b 0.0.0.0` in the official Wildfly Dockerfile) doesn’t work; see http://stackoverflow.com/a/29463772/223225
sed --in-place 's/OTMM_JBOSS_BIND_ADDRESS=/OTMM_JBOSS_BIND_ADDRESS=$(hostname -i)/' $JBOSS_HOME/bin/otmm-standalone.conf
# Fix some deprecations
sed --in-place 's/-XX:MaxPermSize=512m //' $JBOSS_HOME/bin/otmm-standalone.conf
sed --in-place 's/CMSPermGenSweepingEnabled/CMSClassUnloadingEnabled/' $JBOSS_HOME/bin/otmm-standalone.conf
# TODO: Maybe edit $JBOSS_HOME/bin/otmm-standalone.conf per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-igd/en/html/jsframe.htm?jboss if it seems to OTMM that there are multiple OTMM installations on this “network”


printf "${GREEN}Changing folder ownership...${NC}\n"
chown -R jboss:jboss $TEAMS_HOME
chown -R jboss:jboss $JBOSS_HOME
chown -R jboss:jboss $TEAMS_REPOSITORY_HOME


printf "${GREEN}Configuring OpenText Directory Services...${NC}\n"
# TODO: Create user partitions? Per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160000/medmgt-igd/en/html/jsframe.htm?config-user-partitions
