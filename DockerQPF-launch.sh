#!/bin/bash
#==============================================================================
# VERSION:        2.1
# DESCRIPTION:    Launch set of Docker containers to run dockerized QPF
# AUTHOR:         J. C. Gonzalez <JCGonzalez@sciops.esa.int>
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
#   ./DockerQPF-launch.sh
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
LAUNCH_PSQL_SERVER="no"
INIT_QPFDB="no"
DCK_CLEAR_DB="no"
DCK_CLEAR_CONT="no"
DCK_KILL="no"

src=0
tgt=1

#- Other
DATE=$(date +"%Y%m%d%H%M%S")
VERSION=2.1

LOG_FILE="dockerqpf-launch-${DATE}.log"

#=== Handy functions

greetings () {
    say "${_ONHDR}==============================================================================="
    say "${_ONHDR} Euclid DockerQPF"
    say "${_ONHDR} Version ${VERSION}"
    say "${_ONHDR} Execution time-stamp: ${DATE}"
    say "${_ONHDR}==============================================================================="
    say ""
}

usage () {
    local opts="[ -h ] [ -P ] [ -b ] [ -C ] [ -K ] [ -z ]"
    say "Usage: ${SCRIPT_NAME} $opts"
    say "where:"
    say "  -h         Show this usage message"
    say "  -P         Start PostgreSQL Server Container"
    say "  -b         Initialize QPF DB"
    say "  -C         Clear DB"
    say "  -K         Kill running PostgreSQL & QPF Master Core Containers"
    say "  -z         Remove old Docker Containers"
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
while getopts :hPbCKz OPT; do
    case $OPT in
        h|+h) usage
              ;;
        P|+P) LAUNCH_PSQL_SERVER="yes"
              ;;
        b|+b) INIT_QPFDB="yes"
              ;;
        C|+C) DCK_CLEAR_DB="yes"
              ;;
        K|+K) DCK_KILL="yes"
              ;;
        z|+z) DCK_CLEAR_CONT="yes"
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

#=== Variables

EUCUSER=eucops
EUCPWD=eu314clid
QPFDB=qpfdb

PSQL_SERVER_IMG=postgres:10
QPF_CORE_IMG=qpf-core:2.1

#- Volumes, created and then mounted with --mount
#VOL_MNT_QPFDB=(qpfdb /qpfdb)
VOL_MNT_QPFDATA=(qpfdata /home/${EUCUSER}/qpf/data)

#- Binded folders
BIND_QPFDB=(/home/${EUCUSER}/qpf/db /var/lib/postgresql/data)
BIND_QPFCFG=($(pwd)/cfg /home/${EUCUSER}/qpf/cfg)
BIND_QPFDATA=(/data/Test_Data/qpfwa/data /home/${EUCUSER}/qpf/data)
BIND_QPFRUN=(/data/Test_Data/qpfwa/run /home/${EUCUSER}/qpf/run)
BIND_QDT=(/data/Test_Data/QDT-test /home/${EUCUSER}/qpf/bin/QDT)
BIND_BIN=($(pwd)/bin /home/${EUCUSER}/bin)

#- Docker Container Names
QPF_PGSQL=qpf-postgres
QPF_PGSQL_ALIAS=qpfpsql
QPF_CORE=qpf-core

#=== Create volumes
#docker volume create --name=${VOL_QPFDB[$src]}
#docker volume create --name=${VOL_QPFDATA[$src]}

#=== Create bind mount folder in case they do not exist
step "- Creating bind mount folders"
mkdir -p ${BIND_QPFDB[$src]}

#=== Kill running containers
if [ ${DCK_KILL} == "yes" ]; then
    step "- Killing and removing running containers"
    for cnt in ${QPF_CORE} ${QPF_PGSQL} ; do
        docker inspect --format '{{.Id}}' $cnt 2>/dev/null && \
            (echo "  - Killing container $cnt . . ." ; \
             docker stop $cnt ; \
             docker rm $cnt )
    done
fi

#=== Clear Docker Containers if requested
if [ ${DCK_CLEAR_CONT} == "yes" ]; then
    step "- Removing old containers"
    cnts=$(docker ps -a|awk '/Exited/{print $1;}')
    if [ -n "$cnts" ]; then
        docker rm $cnts
    fi
fi

#=== Run PostgreSQL container
if [ "${LAUNCH_PSQL_SERVER}" == "yes" ]; then
    step "- Launching PostgreSQL Server"
    docker run -d --name ${QPF_PGSQL} ${PSQL_SERVER_IMG}
    docker ps -a
    sleep 3
