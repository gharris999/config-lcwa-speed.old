#!/bin/bash

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"


TESTONLY=1
DEBUG=1
SCRIPT='/usr/local/sbin/lcwa-speed-update.sh'

date_msg(){
	DATE=$(date '+%F %H:%M:%S.%N')
	DATE=${DATE#??}
	DATE=${DATE%?????}
	echo "[${DATE}] ${SCRIPT_NAME} ($$)" $@
}


log_msg(){
	error_echo "$@"
	#~ date_msg "$@" >> "$LCWA_VCLOG"
}



sleep_random(){
	local FLOOR="$1"
	local CEILING="$2"
	local RANGE=$(($CEILING-$FLOOR+1));
	local RESULT=$RANDOM;
	let "RESULT %= $RANGE";
	RESULT=$(($RESULT+$FLOOR));
	sleep $RESULT
}



######################################################################################################
# date_epoch_to_iso8601() -- Convert an epoch time to ISO-8601 format in local TZ..
######################################################################################################
date_epoch_to_iso8601(){
	local LEPOCH="$1"
	echo "$(date -d "@${LEPOCH}" --iso-8601=s)"
}

######################################################################################################
# date_epoch_to_iso8601u() -- Convert an epoch time to ISO-8601 format in UTC..
######################################################################################################
date_epoch_to_iso8601u(){
	local LEPOCH="$1"
	echo "$(date -u -d "@${LEPOCH}" --iso-8601=s)"
}

function displaytime {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d days ' $D
  (( $H > 0 )) && printf '%d hours ' $H
  (( $M > 0 )) && printf '%d minutes ' $M
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
  printf '%d seconds\n' $S
}

script_update(){
	# Get date of ourselves..
	# Get date of file..
	local LURL='http://www.hegardtfoundation.org/slimstuff/Services.zip'
	#~ SCRIPT='/usr/local/sbin/lcwa-speed-update.sh'
	local REMOT_FILEDATE=
	local LOCAL_FILEDATE=
	local REMOT_EPOCH=
	local LOCAL_EPOCH=
	local TEMPFILE=

	log_msg "Checking ${SCRIPT} to see if update of the update is needed.."
	
	# Remote file time here: 5/1/2020 14:01
	REMOT_FILEDATE="$(curl -s -v -I -X HEAD http://www.hegardtfoundation.org/slimstuff/Services.zip 2>&1 | grep -m1 -E "^Last-Modified:")"
	# Sanitize the filedate, removing tabs, CR, LF
	REMOT_FILEDATE="$(echo "${REMOT_FILEDATE//[$'\t\r\n']}")"
	REMOT_FILEDATE="$(echo "$REMOT_FILEDATE" | sed -n -e 's/^Last-Modified: \(.*$\)/\1/p')"
	error_echo "REMOT_FILEDATE: ${REMOT_FILEDATE}"
	REMOT_EPOCH="$(date "-d${REMOT_FILEDATE}" +%s)"
	
	LOCAL_FILEDATE="$(stat -c %y ${SCRIPT})"
	LOCAL_EPOCH="$(date "-d${LOCAL_FILEDATE}" +%s)"
	
	[ $DEBUG -gt 0 ] && log_msg "Comparing dates"
	[ $DEBUG -gt 0 ] && log_msg " Local: [${LOCAL_EPOCH}] $(date_epoch_to_iso8601  ${LOCAL_EPOCH})"
	[ $DEBUG -gt 0 ] && log_msg "Remote: [${REMOT_EPOCH}] $(date_epoch_to_iso8601  ${REMOT_EPOCH})"

	[ $DEBUG -gt 0 ] && [ $LOCAL_EPOCH -lt $REMOT_EPOCH ] && log_msg "Local ${SCRIPT} is older than Remote ${LURL} by $(displaytime $(echo "${REMOT_EPOCH} - ${LOCAL_EPOCH}" | bc))." || log_msg "Local ${SCRIPT} is newer than Remote ${LURL} by $(displaytime $(echo "${LOCAL_EPOCH} - ${REMOT_EPOCH}" | bc))." 

	# Update ourselves if we're older than Services.zip
	if [ $LOCAL_EPOCH -lt $REMOT_EPOCH ]; then
		log_msg "Updating ${SCRIPT} with new verson.."
		if [ $TESTONLY -lt 1 ]; then
			TEMPFILE="$(mktemp -u)"
			# Download the Services.zip file, keeping the file modification date & time
			wget --quiet -O "$TEMPFILE" -S "$LURL" >/dev/null 2>&1
			if [ -f "$TEMPFILE" ]; then
				cd /tmp
				unzip -u -o -qq "$TEMPFILE"
				cd Services
				./install.sh
				cd "config-${INST_NAME}"
				"./config-${INST_NAME}.sh" --update
				cd /tmp
				rm -Rf ./Services
				rm "$TEMPFILE"
				REBOOT=1
			fi
		fi
	else
		log_msg "${SCRIPT} is up to date."
	fi
		
}



script_update

