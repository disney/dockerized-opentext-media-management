#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport


# Some colors, per http://stackoverflow.com/a/5947802/223225
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


# Make sure we’re running in the same folder as this file; http://stackoverflow.com/a/246128/223225
containing_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $containing_folder


only_setup=false
build=true
erase_volumes=false
machine_name=


if [[ $# -eq 0 ]] ; then # Based on http://stackoverflow.com/a/2428006/223225
	echo "Usage: $0 --help"
	exit 1
fi

while test $# -gt 0; do # Based on http://stackoverflow.com/a/7069755/223225
	case "$1" in
		-h|--help)
			printf "Deploy the current build of this project ${RED}to an external server${NC}\n"
			echo "syntax:  $0 (options) (name of the external server instance Docker machine)"
			echo "example: $0 media-vault-dev"
			echo
			echo 'options:'
			echo '--only-setup      install the Docker machine for the external server, but don’t deploy'
			echo '--skip-build      don’t recompile before uploading the built files'
			echo '--erase-volumes   reset the database and repository on the remote server'
			exit 0
			;;
		--only-setup)
			export only_setup=true
			shift
			;;
		--skip-build)
			export build=false
			shift
			;;
		--erase-volumes)
			export erase_volumes=true
			shift
			;;
		*)
			export machine_name=$1
			shift
			;;
	esac
done


if ! hash docker-machine 2>/dev/null; then
	echo >&2 'Please install Docker and try again.'
	exit 1
fi
# Add this machine to the user’s system docker machines, even if they have it already (in case anything has changed about it in the repo)
if [ -d "$HOME/.docker/machine/machines/$machine_name" ]; then
	docker-machine rm -y "$machine_name"
fi
mkdir -p "$HOME/.docker/machine/machines"
cp -pR "$containing_folder/deploy/machines/$machine_name" "$HOME/.docker/machine/machines/"
cp "$HOME/.docker/machine/machines/$machine_name/config-example.json" "$HOME/.docker/machine/machines/$machine_name/config.json"
# http://stackoverflow.com/a/4247319/223225
sed -i '' "s|~/.docker|$HOME/.docker|g" "$HOME/.docker/machine/machines/$machine_name/config.json"
echo "Added Docker machine $machine_name"
if [ "$only_setup" = true ]; then
	exit 0
fi


# Ensure that the remote server has required packages and network mounts
printf "${GREEN}Configuring the remote server...${NC}\n"
# It’s an awful hack, but the ssh client passes along environment variables prefixed with LC_; http://superuser.com/a/480029/138751
export LC_MACHINE_NAME=$machine_name
ssh -T ubuntu@$DOCKER_MACHINE_IP 'bash -s' < ./deploy/initialize-remote.sh # http://stackoverflow.com/a/21221449/223225


# Archive the Docker logs before we restart Docker and thereby wipe out the logs
ssh -T ubuntu@$DOCKER_MACHINE_IP 'bash -s' < ./deploy/archive-logs.sh


# Rebuild and restart the docker-compose network on the destination server
cd docker
eval $(docker-machine env $machine_name)

printf "${GREEN}Stopping the Docker network on the remote server...${NC}\n"
docker-compose --file docker-compose.yml --file docker-compose.hosted.yml --file "../deploy/docker-compose/$machine_name.yml" down

if [ "$erase_volumes" = true ]; then
	printf "${GREEN}Erasing and recreating the Docker volumes on the remote server...${NC}\n"
	./erase-volumes.sh
fi

printf "${GREEN}Rebuilding the Docker images on the remote server...${NC}\n"
ssh -T ubuntu@$DOCKER_MACHINE_IP 'bash -s' < ./cleanup.sh || true

docker-compose --file docker-compose.yml --file docker-compose.hosted.yml --file "../deploy/docker-compose/$machine_name.yml" build

printf "${GREEN}Starting the Docker network on the remote server...${NC}\n"
docker-compose --file docker-compose.yml --file docker-compose.hosted.yml --file "../deploy/docker-compose/$machine_name.yml" up -d


cd $containing_folder
printf "${GREEN}Deployment to $machine_name complete!${NC}\n"
