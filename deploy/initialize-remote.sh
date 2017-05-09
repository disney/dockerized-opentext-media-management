#!/usr/bin/env bash
# See http://kvz.io/blog/2013/11/21/bash-best-practices/
set -o errexit
set -o pipefail
set -o nounset
set -o allexport


# This script ensures that an Ubuntu instance that will be our host OS for our cloud-hosted docker-compose network is properly configured
# This script runs on every deployment, so make sure you check that whatever you’re about to modify isn’t already in the state you want to change it to


# Some colors, per http://stackoverflow.com/a/5947802/223225
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


printf "${GREEN}Configuring $LC_MACHINE_NAME...${NC}\n"
sudo su


# Install required packages if they’re not already installed
# - haveged to fix entropy issues: https://www.digitalocean.com/community/tutorials/how-to-setup-additional-entropy-for-cloud-servers-using-haveged
# - lvm2 for attached volumes
# - nano for convenience
# - nfs-common to mount the network share
packages=( 'haveged' 'lvm2' 'nano' 'nfs-common' )
updated=false
for package in "${packages[@]}"; do
	if [ $(dpkg-query -W -f='${Status}' $package 2>/dev/null | grep -c "ok installed") -eq 0 ];
		then
		if [ "$updated" = false ]; then
			apt-get update
			export updated=true
		fi
		printf "${GREEN}Installing $package...${NC}\n"
		apt-get install --yes $package
	else
		echo "$package already installed"
	fi
done


# Configure and mount network attached volume to store Docker data
if ! pvs | grep docker; then
	pvcreate /dev/vdb
	vgcreate docker /dev/vdb
	lvcreate --name data --extents 100%FREE docker
	mkfs -t ext4 /dev/docker/data
fi

mount_string="/dev/mapper/docker-data /var/lib/docker ext4 rw 0 0"
if ! grep -q "$mount_string" /etc/fstab; then # http://stackoverflow.com/a/11287896/223225
	printf "${GREEN}Adding mount for attached volume...${NC}\n"
	echo '' >> /etc/fstab # Add newline
	echo "$mount_string" >> /etc/fstab

	if [ -d /var/lib/docker ]; then
		printf "${GREEN}Mounting attached volume and moving Docker data...${NC}\n"
		service docker stop
		mkdir --parents /mnt/root
		mount --bind / /mnt/root # http://unix.stackexchange.com/a/37767/44496
		mount /dev/docker/data /var/lib/docker
		rsync --remove-source-files --archive --verbose /mnt/root/var/lib/docker/* /var/lib/docker
		service docker start
	else
		printf "${GREEN}Mounting attached volume...${NC}\n"
		mount /dev/docker/data /var/lib/docker
	fi
else
	echo "Network mount for $LC_MACHINE_NAME Docker data already configured"
fi
