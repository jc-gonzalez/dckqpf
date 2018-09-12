#!/bin/bash
#==============================================================================
# FILE:           DockerQPF-create.sh
# DESCRIPTION:    Create set of Docker images to dockerized QPF
# AUTHOR:         J. C. Gonzalez <JCGonzalez@sciops.esa.int>
# VERSION:        2.1
# DATE:           2018/09/07
# COMMENTS:
#   A set of containers from different images are launched to run a dockerized
#   QPF.
#   List of elements needed:
#     - Volumes:
#       + PSQL QPF DB (1)
#       + QPF Data Volume (1)
#     - QPF Master (1 in this host)
#     - QPF Processing Cores (n hosts x 1 per host)
# USAGE:
#   ./DockerQPF-create.sh
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

#- Options
LIST_OF_ITEMS=""

CREATE_PSQL="no"
CREATE_COTS="no"
CREATE_CORE="no"
CREATE_OPTS=""

BUILD="no"
DOWNLOAD="no"
UPLOAD="no"

src=0
tgt=1

# NEXUS Docker Repository URL
NEXUS_DOCKER_URL="scidockreg.esac.esa.int:60400"
NEXUS_USER="eucops"

#- Other
DATE=$(date +"%Y%m%d%H%M%S")
VERSION=2.1
PGSQL_VERSION=10

LOG_FILE="dockerqpf-create-${DATE}.log"

#=== Handy functions

greetings () {
    say "${_ONHDR}==============================================================================="
    say "${_ONHDR} Euclid DockerQPF -- Create Images"
    say "${_ONHDR} Version ${VERSION}"
    say "${_ONHDR} Execution time-stamp: ${DATE}"
    say "${_ONHDR}==============================================================================="
    say ""
}

usage () {
    local opts="[ -h ] [ -b | -d ] [ -p ] [ -C ] [ -c ] [ -u ] [ -o \"opts\" ]"
    say "Usage: ${SCRIPT_NAME} $opts"
    say "where:"
    say "  -h         Show this usage message"
    say "  -b         Build the specified images"
    say "  -d         Download from Nexus repository, instead of build"
    say "  -p         PostgreSQL image"
    say "  -C         COTS base image for QPF"
    say "  -c         QPF Core image"
    say "  -u         Upload to Nexus repository, after creation"
    say "  -o \"opts\"  Specify options"
    say ""
    exit 1
}

say () {
    echo -e "$*${_OFF}"
    echo -e "$*" | sed -e 's#.\[[0-9];[0-9][0-9];[0-9][0-9]m##g' >> \
                       "${LOG_FILE}"
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
while getopts :hpCcbduo: OPT; do
    case $OPT in
        h|+h) usage
              ;;
        p|+p) CREATE_PSQL="yes"
              LIST_OF_ITEMS="psql ${LIST_OF_ITEMS}"
              ;;
        C|+C) CREATE_COTS="yes"
              LIST_OF_ITEMS="${LIST_OF_ITEMS} cots"
              ;;
        c|+c) CREATE_CORE="yes"
              LIST_OF_ITEMS="${LIST_OF_ITEMS} core"
              ;;
        o|+o) CREATE_OPTS="$OPTARG"
              ;;
        b|+b) BUILD="yes"
              ;;
        d|+d) DOWNLOAD="yes"
              ;;
        u|+u) UPLOAD="yes"
              ;;
        *)    usage
              exit 2
              ;;
    esac
done
shift `expr $OPTIND - 1`
OPTIND=1

#- Say hello
greetings

#=== START EXECUTION ================================================

declare -A IMG_IDS=([psql]=postgres:${PGSQL_VERSION} \
                          [cots]=qpf-cots:${VERSION} \
                          [core]=qpf-core:${VERSION})
declare -A IMG_DESC=([psql]="PostgreSQL image" \
                           [cots]="QPF COTS" \
                           [core]="QPF Core")
declare -A IMG_DCK=([psql]=Dockerfile-postgres-${PGSQL_VERSION} \
                          [cots]=Dockerfile-qpfcots \
                          [core]=Dockerfile-qpfcots)

for item in ${LIST_OF_ITEMS}; do

    IMG=${IMG_IDS[$item]}
    IMGTAG=$(echo $IMG | cut -d: -f1):latest

    IMGDESC=${IMG_DESC[$item]}
    DCKFILE=${IMG_DCK[$item]}

    if [ "${DOWNLOAD}" == "yes" ]; then
        step "Pulling image with ${IMGDESC} image ${IMG} from NEXUS repository"
        docker pull ${NEXUS_DOCKER_URL}/${NEXUS_USER}/${IMG}
        docker tag  ${NEXUS_DOCKER_URL}/${NEXUS_USER}/${IMG} ${IMG}
        docker tag  ${NEXUS_DOCKER_URL}/${NEXUS_USER}/${IMG} ${IMGTAG}
        docker tag  ${IMG} ${IMGTAG}
    else
        if [ "${BUILD}" == "yes " ]; then
            step "Creating ${IMGDESC} image ${IMG}"
            make -f Makefile.img \
                 DOCKERFILE=${DCKFILE} IMAGE_NAME=${IMG} OPTS="${CREATE_OPTS}"
        fi
    fi

    if [ "${UPLOAD}" == "yes" ]; then
        step "Pushing image with ${IMGDESC} image ${IMG} to NEXUS repository"
        docker tag  ${IMG} ${NEXUS_DOCKER_URL}/${NEXUS_USER}/${IMG}
        docker push ${NEXUS_DOCKER_URL}/${NEXUS_USER}/${IMG}
    fi

done

say "Done."
