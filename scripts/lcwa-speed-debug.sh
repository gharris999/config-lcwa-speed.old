#!/bin/bash
# lcwa-speed-debug.sh -- script to debug lcwa-speed startup..

SCRIPT_VERSION=20201206.165230


DEBUG=1
FORCE=0

USE_UPSTART=0
USE_SYSTEMD=0
USE_SYSV=1

IS_DEBIAN="$(which apt-get 2>/dev/null | wc -l)"
IS_UPSTART=$(initctl version 2>/dev/null | egrep -c 'upstart')
IS_SYSTEMD=$(systemctl --version 2>/dev/null | egrep -c 'systemd')

INST_NAME=

date_msg(){
	DATE=$(date '+%F %H:%M:%S.%N')
	DATE=${DATE#??}
	DATE=${DATE%?????}
	echo "[${DATE}] $(basename $0) ($$)" $@
}

env_file_read(){

	if [ $IS_DEBIAN -gt 0 ]; then
		INST_ENVFILE="/etc/default/${INST_NAME}"
	else
		INST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

	if [ -f "$INST_ENVFILE" ]; then
		. "$INST_ENVFILE"
	else
		date_msg "Error: Could not read ${INST_ENVFILE}."
		return 128
	fi
	
	if [ $DEBUG -gt 0 ]; then
	
		set -o posix ; set | grep 'LCWA_' | sort
	fi
}


########################################################################
########################################################################
########################################################################
# main()
########################################################################
########################################################################
########################################################################

INST_NAME='lcwa-speed'

env_file_read

# Prep the debug log
DEBUG_LOGFILE="${LCWA_LOGDIR}/${INST_NAME}-debug.log"
touch "$DEBUG_LOGFILE"
#~ truncate --size=0 "$DEBUG_LOGFILE"
date_msg "$@" >"$DEBUG_LOGFILE"

# Execute the service..
$LCWA_DAEMON $LCWA_EXEC_ARGS_DEBUG 2>&1 | tee -a "$DEBUG_LOGFILE"

