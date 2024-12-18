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

# Jmeter module functions.

# This module defines the following env variables.
function docker-jmeter_env() {
    env=(
        JMETERTESTURL
    )
    echo "${env[@]}"
}

# JMETER module checks.
function docker-jmeter_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID
}

# JMETER module config.
function docker-jmeter_config() {
    JMETER=jmeter"${UUID}"
    JMETERTESTURL="jmeter://${JMETER}"
}

# JMETER module setup, launch the containers.
function docker-jmeter_setup() {
    echo
    echo ">>> startsection Starting Jmeter server <<<"
    echo "============================================================================"

    # Start the jmeter server
    docker pull alpine/jmeter:latest

    cp -rf "${BASEDIR}"/modules/docker-jmeter/libraries/* "${SHAREDDIR}"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

function docker-jmeter_run_args() {
    local -n _cmd=$1 # Return by nameref.
    # Start the jmeter server
    _cmd=(
            --name "${JMETER}" \
            --network "${NETWORK}" \
            -u `id -u` \
    	    -v "${SHAREDDIR}:/shared" \
	        -w /shared \
            alpine/jmeter:latest
    )
}
