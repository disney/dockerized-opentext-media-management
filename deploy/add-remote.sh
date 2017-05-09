#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport

# Based on https://gitlab.wdi.disney.com/snippets/5


# Make sure we’re running in the same folder as this file; http://stackoverflow.com/a/246128/223225
containing_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $containing_folder


# Docker is required; per http://stackoverflow.com/a/677212/223225
if ! hash docker-machine 2>/dev/null; then
	echo >&2 'Please install Docker and try again.'
	exit 1
fi


echo 'Once you’ve followed the instructions in deploy/README.md to create a new'
echo 'server instance, this script will create a new docker-machine on your'
echo 'computer that points to the instance; *and* the machine will be added to'
echo 'the deploy/machines folder for you to commit to the repo.'
# http://stackoverflow.com/a/3232082/223225
read -r -p 'Do you wish to continue? [y/N] ' response
if [[ ! $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
	exit 0
fi


if [ ! -n "${MACHINE_NAME+1}" ]; then
	echo 'Please enter the name of the instance, e.g. dev: '
	read -r MACHINE_NAME_INPUT
	export MACHINE_NAME="$MACHINE_NAME_INPUT"
fi

if [ ! -n "${IP_ADDRESS+1}" ]; then
	echo 'Please enter the IP address of the instance, e.g. 1.2.3.4: '
	read -r IP_ADDRESS_INPUT
	export IP_ADDRESS="$IP_ADDRESS_INPUT"
fi

if [ ! -n "${SSH_USERNAME+1}" ]; then
	# The username to use while connecting to the image. Varies by image.
	export SSH_USERNAME='ubuntu'
fi


echo "Creating Docker machine $MACHINE_NAME..."
docker-machine create "$MACHINE_NAME" \
	--driver generic \
	--generic-ip-address "$IP_ADDRESS" \
	--generic-ssh-user "$SSH_USERNAME"

echo 'Copying new machine into the repo...'
cp -r "$HOME/.docker/machine/machines/$MACHINE_NAME" ./machines
cp ./machines/$(ls -1 machines | awk 'NR==1{print $1}')/ca-key.pem "./machines/$MACHINE_NAME"
# Remove the reference to a specific user’s absolute path
sed -i '' "s|$HOME/.docker|~/.docker|g" "./machines/$MACHINE_NAME/config.json"
# Update the references to certs
sed -i '' "s|.docker/machine/certs|.docker/machine/machines/$MACHINE_NAME|g" "./machines/$MACHINE_NAME/config.json"
mv "./machines/$MACHINE_NAME/config.json" "./machines/$MACHINE_NAME/config-example.json"
mkdir -p "./ssl/$MACHINE_NAME"
git add "./machines/$MACHINE_NAME" || echo 'You don’t seem to have git installed'


echo 'Docker machine created!'
echo "Create a deploy/docker-compose/$MACHINE_NAME.yml file to define the"
echo "environment variables for this new instance, and run"
echo "  deploy.sh $MACHINE_NAME"
echo "to deploy to it."
