#!/usr/bin/env bash
#
# This file is part of the Moodle Continuous Integration Project.
#
# Moodle is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Moodle is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Moodle.  If not, see <https://www.gnu.org/licenses/>.

# Docker PHP module functions.

# This module defines the following env variables.
function docker-php_env() {
    env=(
        PHP_VERSION
        DOCKER_PHP
        WEBSERVER
    )
    echo "${env[@]}"
}

# Docker module checks.
function docker-php_check() {
    # Check all module dependencies.
    verify_modules docker env

    # These env variables must be set for the module to work.
    verify_env ENVIROPATH NETWORK UUID COMPOSERCACHE SHAREDDIR
}

# Docker module init.
function docker-php_config() {
    # Apply some defaults (always set to the minimum version supported in the main branch).
    PHP_VERSION="${PHP_VERSION:-8.2}"
    DOCKER_PHP="${DOCKER_PHP:-moodlehq/moodle-php-apache:${PHP_VERSION}}"
    WEBSERVER=webserver"${UUID}"
}

# Docker module setup, start the PHP webserver container.
function docker-php_setup() {
    echo ">>> startsection Starting web server <<<"
    echo "============================================================================"

    docker run \
      --network "${NETWORK}" \
      --name "${WEBSERVER}" \
      --detach \
      --env-file "${ENVIROPATH}" \
      -v "${COMPOSERCACHE}:/var/www/.composer:rw" \
      -v "${SHAREDDIR}":/shared \
      "${DOCKER_PHP}"

    # Ensure that the whole .composer directory is writable to all (www-data needs to write there).
    docker exec "${WEBSERVER}" chmod -R go+rw /var/www/.composer

    echo
    echo "Webserver logs:"
    docker logs "${WEBSERVER}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}
