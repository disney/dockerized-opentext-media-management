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


#
# Connect to required services
#
printf "${GREEN}Waiting for OpenText Media Management app to load...${NC}\n"
# Poll until OpenText Media Management returns 403, not 404, and therefore the app has fully loaded
for i in {1..100}; do ([ $(curl --silent --output /dev/null --head http://opentext-media-management-core-app:11090/otmm/ux-html/index.html --write-out '%{http_code}') = '403' ]) > /dev/null 2>&1 && break || if [ "$i" -lt 101 ]; then sleep $((i * 2)); else printf "${RED}Unable to connect to OpenText Media Management, exiting${NC}\n" && exit 1; fi; done
printf "${GREEN}OpenText Media Management core app started!${NC}\n"


#
# Configure ffmpeg
#
printf "${GREEN}Configuring ffmpeg...${NC}\n"
cd $FFMPEG_HOME
# Update config file with values from environment variables
sed --in-place "s|\$POSTGRES_SERVER|$POSTGRES_SERVER|" ./conf/transcoder.properties
sed --in-place "s|\$DATABASE_USER_PASSWORD|$DATABASE_USER_PASSWORD|" ./conf/transcoder.properties

# Prevent the following command from crashing because of missing files
if [ ! -d /opt/ffmpeg-transcoder/bin/linux ]; then
	mkdir --parents /opt/ffmpeg-transcoder/bin/linux
	cp /opt/ffmpeg-transcoder/bin/ffmpegService /opt/ffmpeg-transcoder/bin/linux
	cp /opt/ffmpeg-transcoder/bin/jsvc /opt/ffmpeg-transcoder/bin/linux
fi
# Configure ffmpeg
ant configure-ffmpeg


#
# Start, per https://knowledge.opentext.com/knowledge/piroot/medmgt/v160001/medmgt-igd/en/html/jsframe.htm?run-ffmpeg-external
#
printf "${GREEN}Starting ffmpeg server...${NC}\n"
# Instead of `bin/ffmpegService start`, adapt that shell script to run in foreground in PID 1 (using `-nodetach`):
APPLICATION_NAME=FFMPEG
STOPKEY=secret
STOPPORT=5
JSVC_EXEC=$FFMPEG_HOME/bin/jsvc
CLASS_PATH=$FFMPEG_HOME/lib/*:FFMPEG_HOME/lib/ffmpeg-transcoder.jar
MAIN_CLASS=com.artesia.server.video.transcode.FFmpegServerDaemonLinux
MAIN_CLASS_START_ARGS=STOP.KEY=secret\ STOP.PORT=50001
MAIN_CLASS_STOP_ARGS=--stop\ STOP.KEY=secret\ STOP.PORT=$STOPPORT
PID=$FFMPEG_HOME/ffmpeg.pid
LOG_OUT_FILE=$FFMPEG_HOME/logs/installation/$APPLICATION_NAME.out
LOG_ERR_FILE=$FFMPEG_HOME/logs/installation/$APPLICATION_NAME.err
JVM_PARAMS=-Dlogfile=$FFMPEG_HOME/logs/ffmpeg-transcoder.log\ -Dlog4j.configuration=file:$FFMPEG_HOME/conf/log4j.xml

# Default command: `$JSVC_EXEC -jvm server -debug -cp $CLASS_PATH $JVM_PARAMS -outfile $LOG_OUT_FILE -errfile $LOG_ERR_FILE -pidfile $PID $MAIN_CLASS $MAIN_CLASS_START_ARGS`
exec $JSVC_EXEC -nodetach -jvm server -debug -cp $CLASS_PATH $JVM_PARAMS $MAIN_CLASS $MAIN_CLASS_START_ARGS