fi

IP_PSQL=$(docker inspect --format '{{.NetworkSettings.IPAddress}}' ${QPF_PGSQL})
[ -f cfg/qpfpsql.ip ] && rm -f cfg/qpfpsql.ip
echo ${IP_PSQL} > cfg/qpfpsql.ip

#=== Initialize DB if required
if [ "${INIT_QPFDB}" == "yes" ]; then
    step "- Creating Euclid Ops. User"
    cat <<EOF_PSQL | \
        docker run -i \
               --rm \
               --link ${QPF_PGSQL}:${QPF_PGSQL_ALIAS} \
               ${PSQL_SERVER_IMG} \
               psql -h ${QPF_PGSQL_ALIAS} -U postgres
CREATE USER ${EUCUSER} WITH SUPERUSER PASSWORD '${EUCPWD}';
DROP DATABASE ${QPFDB};
CREATE DATABASE ${QPFDB} OWNER ${EUCUSER};
EOF_PSQL

    step "- Initializing QPF DB"
    cat qpfdb.sql | \
        docker run -i \
               --rm \
               --link ${QPF_PGSQL}:${QPF_PGSQL_ALIAS} \
               ${PSQL_SERVER_IMG} \
               psql -h ${QPF_PGSQL_ALIAS} -d ${QPFDB} -U ${EUCUSER}
    sleep 1
fi

#=== Clear DB if requested
if [ "${DCK_CLEAR_DB}" == "yes" ]; then
    step "- Clear QPF database"

    step "  - Cleaning up database . . ."
    if [ -f /tmp/clean-up-qpfdb.sql ]; then
        rm -f /tmp/clean-up-qpfdb.sql
    fi
cat <<EOF>/tmp/clean-up-qpfdb.sql
delete from products_info where id>0;
delete from transmissions where id>0;
delete from tasks_info where id>0;
delete from icommands;
delete from alerts;
delete from qpfstates;
delete from task_status_spectra;
EOF
    psql -h ${IP_PSQL} -d ${QPFDB} -U ${EUCUSER} -f /tmp/clean-up-qpfdb.sql

    step "  - Cleaning up data folders . . ."
    pths=""
    pths="$pths archive"
    pths="$pths gateway"
    pths="$pths gateway/in"
    pths="$pths gateway/out"
    pths="$pths inbox"

    size=0
    for p in $pths ; do
        sz=$(du -ks ${BIND_QPFDATA[$src]}/${p} | cut -f 1)
        rm -rf ${BIND_QPFDATA[$src]}/${p}/EUC*
        size=$(($size + $sz))
    done

    step "  - Removing old sessions . . ."
    sess=$(ls -d ${BIND_QPFRUN[$src]}/20* 2>/dev/null)
    for p in $sess ; do
        sz=$(du -ks ${p} | cut -f 1)
        rm -rf ${p}
        size=$(($size + $sz))
    done

    step "  => $size kB recovered."
fi

#=== Start QPF Core
step "- Starting QPF Core"
cmd="docker run -d \
       --name ${QPF_CORE} \
       --link ${QPF_PGSQL}:${QPF_PGSQL_ALIAS} \
       --privileged=true \
       -e USER_NAME=eucops \
       -e DCKQPF=yes \
       -e DCKRUNSRC=${BIND_QPFRUN[$src]} \
       -e DCKRUNTGT=${BIND_QPFRUN[$tgt]} \
       -v /var/run/docker.sock:/var/run/docker.sock \
       -v ${BIND_QPFCFG[$src]}:${BIND_QPFCFG[$tgt]} \
       -v ${BIND_QPFDATA[$src]}:${BIND_QPFDATA[$tgt]} \
       -v ${BIND_QPFRUN[$src]}:${BIND_QPFRUN[$tgt]} \
       -v ${BIND_QDT[$src]}:${BIND_QDT[$tgt]} \
       -v ${BIND_BIN[$src]}:${BIND_BIN[$tgt]} \
       ${QPF_CORE_IMG} \
       /bin/bash bin/start.sh"
echo $cmd
$cmd
qpfid=$(docker ps -ql)
#sleep 5

#=== Check that everything is as expected
step "- Getting some info..."
GetInfo="docker exec $qpfid "
cmd="$GetInfo psql -h ${IP_PSQL} -d ${QPFDB} -U ${EUCUSER} -c '\d'"
echo $cmd
$cmd

say "- Done."
