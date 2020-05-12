#!/bin/bash
# lcwa-speed-update.sh -- script to update lcwa-speed git repo and restart service..
# Version Control for this script
SCRIPT_VERSION=20200511.232252

SCRIPT="$(readlink -f "$0")"
SCRIPT_NAME="$(basename "$0")"
DEBUG=0
VERBOSE=0
FORCE=0

SCRIPT_UPDATE=1
SBIN_UPDATE=0
OS_UPDATE=0
REBOOT=0

USE_UPSTART=0
USE_SYSTEMD=0
USE_SYSV=1

IS_DEBIAN="$(which apt-get 2>/dev/null | wc -l)"
IS_UPSTART=$(initctl version 2>/dev/null | egrep -c 'upstart')
IS_SYSTEMD=$(systemctl --version 2>/dev/null | egrep -c 'systemd')

####################################################################################
# Requirements: do we have the utilities needed to get the job done?
TIMEOUT_BIN=$(which timeout)

if [ -z "$TIMEOUT_BIN" ]; then
	TIMEOUT_BIN=$(which gtimeout)
fi

PROC_TIMEOUT=60

# Prefer upstart to systemd if both are installed..
if [ $IS_UPSTART -gt 0 ]; then
	USE_SYSTEMD=0
	USE_SYSV=0
	USE_UPSTART=1
elif [ $IS_SYSTEMD -gt 0 ]; then
	USE_SYSTEMD=1
	USE_SYSV=0
	USE_UPSTART=0
fi

psgrep(){
    ps aux | grep -v grep | grep -E $*
}

error_exit(){
    echo "Error: $@" 1>&2;
    exit 1
}

error_echo(){
	echo "$@" 1>&2;
}


date_msg(){
	DATE=$(date '+%F %H:%M:%S.%N')
	DATE=${DATE#??}
	DATE=${DATE%?????}
	echo "[${DATE}] ${SCRIPT_NAME} ($$)" $@
}

log_msg(){
	error_echo "$@"
	date_msg "$@" >> "$LCWA_VCLOG"
}


########################################################################
# disp_help() -- display the getopts allowable args
########################################################################
disp_help(){
	local EXTRA_ARGS="$*"
	error_echo "Syntax: $(basename "$SCRIPT") ${EXTRA_ARGS} $(echo "$SHORTARGS" | sed -e 's/, //g' -e 's/\(.\)/[-\1] /g') $(echo "[--${LONGARGS}]" | sed -e 's/,/] [--/g' | sed -e 's/:/=entry/g')" 
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
		log_msg "Error: Could not read ${INST_ENVFILE}."
		return 128
	fi
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
	else
		log_msg "${SCRIPT} is up to date."
	fi
		
}

sbin_update(){
	local LURL='http://www.hegardtfoundation.org/slimstuff/sbin.zip'
	local TEMPFILE="$(mktemp)"

	log_msg "Downloading updated utility scripts.."

	# Download the sbin.zip file, keeping the file modification date & time
	wget --quiet -O "$TEMPFILE" -S "$LURL" >/dev/null 2>&1
	
	if [ -f "$TEMPFILE" ]; then
		log_msg "Updating ${SCRIPT} with new verson.."
		cd /tmp
		#~ unzip -u -o -qq "$TEMPFILE" -d /usr/local
		unzip -u -o "$TEMPFILE" -d /usr/local
		rm "$TEMPFILE"
	fi
	
}

service_stop() {
	echo "Stopping ${INST_NAME} service.."
	if [ $USE_UPSTART -gt 0 ]; then
		initctl stop "$INST_NAME" >/dev/null 2>&1
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemctl stop "${INST_NAME}.service" >/dev/null 2>&1
	else
		if [ $IS_DEBIAN -gt 0 ]; then
			service "$INST_NAME" stop >/dev/null 2>&1
		else
			"/etc/rc.d/init.d/${INST_NAME}" stop >/dev/null 2>&1
		fi
	fi

	sleep 2

	# Failsafe stop
	local LLCWA_PID=$(pgrep -fn "$LCWA_DAEMON")

	if [ ! -z "$LLCWA_PID" ]; then
		kill -9 "$LLCWA_PID"
	fi

	return $?
}

service_start() {
	echo "Starting ${INST_NAME} service.."
	if [ $USE_UPSTART -gt 0 ]; then
		initctl start "$INST_NAME" >/dev/null 2>&1
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemctl start "${INST_NAME}.service" >/dev/null 2>&1
	else
		if [ $IS_DEBIAN -gt 0 ]; then
			service "$INST_NAME" start >/dev/null 2>&1
		else
			"/etc/rc.d/init.d/${INST_NAME}" start >/dev/null 2>&1
		fi
	fi
	return $?
}

######################################################################################################
# service_status() Get the status of the service..
######################################################################################################
service_status() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	local LSERVICE="$1"
	
	if [ -z "$LSERVICE" ]; then
		LSERVICE="$INST_NAME"
	fi

	if [ $USE_UPSTART -gt 0 ]; then
		# returns 0 if running, 1 if unknown job
		initctl status "$LSERVICE"
	elif [ $USE_SYSTEMD -gt 0 ]; then
		if [ $(echo "$LSERVICE" | grep -c -e '.*\..*') -lt 1 ]; then
			LSERVICE="${LSERVICE}.service"
		fi
		# returns 0 if service running; returns 3 if service is stopped, dead or not installed..
		systemctl --no-pager status "$LSERVICE"
	else
		# returns 0 if service is running, returns 1 if unrecognized service
		if [ $IS_DEBIAN -gt 0 ]; then
			service "$LSERVICE" status
		else
			"/etc/rc.d/init.d/${LSERVICE}" status
		fi
	fi
	return $?
}



