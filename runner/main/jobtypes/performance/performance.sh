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
        SITESIZE
        TARGET_FILE
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
    echo "== TARGET_FILE: ${TARGET_FILE}"
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
    export SITESIZE="${SITESIZE:-S}"
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

    # Copy the site normalisation script and execute it.
    echo "Copying and executing the site normalisation script"
    docker cp "${BASEDIR}/jobtypes/performance/normalise_site.php" "${WEBSERVER}:/var/www/html/normalise_site.php"
    docker exec -t -u www-data "${WEBSERVER}" php /var/www/html/normalise_site.php

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
    performance_testplan_generator_command testplancmd # By nameref.
    echo "Running: docker exec -t -u www-data "${WEBSERVER}" "${testplancmd[@]}""
    testplanfiles=$(docker exec -t -u www-data "${WEBSERVER}" "${testplancmd[@]}")

    # Display the captured output
    echo "Captured Output:"
    echo "${testplanfiles}"
    echo "${SHAREDDIR}"

    # Ensure the directory exists and is writable
    mkdir -p "${SHAREDDIR}/planfiles"
    mkdir -p "${SHAREDDIR}/output/logs"
    mkdir -p "${SHAREDDIR}/output/runs"

    chmod -R 2777 "${SHAREDDIR}"

    # Extract URLs and download files to ${SHAREDDIR}
    urls=$(echo "${testplanfiles}" | grep -oP 'http://[^ ]+')
    for url in ${urls}; do
        # Trim any whitespace or newline characters from the URL
        url=$(echo "${url}" | tr -d '\r\n')
        # Extract the filename from the URL
        filename=$(basename "${url}")
        echo "Downloading: ${url} to ${SHAREDDIR}/${filename}"
        docker exec -t -u www-data "${WEBSERVER}" curl -o "/shared/planfiles/${filename}" "${url}"
    done
}

# Performance job type run.
function performance_run() {
    echo
    if [[ RUNCOUNT -gt 1 ]]; then
        echo ">>> startsection Starting ${RUNCOUNT} Performance main runs at $(date) <<<"
    else
        echo ">>> startsection Starting Performance main run at $(date) <<<"
    fi
    echo "============================================================================"

    datestring=`date '+%Y%m%d%H%M'`
    # Get the plan file name.
    testplanfile=`ls "${SHAREDDIR}"/planfiles/*.jmx | head -1 | sed "s@${SHAREDDIR}@/shared@"`
    testusersfile=`ls "${SHAREDDIR}"/planfiles/*.csv | head -1 | sed "s@${SHAREDDIR}@/shared@"`
    group="${MOODLE_BRANCH}"
    description="${GIT_COMMIT}"
    siteversion=""
    sitebranch="${MOODLE_BRANCH}"
    sitecommit="${GIT_COMMIT}"
    runoutput="${SHAREDDIR}/output/logs/run.log"

    # Calculate the command to run. The function will return the command in the passed array.
    local jmeterruncmd=
    performance_main_command jmeterruncmd # By nameref.

    echo "Running: ${jmeterruncmd[*]}"
    echo ">>> Performance run at $(date) <<<"
    local dockerrunargs=
    docker-jmeter_run_args dockerrunargs # By nameref

    echo "${dockerrunargs[@]}"
    echo docker run ${dockerrunargs[@]} ${jmeterruncmd[@]}
    docker run "${dockerrunargs[@]}" ${jmeterruncmd[@]} | tee "${runoutput}"
    EXITCODE=$?

    # Grep the logs looking for errors and warnings.
    for errorkey in ERROR WARN; do
      # Also checking that the errorkey is the log entry type.
      if grep $errorkey "${SHAREDDIR}/output/logs/jmeter.log" | awk '{print $3}' | grep -q $errorkey ; then
        echo "Error: \"$errorkey\" found in jmeter logs, read log file to see the full trace."
        # EXITCODE=1
      fi
    done

    echo "============================================================================"
    echo "== Date: $(date)"
    echo "== Exit code: ${EXITCODE}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Performance job type teardown.
function performance_teardown() {
    DATADIR="${SHAREDDIR}/output/runs"
    cp "${BASEDIR}/jobtypes/performance/format_rundata.php" "${DATADIR}/format_rundata.php"
    docker run \
        -v "${DATADIR}:/shared" \
        -w /shared \
        php:8.3-cli \
        php /shared/format_rundata.php rundata.php

    echo "Storing data with a git commit of '${GIT_COMMIT}'"

    # We use the storage directory to store data for long term comparison.
    TARGETDIR=`dirname "${TARGET_FILE}"`
    mkdir -p "${WORKSPACE}/${TARGETDIR}"
    cp -rf "${DATADIR}/rundata.json" "${TARGET_FILE}"
}

# Calculate the command to run for Performance main execution,
# returning it in the passed array parameter.
# Parameters:
#   $1: The array to store the command.
function performance_main_command() {
    local -n _cmd=$1 # Return by nameref.

    # Include logs string.
    includelogs=1
    includelogsstr="-Jincludelogs=$includelogs"
    samplerinitstr="-Jbeanshell.listener.init=recorderfunctions.bsf"


    # TODO: Get all of these values from somewhere?
    # In particular where to get users, loops, rampup, and throughput from?
    # Build the complete perf command for the run.
        _cmd=(
            -n \
            -j "/shared/output/logs/jmeter.log" \
            -t "$testplanfile" \
            -Jusersfile="$testusersfile" \
            -Jgroup="$group" \
            -Jdesc="$description" \
            -Jsiteversion="$siteversion" \
            -Jsitebranch="$sitebranch" \
            -Jsitecommit="$sitecommit" \
            -Jusers=5 -Jloops=1 -Jrampup=1 -Jthroughput=120 \
            $samplerinitstr $includelogsstr
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

    case "${SITESIZE}" in
    'XS')
        targetcourse='testcourse_3'
        ;;
     'S')
        targetcourse='testcourse_12'
        ;;
     'M')
        targetcourse='testcourse_73'
        ;;
     'L')
        targetcourse='testcourse_277'
        ;;
    'XL')
        targetcourse='testcourse_1065'
        ;;
   'XXL')
        targetcourse='testcourse_4177'
        ;;
       *)
	;;
    esac

    # Build the complete perf command for the run.
    _cmd=(
        php admin/tool/generator/cli/maketestplan.php \
            --size="${SITESIZE}" \
            --shortname="${targetcourse}" \
            --bypasscheck
    )
}
