# Docker Mattermost

This image provides the [Mattermost (Team Edition)](https://www.mattermost.org)
chat application server as a Docker image.


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


# Quick Start

The quickest way to get started is using [docker-compose](https://docs.docker.com/compose/).

Copy the [`docker-compose.yml`](https://raw.githubusercontent.com/telota/docker-mattermost/master/docker-compose.yml)
file, adjust as needed and start the project's containers:

    docker-compose up


You can generate the random strings for salts &ndash; though this isn't needed for testing purposes &ndash; with:

    pwgen -s1 32


With the provided example configuration, open http://localhost:8080 in a
browser and create your administrator account.

You should now have the Mattermost application up and ready for testing. If you want to use this image in production the please read on.


# Configuration

## Configuration file and environment variables

This image comes with the [default configuration file](https://github.com/mattermost/platform/blob/master/config/config.json)
which you may replace by mounting your customized one into
`/opt/mattermost/mattermost/config`.

It is however recommended to override setting with environment variables.
For the defaults see the config file linked above. Please refer to
[this documentation](https://docs.mattermost.com/administration/config-settings.html)
regarding naming of environment variables and available configuration options.

**MAKE SURE THAT ANY OF YOUR DEPLOYMENTS IS CONFIGURED WITH UNIQUE VALUES PER
INSTANCE FOR EACH OF THESE SETTINGS:**

(noted by their environment variable name here)

- `MM_EMAILSETTINGS_INVITESALT`
- `MM_EMAILSETTINGS_PASSWORDRESETSALT`
- `MM_SQLSETTINGS_ATRESTENCRYPTKEY`

Furthermore you need to set `MM_SERVICESETTINGS_SITEURL`.

You may set `DEBUG` to `true` for a verbose bootstrapping and to set
Mattermost's debug level to `DEBUG`.

## File Assets Store

Mattermost stores data in the file system for assets like file uploads and avatars.
The image defines a [volume](https://docs.docker.com/engine/tutorials/dockervolumes/)
for that location.

## Database

Mattermost uses a database backend to store most of its data.
You can configure this image to use MySQL or Postgres.

### Autodiscovery

The simplest configuration uses a container dedicated as database backend, like
in the example `docker-compose.yml`.
As the service names (`postgres` or `mysql`) will be used as hostnames, these
will be probed and any configuration values will be derived from it and use
default values. Just make sure that `DB_PASS` in the `mattermost` service and
`POSTGRES_PASSWORD` resp. `MYSQL_ROOT_PASSWORD` in the database service are
identical.

### Datasource URL

You can also define the database configuration as URL with the
`MM_SQLSETTINGS_DATASOURCE` and an according `MM_SQLSETTINGS_DRIVERNAME`
environment variable.

### Granular settings variables

Lastly the `MM_SQLSETTINGS_DATASOURCE` variable can be assembled from these
variables:

- `MM_SQLSETTINGS_DRIVERNAME` (determines postgres / mysql defaults)
- `DB_ENCODING` (default: none / `utf8mb4,utf8`)
- `DB_HOST`
- `DB_NAME` (default: `mattermost`)
- `DB_PARAMS` (default: `sslmode=disable&connect_timeout=10` / `charset=${DB_ENCODING}`)
- `DB_PASS`
- `DB_PORT` (default: `5432` / `3306`)
- `DB_USER` (default: `postgres` / `root`)


# Building the image

The source repository contains a `Makefile` that can be used to build the image
locally:

    make


# References

- [Source repository of this image](https://github.com/telota/docker-mattermost)
- [Image repository on the Docker Hub](https://hub.docker.com/r/telota/mattermost-team-edition/)

- [Mattermost changelog](https://docs.mattermost.com/administration/changelog.html)
- [Mattermnost source repository](https://github.com/mattermost/platform)
- [Mattermost documentation](https://docs.mattermost.com)
