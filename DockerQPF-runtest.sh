#!/bin/bash
#==============================================================================
# FILE:           DockerQPF-runtest.sh
# DESCRIPTION:    Runtest set of Docker containers to run dockerized QPF
# AUTHOR:         J. C. Gonzalez <JCGonzalez@sciops.esa.int>
# VERSION:        2.1
# DATE:           2018/09/07
# COMMENTS:
#   A set of containers from different images are runtested to run a dockerized
#   QPF.
#   List of elements needed:
#     - Volumes:
#       + PSQL QPF DB (1)
#       + QPF Data Volume (1)
#     - QPF Master (1 in this host)
#     - QPF Processing Cores (n hosts x 1 per host)
# USAGE:
#   ./DockerQPF-runtest.sh
#
# Copyright (C) 2015-2018 J C Gonzalez
#==============================================================================

#=== ENVIRONMENT AND DATA PREPARATION ===============================

#- Saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

#- This script path and name
SCRIPT_PATH="${BASH_SOURCE[0]}";
SCRIPT_NAME=$(basename "${SCRIPT_PATH}")
if [ -h "${SCRIPT_PATH}" ]; then
    while [ -h "${SCRIPT_PATH}" ]; do
        SCRIPT_PATH=$(readlink "${SCRIPT_PATH}")
    done
fi
pushd . > /dev/null
cd $(dirname ${SCRIPT_PATH}) > /dev/null
SCRIPT_PATH=$(pwd)
popd  > /dev/null

#- Messages
_ONHDR="\e[1;49;93m"
_ONMSG="\e[1;49;92m"
_ONRUN="\e[0;49;32m"
_ONERR="\e[1;49;91m"
_OFF="\e[0m"
STEP=0

TEST_DATA_FOLDER=/localdata/QLA_data/Test_Data
QDT_FOLDER=${TEST_DATA_FOLDER}/QDT

#- Other
DATE=$(date +"%Y%m%d%H%M%S")
VERSION=2.1

LOG_FILE="dockerqpf-runtest-${DATE}.log"

#=== Handy functions

greetings () {
    say "${_ONHDR}==============================================================================="
    say "${_ONHDR} Euclid DockerQPF -- Run test"
    say "${_ONHDR} Version ${VERSION}"
    say "${_ONHDR} Execution time-stamp: ${DATE}"
    say "${_ONHDR}==============================================================================="
    say ""
}

usage () {
    local opts="[ -h ] [ -d <data> ] [ -q <qdt> ]"
    say "Usage: ${SCRIPT_NAME} $opts"
    say "where:"
    say "  -h         Show this usage message"
    say "  -d <data>  Set data folder"
    say "  -q <qdt>   Set QDT folder"
    say ""
    exit 1
}

say () {
    echo -e "$*${_OFF}"
    echo -e "$*" | sed -e 's#.\[[0-9];[0-9][0-9];[0-9][0-9]m##g' >> "${LOG_FILE}"
}

step () {
    say "${_ONMSG}## STEP ${STEP} - $*"
    STEP=$(($STEP + 1))
}

die () {
    say "${_ONERR}ERROR: $*"
    exit 1
}

#=== PARSE COMMAND LINE OPTIONS =====================================

#- Parse command line and display grettings
while getopts :hd:q: OPT; do
    case $OPT in
        h|+h) usage
              ;;
        d|+d) TEST_DATA_FOLDER="$OPTARG"
              ;;
        q|+q) QDT_FOLDER="$OPTARG"
              ;;
        *)    usage
              exit 2
              ;;
    esac
done
shift `expr $OPTIND - 1`
OPTIND=1

DATA_FILES=$*

#- Say hello
greetings

#=== START EXECUTION ================================================

#=== Download images

step "Retrieving Docker images from NEXUS"
bash ./DockerQPF-create.sh -d -p -c

#=== Launch containers

step "Launch containers"
bash ./DockerQPF-launch.sh -K -z -b -p \
     -d ${TEST_DATA_FOLDER} -q ${QDT_FOLDER}

#=== Feed data into container

step "Feed data files into QPF core"
say  "  . Files to be used as input data files:"
for f in ${DATA_FILES}; do
    say  "    - $f"
done

INBOX_FLD=${TEST_DATA_FOLDER}/qpfwa/data/inbox
sleep 10

k=0

for f in ${DATA_FILES}; do

    k=$((k + 1))
    obsid=$(printf "%05d" $k)

    d=$(dirname $f)
    b=$(basename $f)
    datafile=${INBOX_FLD}/${b:0:12}${obsid}${b:17}

    say  "  . Feeding data file ${datafile} . . ."
    ln ${f} ${datafile}
    
    sleep 30

done


