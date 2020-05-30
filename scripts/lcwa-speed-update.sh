#!/bin/bash
# lcwa-speed-update.sh -- script to update lcwa-speed git repo and restart service..
# Version Control for this script
{
SCRIPT_VERSION=20200529.222408

INST_NAME='lcwa-speed'

SCRIPT="$(readlink -f "$0")"
SCRIPT_NAME="$(basename "$0")"
DEBUG=0
VERBOSE=0
FORCE=0
TEST_ONLY=0

SERVICES_UPDATE=0
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

services_zip_update(){
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
		[ $TEST_ONLY -lt 1 ] && wget --quiet -O "$TEMPFILE" -S "$LURL" >/dev/null 2>&1
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

sbin_zip_update(){
	local LURL='http://www.hegardtfoundation.org/slimstuff/sbin.zip'
	local TEMPFILE="$(mktemp)"

	log_msg "Downloading updated utility scripts.."

	# Download the sbin.zip file, keeping the file modification date & time
	[ $TEST_ONLY -lt 1 ] && wget --quiet -O "$TEMPFILE" -S "$LURL" >/dev/null 2>&1
	
	if [ -f "$TEMPFILE" ]; then
		log_msg "Updating ${SCRIPT} with new verson.."
		cd /tmp
		#~ unzip -u -o -qq "$TEMPFILE" -d /usr/local
		unzip -o "$TEMPFILE" -d /usr/local
		rm "$TEMPFILE"
	fi
	
}

service_stop() {
	echo "Stopping ${INST_NAME} service.."
	if [ $USE_UPSTART -gt 0 ]; then
		[ $TEST_ONLY -lt 1 ] && initctl stop "$INST_NAME" >/dev/null 2>&1
	elif [ $USE_SYSTEMD -gt 0 ]; then
		[ $TEST_ONLY -lt 1 ] && systemctl stop "${INST_NAME}.service" >/dev/null 2>&1
	else
		if [ $IS_DEBIAN -gt 0 ]; then
			[ $TEST_ONLY -lt 1 ] && service "$INST_NAME" stop >/dev/null 2>&1
		else
			[ $TEST_ONLY -lt 1 ] && "/etc/rc.d/init.d/${INST_NAME}" stop >/dev/null 2>&1
		fi
	fi

	sleep 2

	# Failsafe stop
	local LLCWA_PID=$(pgrep -fn "$LCWA_DAEMON")

	if [ ! -z "$LLCWA_PID" ]; then
		[ $TEST_ONLY -lt 1 ] && kill -9 "$LLCWA_PID"
	fi

	return $?
}

service_start() {
	echo "Starting ${INST_NAME} service.."
	if [ $USE_UPSTART -gt 0 ]; then
		[ $TEST_ONLY -lt 1 ] && initctl start "$INST_NAME" >/dev/null 2>&1
	elif [ $USE_SYSTEMD -gt 0 ]; then
		[ $TEST_ONLY -lt 1 ] && systemctl start "${INST_NAME}.service" >/dev/null 2>&1
	else
		if [ $IS_DEBIAN -gt 0 ]; then
			[ $TEST_ONLY -lt 1 ] && service "$INST_NAME" start >/dev/null 2>&1
		else
			[ $TEST_ONLY -lt 1 ] && "/etc/rc.d/init.d/${INST_NAME}" start >/dev/null 2>&1
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
	local LLOCAL_REPO="$1"
	if [ $(pwd) != "$LLOCAL_REPO" ]; then
		log_msg "Error: ${LLOCAL_REPO} not found."
		return 128
	fi
}

#---------------------------------------------------------------------------
# Discard any local changes from the repo..
git_clean(){
	local LLOCAL_REPO="$1"
	cd "$LLOCAL_REPO" && git_in_repo "$LLOCAL_REPO"
	log_msg "Cleaning ${LLOCAL_REPO}"
	if [ -d './.git' ]; then
		[ $TEST_ONLY -lt 1 ] && git reset --hard
		[ $TEST_ONLY -lt 1 ] && git clean -fd
	elif [ -d './.svn' ]; then
		[ $TEST_ONLY -lt 1 ] && svn revert -R .
	fi
}

#---------------------------------------------------------------------------
# Update the repo..
git_update(){
	local LLOCAL_REPO="$1"
	cd "$LLOCAL_REPO" && git_in_repo "$LLOCAL_REPO" 
	log_msg "Updating ${LLOCAL_REPO}"
	if [ -d './.git' ]; then
		[ $TEST_ONLY -lt 1 ] && git pull | tee -a "$LCWA_VCLOG"
	elif [ -d './.svn' ]; then
		[ $TEST_ONLY -lt 1 ] && svn up | tee -a "$LCWA_VCLOG"
	fi
	return $?
}

git_update_do() {
	local LLOCAL_REPO="$1"
	git_clean "$LLOCAL_REPO" 
	git_update "$LLOCAL_REPO" && status=0 || status=$?
	if [ $status -eq 0 ]; then
		log_msg "${LLOCAL_REPO} has been updated."
	else
		log_msg "Error updating ${LLOCAL_REPO}."
	fi
}

git_check_up_to_date(){
	local LLOCAL_REPO="$1"
	
	cd "$LLOCAL_REPO" && git_in_repo "$LLOCAL_REPO" 
	if [ -d './.git' ]; then
		# http://stackoverflow.com/questions/3258243/git-check-if-pull-needed
		log_msg "Checking ${LLOCAL_REPO} to see if update is needed.."
		if [ $($TIMEOUT_BIN $PROC_TIMEOUT git remote -v update 2>&1 | egrep -c "\[up to date\]") -gt 0 ]; then
			log_msg "Local repository ${LLOCAL_REPO} is up to date."
			return 0
		else
			log_msg "Local repository ${LLOCAL_REPO} requires update."
			git_update_do "$LLOCAL_REPO"
			return 1
		fi
	fi
}

script_update_check(){
	local LLOCAL_REPO="$1"
	local LINSTALL_XML="${LLOCAL_REPO}/install.xml"
	local LREPO_VERSION=
	local LREPO_EPOCH=
	local LLCWA_EPOCH=
	
	if [ ! -f "$LINSTALL_XML" ]; then
		log_msg "Error: ${LINSTALL_XML} file not found."
		return 100
	fi
	
	log_msg "Checking ${LLOCAL_REPO}/install.xml to see if an update of the ${INST_NAME} service is required."
	
	#~ <version>20200511.232252</version>
	LREPO_VERSION="$(grep -E '<version>[0-9]{8}\.[0-9]{6}</version>' "$LINSTALL_XML" | sed -n -e 's/^.*\([0-9]\{8\}\.[0-9]\{6\}\).*$/\1/p')"
	
	if [ $DEBUG -gt 0 ]; then
		LREPO_EPOCH="$(echo "$LREPO_VERSION" | sed -e 's/\./ /g' | sed -e 's/\([0-9]\{8\}\) \([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2:\3:\4/')"
		LREPO_EPOCH="$(date "-d${LREPO_EPOCH}" +%s)"
		LLCWA_EPOCH="$(echo "$LCWA_VERSION" | sed -e 's/\./ /g' | sed -e 's/\([0-9]\{8\}\) \([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2:\3:\4/')"
		LLCWA_EPOCH="$(date "-d${LLCWA_EPOCH}" +%s)"
		
		log_msg "Comparing version timestamps:"
		log_msg "Running: [${LLCWA_EPOCH}] $(date_epoch_to_iso8601  ${LLCWA_EPOCH})"
		log_msg "'  Repo: [${LREPO_EPOCH}] $(date_epoch_to_iso8601  ${LREPO_EPOCH})"

		if [ $LLCWA_EPOCH -lt $LREPO_EPOCH ]; then
			log_msg "Running ${SCRIPT} version is older than repo ${LLOCAL_REPO} by $(displaytime $(echo "${LREPO_EPOCH} - ${LLCWA_EPOCH}" | bc))."
		else
			log_msg "Running ${SCRIPT} version is newer than repo ${LLOCAL_REPO} by $(displaytime $(echo "${LLCWA_EPOCH} - ${LREPO_EPOCH}" | bc))." 
		fi
	fi
	
	# If the repo version is greater than our version..
	if [[ "$LREPO_VERSION" > "$LCWA_VERSION" ]]; then
		# Update the service
		log_msg "Updating installed ${INST_NAME} service version ${LCWA_VERSION} to new version ${LREPO_VERSION} from ${LLOCAL_REPO}config-${INST_NAME}.sh"
		[ $TEST_ONLY -lt 1 ] && "${LLOCAL_REPO}/config-${INST_NAME}.sh" --update
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
	[ $TEST_ONLY -lt 1 ] && sleep $RESULT
}

################################################################################
################################################################################
# main()
################################################################################
################################################################################

# Process cmd line args..
SHORTARGS='hdvft'
LONGARGS='help,debug,verbose,force,test,services-update,no-servcies-update,sbin-update,os-update'
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
		-t|--test)
			TEST_ONLY=1
			;;
		--services-update)
			SERVICES_UPDATE=1
			;;
		--no-services-update)
			SERVICES_UPDATE=0
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

# Get our environmental variables..
env_file_read

service_stop

# Check and update Andi's repo..
git_check_up_to_date "$LCWA_LOCALREPO"

# Check & update the suplimental repo (contains this script)
git_check_up_to_date "$LCWA_LOCALSUPREPO"

# Service version is: $LCWA_VERSION
# See if we need to update the service installation
script_update_check "$LCWA_LOCALSUPREPO"


# See if we need to update this update script..
if [ $SERVICES_UPDATE -gt 0 ]; then
	services_zip_update
fi

if [ $SBIN_UPDATE -gt 0 ]; then
	sbin_zip_update
fi

if [ $OS_UPDATE -gt 0 ]; then
	log_msg "Updating operating system.."
	[ $TEST_ONLY -lt 1 ] && apt-get update
	[ $TEST_ONLY -lt 1 ] && apt-get -y upgrade
fi



if [ $REBOOT -gt 0 ]; then
	log_msg "${SCRIPT} requries a reboot of this system!"
	[ $TEST_ONLY -lt 1 ] && shutdown -r 1 "${SCRIPT} requries a reboot of this system!"
else
	# Sleep for a random number of seconds between 1 a 240 (i.e. 4 minutes)..
	sleep_random 1 240
	service_start
	service_status
fi

exit
}

