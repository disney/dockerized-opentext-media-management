# OpenText Media Management 16.2 in Docker Deployment

Deploying, once you have a Docker machine configured for your machine, is as simple as:

```bash
./deploy.sh machine-name-here
```

from the root of the repo. If you don’t have the Docker machine set up on your machine yet, follow one of the sets of instructions below to either tell your machine where to find it (if it was already created by a different machine) or to create a new machine and server instance.

## Prerequisites

If you’re using [Mac OS X Sierra 10.12.2 or later](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/), make sure the following is in your `~/.ssh/config` file:

```conf
Host *
	AddKeysToAgent yes
	UseKeychain yes
	IdentityFile ~/.ssh/id_rsa
	SendEnv LANG LC_*
```

Note especially the last line.

## Accessing an existing server instance

When a new `docker-machine` server instance is created, the machine that created it is automatically configured to continue to access that instance. If you want to later access that instance from a different computer, whether to simply read the logs or to deploy, follow these steps:

1. On the new machine, [generate SSH keys](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/) if you haven’t already.
1. Copy the SSH public key, probably from `~/.ssh/id_rsa.pub`, to a machine that already has access to the instance. You can simply IM it:

	```sh
	cat ~/.ssh/id_rsa.pub | pbcopy
	# Then paste into Slack or an email or similar to get the data to the other machine
	```

1. On the old machine, copy the key that was IMed or emailed.
1. On the old machine, SSH into the server instance:

	```sh
	docker-machine ssh machine-name-here
	```

1. Add the key to the end of `~/.ssh/authorized_keys`:

	```sh
	echo "paste key here between the quotes" >> ~/.ssh/authorized_keys
	```

	For example:

	```sh
	echo "ssh-rsa AAAAB3NzaC1yc2E+T4/M7UWM/IQ== geoffrey.booth@disney.com" >> ~/.ssh/authorized_keys
	```

1. Back on the new machine, configure your local Docker with the new machine:

	```sh
	./deploy.sh --only-setup machine-name-here
	```

That should be it! Verify that you can access the instance from your new machine:

```
docker-machine ssh machine-name-here
```

## Creating a new server instance and adding it to the repo

### Create a new local Docker machine

[Create an instance to deploy to, and configure docker-machine on your local machine to connect to it.](https://docs.docker.com/machine/get-started-cloud/) You should see this instance, e.g. `machine-name-here`, when you run `docker-machine ls`.

Read through `initialize-remote.sh` and either update that script or configure your instance as appropriate. The script assumes attached volume at `/dev/vdb` that it can format and mount, and a network share at `/mnt/opentext-media-management-repository` where asset files and backups can be stored.

### Add the new instance to the project

In order for the deploy script to work, a `docker-machine` folder for this new instance needs to be created and added to the project. Go to `deploy` and run `add-remote.sh`. It will prompt you for the instance/machine name and instance IP address. Once supplied, it will create a new Docker machine for this instance, which you should afterward see via `docker-machine ls`. The folder containing this machine’s config files will be copied into the project, into `deploy/machines/machine-name-here`. Make sure you commit this addition so that the rest of the team can access this instance (unless it is sensitive and meant to be private).

### Configure `docker-compose` for the new instance

Copy `deploy/docker-compose/-default.yml` to `deploy/docker-compose/machine-name-here.yml` and update as appropriate for the new instance. Make sure you update the domain name.

### Configure SSL

Once you have an SSL certificate and key for the new instance, update the `SSL_*` environment variables in your `deploy/docker-compose/machine-name-here.yml`.
