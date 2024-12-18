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

# Performance job type functions.

# Performance needed variables to go to the env file.
function performance_to_env_file() {
    local env=(
        DBTYPE
        DBTAG
        DBHOST
        DBNAME
        DBUSER
        DBPASS
        DBCOLLATION
        DBREPLICAS
        DBHOST_DBREPLICA
        WEBSERVER
        MOODLE_WWWROOT
    )
    echo "${env[@]}"
}

# Performance information to be added to the summary.
function performance_to_summary() {
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== PHP version: ${PHP_VERSION}"
    echo "== DBTYPE: ${DBTYPE}"
    echo "== DBTAG: ${DBTAG}"
    echo "== DBREPLICAS: ${DBREPLICAS}"
    echo "== MOODLE_CONFIG: ${MOODLE_CONFIG}"
    echo "== PLUGINSTOINSTALL: ${PLUGINSTOINSTALL}"
    echo "== SITESIZE: ${SITESIZE}"
}

# This job type defines the following env variables
function performance_env() {
    env=(
        RUNCOUNT
        EXITCODE
    )
    echo "${env[@]}"
}

# Performance needed modules. Note that the order is important.
function performance_modules() {
    local modules=(
        env
        summary
        docker
        docker-logs
        git
        browser
        plugins
        docker-database
        docker-php
        moodle-config
        moodle-core-copy
        docker-healthy
        docker-summary
        docker-jmeter
    )
    echo "${modules[@]}"
}

# Performance job type checks.
function performance_check() {
    # Check all module dependencies.
    verify_modules $(performance_modules)

    # These env variables must be set for the job to work.
    verify_env UUID WORKSPACE SHAREDDIR ENVIROPATH WEBSERVER GOOD_COMMIT BAD_COMMIT
}

# Performance job type init.
function performance_config() {
    EXITCODE=0

    export MOODLE_WWWROOT="http://${WEBSERVER}"
    export SITESIZE="${SITESIZE:-XS}"
    export COURSENAME="performance_course"
}

# Performance job type setup.
function performance_setup() {
    # If both GOOD_COMMIT and BAD_COMMIT are not set, we are going to run a normal session.
    # (for bisect sessions we don't have to setup the environment).
    if [[ -z "${GOOD_COMMIT}" ]] && [[ -z "${BAD_COMMIT}" ]]; then
        performance_setup_normal
    fi
}

# Performance job type setup for normal mode.
function performance_setup_normal() {
    # Init the Performance site.
    echo
    echo ">>> startsection Initialising Performance environment at $(date)<<<"
    echo "============================================================================"
    local initcmd
    performance_initcmd initcmd # By nameref.
    echo "Running: ${initcmd[*]}"
    docker exec -t -u www-data "${WEBSERVER}" "${initcmd[@]}"

    echo "Creating test data"
    performance_generate_test_data

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Returns (by nameref) an array with the command needed to init the Performance site.
function performance_initcmd() {
    local -n cmd=$1
    # We need to determine the init suite to use.
    local initsuite=""


    # Build the complete init command.
    cmd=(
        php admin/cli/install_database.php \
            --agree-license \
            --fullname="Moodle Performance Test"\
            --shortname="moodle" \
            --adminuser=admin \
            --adminpass=adminpass
    )
}

function performance_generate_test_data() {
    local phpcmd="php"

    # Generate Test Site.
    local testsitecmd
    perfomance_testsite_generator_command testsitecmd # By nameref.
    echo "Running: ${testsitecmd[*]}"
    docker exec -t -u www-data "${WEBSERVER}" "${testsitecmd[@]}"

    # Generate the test plan files and capture the output
    local testplancmd
    perfomance_testplan_generator_command testplancmd # By nameref.
    echo "Running: ${testplancmd[*]}"
    testplanfiles=$(docker exec -t -u www-data "${WEBSERVER}" "${testplancmd[@]}")

    # Display the captured output
    echo "Captured Output:"
    echo "${testplanfiles}"

    # Extract URLs and download files to ${SHAREDDIR}
    urls=$(echo "${testplanfiles}" | grep -oP 'http://[^ ]+')
    for url in ${urls}; do
        # Extract the filename from the URL
        filename=$(basename "${url}")
        echo "Downloading: ${url} to /shared/${filename}"
        docker exec -it -u www-data "${WEBSERVER}" curl -o "/shared/${filename}" "${url}"
    done
}

#function performance_datacmd() {
#
#}

# Performance job type run.
function performance_run() {
    echo
    if [[ RUNCOUNT -gt 1 ]]; then
        echo ">>> startsection Starting ${RUNCOUNT} Performance main runs at $(date) <<<"
    else
        echo ">>> startsection Starting Performance main run at $(date) <<<"
    fi
    echo "============================================================================"

    # Calculate the command to run. The function will return the command in the passed array.
    local cmd=
    performance_main_command cmd # By nameref.

    echo "Running: ${cmd[*]}"
    echo ">>> Performance run at $(date) <<<"
    docker exec -t "${JMETER}" "${cmd[@]}"
    EXITCODE=$?

    echo "============================================================================"
    echo "== Date: $(date)"
    echo "== Exit code: ${EXITCODE}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Performance job type teardown.
function performance_teardown() {
    # Need to copy the results from the jmeter test into the shared directory.
    # cp "${SHAREDDIR}"/timing.json "${timingpath}"
    echo "TODO: Copy results to results directory for persistence into S3"
}

# Calculate the command to run for Performance main execution,
# returning it in the passed array parameter.
# Parameters:
#   $1: The array to store the command.
function performance_main_command() {
    local -n _cmd=$1 # Return by nameref.

    # TODO: Get all of these values from somewhere?
    # Build the complete perf command for the run.
    _cmd=(
        jmeter \
            -n \
            -j "/shared/logs/jmeter.log" \
            -t "$testplanfile" \
            -Jusersfile="$testusersfile" \
            -Jgroup="$group" \
            -Jdesc="$description" \
            -Jsiteversion="$siteversion" \
            -Jsitebranch="$sitebranch" \
            -Jsitecommit="$sitecommit" \
            $samplerinitstr \
            $includelogsstr \
            $users \
            $loops \
            $rampup \
            $throughput \
            > $runoutput || \
            throw_error $jmetererrormsg
    )
}

function perfomance_testsite_generator_command() {
    local -n _cmd=$1 # Return by nameref.

    # Build the complete perf command for the run.
    _cmd=(
        php admin/tool/generator/cli/maketestsite.php \
            --size="${SITESIZE}" \
            --fixeddataset \
            --bypasscheck \
            --filesizelimit="1000"
    )
}

function performance_testplan_generator_command() {
    local -n _cmd=$1 # Return by nameref.

    # Build the complete perf command for the run.
    _cmd=(
        php admin/tool/generator/cli/maketestplan.php \
            --size="${SITESIZE}" \
            --shortname="${COURSENAME}" \
            --bypasscheck
    )
}
