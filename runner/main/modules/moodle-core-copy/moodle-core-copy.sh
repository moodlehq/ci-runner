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

# Moodle core (copy) module functions.

# This module defines the following env variables.
function moodle-core-copy_env() {
    env=(
        MOODLE_BRANCH
    )
    echo "${env[@]}"
}

# Moodle core copy module checks.
function moodle-core-copy_check() {
    # Check all module dependencies.
    verify_modules docker plugins docker-php

    # These env variables must be set for the module to work.
    verify_env BASEDIR CODEDIR PLUGINSDIR WEBSERVER FULLGIT LOCAL_CI_PATH
}

# Moodle core copy module config.
function moodle-core-copy_config() {
    # Get the Moodle branch from code, so we can make decisions based on it.
    MOODLE_BRANCH=$(grep "\$branch" "${CODEDIR}"/version.php | sed "s/';.*//" | sed "s/^\$.*'//")
}

# Moodle core copy module setup.
function moodle-core-copy_setup() {

    echo ">>> startsection Copying source files <<<"
    echo "============================================================================"

    # TODO: Maybe make this a separate module, so it can be reused in other places.
    # If we are going to need a working git clone, with access to the full history and
    # without any dependency withing the container (git reference repo), this is the
    # time to achieve it (before copying the code to the container).
    # If it's a git repository, that has a reference repository, and we need the full
    # history within the container, let's remove the dependency.
    if [[ -n "$FULLGIT" ]] && [[ -d "${CODEDIR}/.git" ]] && [[ -r "${CODEDIR}/.git/objects/info/alternates" ]]; then
        echo "== Removing the repository dependencies (reference repo)"
        git -C "${CODEDIR}" repack -a && rm -f "${CODEDIR}/.git/objects/info/alternates"
    fi

    # Copy the code to the web server (and change owner)
    echo "== Copying code in place."
    docker cp "${CODEDIR}"/. "${WEBSERVER}":/var/www/html
    docker exec "${WEBSERVER}" chown -R www-data:www-data /var/www/html

    # TODO: Maybe make this a separate module, so it can be reused in other places.
    # Once copied, if we are going to need access to the full history, we'll need to
    # update refs (in case the repo was cloned with --branch or --single-branch) and
    # un-shallow if needed to. Only if it's a git repository.
    if [[ -n "$FULLGIT" ]] && [[ -d "${CODEDIR}/.git" ]]; then
        # Before anything else, we only support https public repos, not ssh+git ones, coz we would need
        # to play with ssh keys / known hosts or disable strict host checking, and that's not good.
        if (! docker exec -u www-data "${WEBSERVER}" git config --get remote.origin.url | grep -q '^https'); then
            exit_error "Only https public repositories are supported for this job, not ssh+git ones."
        fi

        # If the repository was cloned shallow (--depth), un-shallow it.
        if (docker exec -u www-data "${WEBSERVER}" git rev-parse --is-shallow-repository | grep -q 'true'); then
            echo "== Unshallowing the repository."
            docker exec -u www-data "${WEBSERVER}" git fetch --unshallow
        fi
        # Detect if the repo was cloned single-branch, update refs to get the full history.
        remotefetchall="+refs/heads/*:refs/remotes/origin/*"
        remote=$(docker exec -u www-data "${WEBSERVER}" git config --get-all remote.origin.fetch)
        if [[ "${remote}" != "${remotefetchall}" ]]; then
            echo "== Updating refs to get the full history."
            docker exec -u www-data "${WEBSERVER}" git config remote.origin.fetch "${remotefetchall}"
            docker exec -u www-data "${WEBSERVER}" git fetch origin
        fi
    fi

    # Copy the config.php in place
    echo "== Copying configuration in place."
    docker cp "${BASEDIR}/modules/docker-php/config.template.php" "${WEBSERVER}":/var/www/html/config.php
    docker exec "${WEBSERVER}" chown -R www-data:www-data /var/www/html/config.php

    # Copy the plugins in place.
    if [[ -n "$PLUGINSTOINSTALL" ]]; then
        echo "== Copying external plugins in place."
        docker cp "${PLUGINSDIR}"/. "${WEBSERVER}":/var/www/html
        docker exec "${WEBSERVER}" chown -R www-data:www-data /var/www/html
    fi

    # Copy composer-phar if available in caches.
    if [[ -f "${COMPOSERCACHE}/composer.phar" ]]; then
        echo "== Copying composer.phar in place."
        docker cp "${COMPOSERCACHE}/composer.phar" "${WEBSERVER}":/var/www/html/composer.phar
        docker exec "${WEBSERVER}" chown -R www-data:www-data /var/www/html/composer.phar
    fi

    # Copy local_ci if available to /tmp/local_ci, we'll execute all the scripts from there.
    # (perform some basic validation, we don't want to copy the wrong stuff)
    if [[ -n "${LOCAL_CI_PATH}" ]] && [[ ! -d "${LOCAL_CI_PATH}/tracker_automations" ]]; then
        exit_error "LOCAL_CI_PATH doesn't point to a valid moodle-local_ci checkout"
    fi

    if [[ -n "${LOCAL_CI_PATH}" ]]; then
        echo "== Copying local_ci in place."
        docker cp "${LOCAL_CI_PATH}" "${WEBSERVER}":/tmp/local_ci
        docker exec "${WEBSERVER}" chown -R www-data:www-data /tmp/local_ci
    fi

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
