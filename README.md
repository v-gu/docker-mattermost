# Docker Mattermost

This image provides the [Mattermost (Team Edition)](https://www.mattermost.org)
chat application server as a Docker image.

- [Introduction](#introduction)
    - [Changelog](CHANGELOG.md)
- [Contributing](#contributing)
- [Issues](#issues)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
    - [Data Store](#data-store)
    - [Database](#database)
        - [MySQL](#mysql)
            - [External MySQL Server](#external-mysql-server)
            - [Linking to MySQL Container](#linking-to-mysql-container)
        - [PostgreSQL](#postgresql)
            - [External PostgreSQL Server](#external-postgresql-server)
            - [Linking to PostgreSQL Container](#linking-to-postgresql-container)
    - [Mail](#mail)
    - [SSL](#ssl)
        - [Generation of Self Signed Certificates](#generation-of-self-signed-certificates)
        - [Strengthening the Server Security](#strengthening-the-server-security)
        - [Installation of the SSL Certificates](#installation-of-the-ssl-certificates)
        - [Running Mattermost with HTTPS](#running-mattermost-with-https)
    - [GitLab Integration](#gitlab-integration)
    - [Available Configuration Parameters](#available-configuration-parameters)
- [Maintenance](#maintenance)
    - [Upgrading](#upgrading)
        - [Upgrading to Version 3](#upgrading-to-version-3)
    - [Shell Access](#shell-access)
- [References](#references)

# Upgrade notes

Since version 3.8 Mattermost supports setting configuration values via
environment variables. As this perfectly matches with common container
practices and allows to remove the logic to write a configuration file from
environment variables during startup, the former environment variable and their
resolution have been removed. This increases maintainability of this image and
keeps it tighter to Mattermost itself.

*This means that you need to redefine any environment variable that you used
before the 3.8 release of this image. See `CHANGELOG.md` for a reference
regarding some important variables.*

# Introduction

Dockerfile to build a [Mattermost](https://www.mattermost.org/) image.

# Contributing

If you find this image useful here's how you can help:

- Send a Pull Request with your awesome new features and bug fixes
- Help new users with [Issues](https://github.com/telota/docker-mattermost/issues) they may encounter

# Issues

Please file a issue request on the [issues](https://github.com/telota/docker-mattermost/issues) page.

# Installation

There are currently no automated builds linked to the source repository,
thus you must build the image locally.

```bash
make
```

# Quick Start

The quickest way to get started is using [docker-compose](https://docs.docker.com/compose/).

```bash
curl -O https://raw.githubusercontent.com/telota/docker-mattermost/master/docker-compose.yml
```

Generate and assign random strings to the `MATTERMOST_SECRET_KEY`, `MATTERMOST_LINK_SALT`, `MATTERMOST_RESET_SALT` and `MATTERMOST_INVITE_SALT` environment variables. Once set you should not change these values and ensure you backup these values.

> **Tip**: You can generate a random string using `pwgen -Bsv1 64`.

Start Mattermost using:

```bash
docker-compose up
```

Alternatively, you can manually launch the `mattermost` container and the supporting `mysql` and `redis` containers by following this three step guide.

Step 1. Launch a mysql container

```bash
docker run --name mattermost-mysql -d \
    --env 'MYSQL_USER=mattermost' --env 'MYSQL_PASSWORD=password' \
    --env 'MYSQL_DATABASE=mattermost' --env 'MYSQL_ROOT_PASSWORD=password' \
    --volume /srv/docker/mattermost/mysql:/var/lib/mysql
    mysql:latest
```

Step 2. Launch the mattermost container

```bash
docker run --name mattermost -d \
    --link mattermost-mysql:mysql \
    --publish 8080:80 \
    --env 'MATTERMOST_SECRET_KEY=long-and-random-alphanumeric-string' \
    --env 'MATTERMOST_LINK_SALT=long-and-random-alphanumeric-string' \
    --env 'MATTERMOST_RESET_SALT=long-and-random-alphanumeric-string' \
    --env 'MATTERMOST_INVITE_SALT=long-and-random-alphanumeric-string' \
    --volume /srv/docker/mattermost/mattermost:/opt/mattermost/data \
    telota/mattermost:3.7.3
```

*Please refer to [Available Configuration Parameters](#available-configuration-parameters) to understand `MATTERMOST_PORT` and other configuration options*

__NOTE__: Please allow a couple of minutes for the Mattermost application to start.

Point your browser to `http://localhost:8080` and create your administrator account.

You should now have the Mattermost application up and ready for testing. If you want to use this image in production the please read on.

*The rest of the document will use the docker command line. You can quite simply adapt your configuration into a `docker-compose.yml` file if you wish to do so.*

# Configuration

## Data Store

Mattermost stores data in the file system for features like file uploads and avatars.
The image defines a volume for that location.

## Database

Mattermost uses a database backend to store its data.
You can configure this image to use MySQL or Postgres.

### MySQL

#### External MySQL Server

The image can be configured to use an external MySQL database. The database configuration should be specified using environment variables while starting the Mattermost image.

Before you start the Mattermost image create a user and database for mattermost.

```sql
CREATE USER 'mattermost'@'%.%.%.%' IDENTIFIED BY 'password';
CREATE DATABASE IF NOT EXISTS `mattermost` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;
GRANT ALL PRIVILEGES ON `mattermost`.* TO 'mattermost'@'%.%.%.%';
```

We are now ready to start the Mattermost application.

*Assuming that the mysql server host is 192.168.1.100*

```bash
docker run --name mattermost -d \
    --env 'DB_ADAPTER=mysql' --env 'DB_HOST=192.168.1.100' \
    --env 'DB_NAME=mattermost' \
    --env 'DB_USER=mattermost' --env 'DB_PASS=password' \
    --volume /srv/docker/mattermost/mattermost:/opt/mattermost/data \
    telota/mattermost:3.7.3
```

#### Linking to MySQL Container

You can link this image with a mysql container for the database requirements. The alias of the mysql server container should be set to **mysql** while linking with the mattermost image.

If a mysql container is linked, only the `DB_ADAPTER`, `DB_HOST` and `DB_PORT` settings are automatically retrieved using the linkage. You may still need to set other database connection parameters such as the `DB_NAME`, `DB_USER`, `DB_PASS` and so on.

To illustrate linking with a mysql container, we will use the official [mysql](https://hub.docker.com/_/mysql/) image. When using mysql in production you should mount a volume for the mysql data store.

First, lets pull the mysql image from the docker index.

```bash
docker pull mysql:latest
```

For data persistence lets create a store for the mysql and start the container.

SELinux users are also required to change the security context of the mount point so that it plays nicely with selinux.

```bash
mkdir -p /srv/docker/mattermost/mysql
sudo chcon -Rt svirt_sandbox_file_t /srv/docker/mattermost/mysql
```

The run command looks like this.

```bash
docker run --name mattermost-mysql -d \
    --env 'MYSQL_USER=mattermost' --env 'MYSQL_PASSWORD=password' \
    --env 'MYSQL_DATABASE=mattermost' --env 'MYSQL_ROOT_PASSWORD=password' \
    --volume /srv/docker/mattermost/mysql:/var/lib/mysql
    mysql:latest
```

The above command will create a database named `mattermost` and also create a user named `mattermost` with the password `password` with full/remote access to the `mattermost` database.

We are now ready to start the Mattermost application.

```bash
docker run --name mattermost -d --link mattermost-mysql:mysql \
    --volume /srv/docker/mattermost/mattermost:/opt/mattermost/data \
    telota/mattermost:3.7.3
```

Here the image will also automatically fetch the `MYSQL_DATABASE`, `MYSQL_USER` and `MYSQL_PASSWORD` variables from the mysql container as they are specified in the `docker run` command for the mysql container. This is made possible using the magic of docker links and works with the following images:

 - [mysql](https://hub.docker.com/_/mysql/)
 - [sameersbn/mysql](https://quay.io/repository/sameersbn/mysql/)
 - [centurylink/mysql](https://hub.docker.com/r/centurylink/mysql/)
 - [orchardup/mysql](https://hub.docker.com/r/orchardup/mysql/)

### PostgreSQL

#### External PostgreSQL Server

The image also supports using an external PostgreSQL server. This is also controlled via environment variables.

```sql
CREATE ROLE mattermost with LOGIN CREATEDB PASSWORD 'password';
CREATE DATABASE mattermost;
GRANT ALL PRIVILEGES ON DATABASE mattermost to mattermost;
```

We are now ready to start the Mattermost application.

*Assuming that the PostgreSQL server host is 192.168.1.100*

```bash
docker run --name mattermost -d \
     --env 'DB_ADAPTER=postgres' --env 'DB_HOST=192.168.1.100' \
     --env 'DB_NAME=mattermost' \
     --env 'DB_USER=mattermost' --env 'DB_PASS=password' \
     --volume /srv/docker/mattermost/mattermost:/opt/mattermost/data \
     telota/mattermost:3.7.3
```

#### Linking to PostgreSQL Container

You can link this image with a postgres container for the database requirements. The alias of the postgres server container should be set to **postgres** while linking with the mattermost image.

If a postgres container is linked, only the `DB_ADAPTER`, `DB_HOST` and `DB_PORT` settings are automatically retrieved using the linkage. You may still need to set other database connection parameters such as the `DB_NAME`, `DB_USER`, `DB_PASS` and so on.

To illustrate linking with a postgres container, we will use the [postgres](https://hub.docker.com/_/postgres/) image. When using postgres image in production you should mount a volume for the postgres data store. Please refer the [postgres](https://hub.docker.com/_/postgres/) documentation for details.

First, lets pull the postgres image from the docker index.

```bash
docker pull postgres:latest
```

For data persistence lets create a store for the postgres and start the container.

SELinux users are also required to change the security context of the mount point so that it plays nicely with selinux.

```bash
mkdir -p /srv/docker/mattermost/postgres
sudo chcon -Rt svirt_sandbox_file_t /srv/docker/mattermost/postgres
```

The run command looks like this.

```bash
docker run --name mattermost-postgres -d \
    --env 'POSTGRES_USER=mattermost' --env 'POSTGRES_PASSWORD=password' \
    --volume /srv/docker/mattermost/postgres:/var/lib/postgresql \
    postgresql:latest
```

The above command will create a database named `mattermost` and also create a user named `mattermost` with the password `password` with access to the `mattermost` database.

We are now ready to start the Mattermost application.

```bash
docker run --name mattermost -d --link mattermost-postgres:postgres \
     --volume /srv/docker/mattermost/mattermost:/opt/mattermost/data \
     telota/mattermost:3.7.3
```

Here the image will also automatically fetch the `POSTGRES_DB`, `POSTGRES_USER` and `POSTGRES_PASSWORD` variables from the postgres container as they are specified in the `docker run` command for the postgres container. This is made possible using the magic of docker links and works with the official [postgres](https://hub.docker.com/_/postgres/) image.

### Mail

The mail configuration should be specified using environment variables while starting the Mattermost image.

If you are using Gmail then all you need to do is:

```bash
docker run --name mattermost -d \
    --env 'SMTP_USER=USER@gmail.com' --env 'SMTP_PASS=PASSWORD' \
    --env 'SMTP_HOST=smtp.gmail.com' --env 'SMTP_PORT=587' \
    --volume /srv/docker/mattermost/mattermost:/opt/mattermost/data \
    telota/mattermost:3.7.3
```

Please refer the [Available Configuration Parameters](#available-configuration-parameters) section for the list of SMTP parameters that can be specified.

### Available Configuration Parameters

This image comes with the [default configuration file](https://github.com/mattermost/platform/blob/master/config/config.json#)
which you may replace by mounting your customized one into
`/opt/mattermost/mattermost/config`.

It is however recommended to override setting with
[environment variables](https://docs.mattermost.com/administration/config-settings.html).
For the defaults see the config file linked above.

Please refer to [this documentation](https://docs.mattermost.com/administration/config-settings.html)
regarding naming of environment variables and available configuration options.

**MAKE SURE THAT ANY OF YOUR DEPLOYMENTS IS CONFIGURED WITH UNIQUE VALUES PER
INSTANCE FOR EACH OF THESE SETTINGS:**

(noted by their environment variable name here)

- `MM_EMAILSETTINGS_INVITESALT` (formerly `MATTERMOST_INVITE_SALT`)
- `MM_EMAILSETTINGS_PASSWORDRESETSALT` (formerly `MATTERMOST_RESET_SALT`)
- `MM_SQLSETTINGS_ATRESTENCRYPTKEY` (formerly `MATTERMOST_SECRET_KEY`)

Furthermore you need to set `MM_SERVICESETTINGS_SITEURL`.


# Maintenance

## Upgrading

Mattermost releases new versions on the 16th of every month.  I will update this project shortly after a release is made.

To upgrade to newer Mattermost releases, simply follow this 4 step upgrade procedure.

- **Step 1**: Update the docker image.

See [installation notes](#Installation) above.

- **Step 2**: Stop and remove the currently running image

```bash
docker stop mattermost
docker rm mattermost
```

- **Step 3**: Create a backup

Backup your database and local file storage by your preferred backup method.  All of the necessary data is located under `/srv/docker/mattermost` if the docker volume conventions of this guide are followed.

- **Step 4**: Start the image

```bash
docker run --name mattermost -d [OPTIONS] telota/mattermost:3.7.3
```

## Shell Access

For debugging and maintenance purposes you may want access the containers shell. If you are using docker version `1.3.0` or higher you can access a running containers shell using `docker exec` command.

```bash
docker exec -it mattermost bash
```

# References

* [Mattermost changelog](https://docs.mattermost.com/administration/changelog.html)
* [Mattermnost source repository](https://github.com/mattermost/platform)
* [Mattermost documentation](https://docs.mattermost.com)
