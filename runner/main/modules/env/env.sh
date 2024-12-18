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

# Environment module functions.

# This module defines the following env variables.
function env_env() {
    env=(
        ENVIROPATH
    )
    echo "${env[@]}"
}

# Environment module checks.
function env_check() {
    # These env variables must be set for the module to work.
    verify_env JOBTYPE SHAREDDIR BUILD_ID
}

# Environment module config.
function env_config() {
    # Apply some defaults.
    ENVIROPATH="${SHAREDDIR}"/moodle-ci-runner.env
}

# Environment module setup, Create the environment file to be used by other modules.
# (this is executed after all the modules and the job have been able to set their env variables).
function env_setup() {
    # Reset the environment file.
    rm -f "${ENVIROPATH}"
    touch "${ENVIROPATH}"

    # Always add the BUILD_ID, in case it's needed by any of the scripts out from the runner.
    echo "BUILD_ID=${BUILD_ID}" >> "${ENVIROPATH}"

    # TODO: Remove this once https://github.com/moodlehq/moodle-local_ci/issues/303 is fixed.
    # Always make BUILD_NUMBER available, some old scripts use it.
    echo "BUILD_NUMBER=${BUILD_NUMBER}" >> "${ENVIROPATH}"

    # Always add the job type.
    echo "JOBTYPE=${JOBTYPE}" >> "${ENVIROPATH}"

    # Add all the variables that the job type requires.
    for var in $(get_job_to_env_file "${JOBTYPE}"); do
        # Docker does not support multiline env variables via --env-file, so we need to
        # remove the newlines from the value. See unresolved: https://github.com/moby/moby/issues/12997
        value="${!var//$'\n'/}"
        echo "${var}=${value}" >> "${ENVIROPATH}"
    done
}

# Environment module teardown. Remove the environment file.
function env_teardown() {
    rm -f "${ENVIROPATH}"
}