#---------------------------------------------------------------------------
# Check to see we are where we are supposed to be..
git_in_repo(){
	if [ $(pwd) != "$LCWA_LOCALREPO" ]; then
		log_msg "Error: ${LCWA_LOCALREPO} not found."
		return 128
	fi
}

#---------------------------------------------------------------------------
# Discard any local changes from the repo..
git_clean(){
	cd "$LCWA_LOCALREPO" && git_in_repo
	log_msg "Cleaning ${LCWA_LOCALREPO}"
	if [ -d './.git' ]; then
		git reset --hard
		git clean -fd
	elif [ -d './.svn' ]; then
		svn revert -R .
	fi
}

#---------------------------------------------------------------------------
# Update the repo..
git_update(){
	cd "$LCWA_LOCALREPO" && git_in_repo
	log_msg "Updating ${LCWA_LOCALREPO}"
	if [ -d './.git' ]; then
		git pull | tee -a "$LCWA_VCLOG"
	elif [ -d './.svn' ]; then
		svn up | tee -a "$LCWA_VCLOG"
	fi
	return $?
}

git_check_up_to_date(){
	cd "$LCWA_LOCALREPO" && git_in_repo
	if [ -d './.git' ]; then
		# http://stackoverflow.com/questions/3258243/git-check-if-pull-needed
		log_msg "Checking ${LCWA_DESC} to see if update is needed.."
		if [ $($TIMEOUT_BIN $PROC_TIMEOUT git remote -v update 2>&1 | egrep -c "\[up to date\]") -gt 0 ]; then
			log_msg "Local repository ${LCWA_LOCALREPO} is up to date."
			return 0
		else
			log_msg "Local repository ${LCWA_LOCALREPO} requires update."
			return 1
		fi
	fi
}

git_update_do() {
	git_clean
	git_update && status=0 || status=$?
	if [ $status -eq 0 ]; then
		log_msg "${LCWA_DESC} has been updated."
	else
		log_msg "Error updating ${LCWA_DESC}."
	fi
}

sleep_random(){
	local FLOOR="$1"
	local CEILING="$2"
	local RANGE=$(($CEILING-$FLOOR+1));
	local RESULT=$RANDOM;
	let "RESULT %= $RANGE";
	RESULT=$(($RESULT+$FLOOR));
	log_msg "Waiting ${RESULT} seconds before restarting service.."
	sleep $RESULT
}

################################################################################
################################################################################
# main()
################################################################################
################################################################################

# Process cmd line args..
SHORTARGS='hdvf'
LONGARGS='help,debug,verbose,force,script-update,no-script-update,sbin-update,os-update'
ARGS=$(getopt -o "$SHORTARGS" -l "$LONGARGS"  -n "$(basename $0)" -- "$@")

eval set -- "$ARGS"

while [ $# -gt 0 ]; do
	case "$1" in
		--)
			;;
		-h|--help)
			disp_help
			exit 0
			;;
		-d|--debug)
			DEBUG=1
			;;
		-v|--verbose)
			VERBOSE=1
			;;
		-f|--force)
			FORCE=1
			;;
		--script-update)
			SCRIPT_UPDATE=1
			;;
		--no-script-update)
			SCRIPT_UPDATE=0
			;;
		--sbin-update)
			SBIN_UPDATE=1
			;;
		--os-update)
			OS_UPDATE=1
			;;
		*)
			log_msg "Error: unrecognized option ${1}."
			;;
	esac
	shift
done

INST_NAME=lcwa-speed

# Get our environmental variables..
env_file_read

# Service version is: $LCWA_VERSION

# Download the install.xml file from https://raw.githubusercontent.com/gharris999/config-lcwa-speed/master/install.xml

# Alternatly, just git-update the $LCWA_LOCALSUPREPO

# Read the version info from the instll.xml file:

#~ REPO_VERSION="$(grep -E '<version>.*</version>' "$TEMPFILE" | sed -n -e 's#<version>\(.*\)</version>#\1#p')"

# Compare $REPO_VERSION with $LCWA_VERSION

# If $REPO_VERSION is newer, 




# See if we need to update this update script..
if [ $SCRIPT_UPDATE -gt 0 ]; then
	script_update
fi

if [ $SBIN_UPDATE -gt 0 ]; then
	sbin_update
fi

if [ $OS_UPDATE -gt 0 ]; then
	log_msg "Updating operating system.."
	service_stop
	apt-upgrade
fi

# Check Andi's repo to see if there are updates..
git_check_up_to_date

if [[ $? -gt 0 ]] || [[ $FORCE -gt 0 ]]; then
	service_stop
	git_update_do
fi

if [ $REBOOT -gt 0 ]; then
	log_msg "${SCRIPT} requries a reboot of this system!"
	shutdown -r 1 "${SCRIPT} requries a reboot of this system!"
else
	# Sleep for a random number of seconds between 1 a 240 (i.e. 4 minutes)..
	sleep_random 1 240
	service_start
	service_status
fi



