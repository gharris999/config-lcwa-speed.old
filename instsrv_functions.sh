#!/bin/bash

######################################################################################################
# Bash include script for generically installing services on upstart, systemd & sysv systems
# 20190312 -- Gordon Harris
######################################################################################################
INCSCRIPTVER=20200517
SCRIPTNAME=$(basename "$0")

# Get the underlying user...i.e. who called sudo..
UUSER="$(who am i | awk '{print $1}')"

NOPROMPT=0
QUIET=0
VERBOSE=0
DEBUG=0
UPDATE=0
UNINSTALL=0
REMOVEALL=0
FORCE=0

DISABLE=0
ENABLE=0
UPDATE=0
UNINSTALL=0

# Defaults..should be overridden in calling script
NEEDSPID=0
NEEDSUSER=0
NEEDSDATA=0
NEEDSLOG=0
NEEDSCONF=0
NEEDSPRIORITY=0

USE_UPSTART=0
USE_SYSTEMD=0
USE_SYSV=1

USE_APT=0
USE_YUM=0

######################################################################################################
# Identify system type, init type, update utility, firewall utility, network config system..
######################################################################################################

IS_DEBIAN="$(which apt-get 2>/dev/null | wc -l)"
IS_FEDORA="$(which firewall-cmd 2>/dev/null | wc -l)"
IS_FOCAL=0

if [ $IS_DEBIAN -gt 0 ]; then
	[ "$(lsb_release -sc)" = 'focal' ] && IS_FOCAL=1
	#~ # Test to see if is Ubuntu 20.04..
	#~ UBUNTU_VER="$(lsb_release -rs)"
	#~ if [[ ! "$UBUNTU_VER" < '20.04' ]]; then
		#~ IS_FOCAL=1
	#~ else
		#~ IS_FOCAL=0
	#~ fi
fi

IS_UPSTART=$(initctl version 2>/dev/null | grep -c 'upstart')
#~ IS_SYSTEMD=$(systemctl 2>&1 | grep -c '\-\.mount')
IS_SYSTEMD=$(systemctl --version 2>/dev/null | grep -c 'systemd')

[ $IS_FEDORA -gt 0 ] && USE_YUM=1 || USE_APT=1

USE_FIREWALLD="$(which firewall-cmd 2>/dev/null | wc -l)"
USE_UFW="$(which ufw 2>/dev/null | wc -l)"

IS_NETPLAN="$(which netplan 2>/dev/null | wc -l)"


IS_DHCPCD="$(which dhcpcd 2>/dev/null | wc -l)"

if [[ $IS_DHCPCD -gt 0 ]] && [[ $IS_SYSTEMD -gt 0 ]]; then
	systemctl is-active --quiet dhcpcd.service
	[ $? -eq 0 ] && IS_DHCPCD=1 || IS_DHCPCD=0
fi


# https://ask.fedoraproject.org/en/question/49738/how-to-check-if-system-is-rpm-or-debian-based/
#~ /usr/bin/rpm -q -f /usr/bin/rpm >/dev/null 2>&1
#~ [ $? -eq 0 ] && IS_FEDORA=1 || IS_FEDORA=0
#~ [ $(which firewall-cmd 2>/dev/null | wc -l) -gt 0 ] && IS_FEDORA=1 || IS_FEDORA=0
#~ if [ $IS_FEDORA -gt 0 ]; then
	#~ USE_YUM=1
#~ else
	#~ USE_APT=1
#~ fi



# Prefer upstart to systemd if both are installed..

if [ $(ps -eaf | grep -c [u]pstart) -gt 1 ]; then
	USE_UPSTART=1
	USE_SYSTEMD=0
	USE_SYSV=0
elif [ $(ps -eaf | grep -c [s]ystemd) -gt 2 ]; then
	USE_UPSTART=0
	USE_SYSTEMD=1
	USE_SYSV=0
else
	USE_UPSTART=0
	USE_SYSTEMD=0
	USE_SYSV=1
fi


######################################################################################################
# Variables for fetching scripts to fetch/install from scserver to this machine.
######################################################################################################
SCSERVER='scserver'
SCSERVER_IP='192.168.0.198'
PING_BIN="$(which ping)"
PING_OPTS='-c 1 -w 5'


######################################################################################################
# Vars: the calling script must define at least define INST_NAME & INST_BIN
######################################################################################################

INST_NAME=
INST_PROD=
INST_DESC=

INST_BIN=
INST_PID=
INST_PIDDIR=
INST_CONF=
INST_NICE=
INST_RTPRIO=
INST_MEMLOCK=

INST_USER=
INST_GROUP=
INST_ENVFILE=
INST_ENVFILE_LOCK=0

INST_DATADIR=
INST_DATAFILE=
INST_LOGDIR=
INST_LOGFILE=

INST_IFACE=
INST_SUBNET=
INST_FWZONE=

HOSTNAME=$(hostname | tr [a-z] [A-Z])

######################################################################################################
# is_root() -- make sure we're running with suficient credentials..
######################################################################################################
function is_root(){
	if [ $(whoami) != 'root' ]; then
		echo '################################################################################'
		echo -e "\nError: ${SCRIPTNAME} needs to be run with root cridentials, either via:\n\n# sudo ${0}\n\nor under su.\n"
		echo '################################################################################'
		exit 1
	fi
}

######################################################################################################
# psgrep() -- get info on a process grepping via a regular expression..
######################################################################################################
function psgrep(){
    ps aux | grep -v grep | grep -E $*
}


######################################################################################################
# timezone_get() -- Use the ipapi.co website to get the local timezone..
######################################################################################################
function timezone_get(){
	echo "$(curl -s 'https://ipapi.co/timezone' 2>/dev/null)"
}

######################################################################################################
# timestamp_get_iso8601() -- Get a second granularity local TZ timestamp in ISO-8601 format..
######################################################################################################
function timestamp_get_iso8601(){
	echo "$(date --iso-8601=s)"
}

######################################################################################################
# timestamp_get_iso8601u() -- Get a second granularity UTC timestamp in ISO-8601 format..
######################################################################################################
timestamp_get_iso8601u(){
	echo "$(date -u --iso-8601=s)"
}

######################################################################################################
# timestamp_get_epoch() -- Get a second granularity epoch timestamp..
######################################################################################################
timestamp_get_epoch(){
	echo "$(date +%s)"
}

######################################################################################################
# date_iso8601_to_epoch() -- Convert a ISO-8601 timestamp to epoch time..
######################################################################################################
date_iso8601_to_epoch(){
	local LISO="$1"
	echo "$(date "-d${LISO}" +%s)"
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

error_log(){
	echo "${SCRIPT} $(timestamp_get_iso8601) " "$@" >"$INST_LOGFILE"
}

######################################################################################################
# error_echo() -- echo a message to stderr
######################################################################################################
error_echo(){
	echo "$@" 1>&2;
}

######################################################################################################
# error_exit() -- echo a message to stderr and exit with an errorlevel
######################################################################################################
error_exit(){
    error_echo "Error: $@"
    exit 1
}

######################################################################################################
# pause() -- echo a prompt and then wait for keypress
######################################################################################################
pause(){
	read -p "$*"
}

########################################################################
# disp_help() -- display the getopts allowable args
########################################################################
disp_help(){
	EXTRA_ARGS="$*"
	error_echo "Syntax: ${SCRIPT} ${EXTRA_ARGS} $(echo "$SHORTARGS" | sed -e 's/, //g' -e 's/\(.\)/[-\1] /g') $(echo "[--${LONGARGS}]" | sed -e 's/,/] [--/g' | sed -e 's/:/=entry/g')" 
}

######################################################################################################
# service_inst_prep() -- Set most of the INST_ variables based on $INST_NAME
######################################################################################################
service_inst_prep(){
	if [ -z "$INST_NAME" ]; then
		error_exit "INST_NAME undefined."
	fi

	[ -z "$INST_PROD" ] && INST_PROD=$(echo "$INST_NAME" | tr [a-z] [A-Z])
	[ -z "$INST_DESC" ] && INST_DESC="${INST_PROD} service daemon"
	if [ -z "$INST_BIN" ]; then
		# Try tacking on a 'd'
		INST_BIN=$(which "${INST_NAME}d")
		if [ ! -x "$INST_BIN" ]; then
			# Try just the name..
			INST_BIN=$(which "${INST_NAME}")
			if [ ! -x "$INST_BIN" ]; then
				# Try removing the 'd'
				INST_BIN=$(which "${INST_NAME%d}")
				if [ ! -x "$INST_BIN" ]; then
					# Punt!
					INST_BIN="/usr/local/bin/${INST_NAME}"
				fi
			fi
		fi
	fi
	[ -z "$INST_PIDDIR" ] && INST_PIDDIR="/var/run/${INST_NAME}"
	[ -z "$INST_PID" ] && INST_PID="${INST_PIDDIR}/${INST_NAME}.pid"
	[ -z "$INST_CONF" ] && INST_CONF="/etc/${INST_NAME}/${INST_NAME}.conf"
	[ -z "$INST_USER" ] && inst_user_create
	# [ -z "$INST_GROUP" ] &&
	if [ -z "$INST_ENVFILE" ]; then
		if [ $IS_DEBIAN -gt 0 ]; then
			INST_ENVFILE="/etc/default/${INST_NAME}"
		else
			INST_ENVFILE="/etc/sysconfig/${INST_NAME}"
		fi
	fi
	[ -z "$INST_DATADIR" ] && INST_DATADIR="/var/lib/${INST_NAME}"
	[ -z "$INST_LOGDIR" ] && INST_LOGDIR="/var/lib/${INST_NAME}"
	[ -z "$INST_LOGFILE" ] && INST_LOGFILE="${INST_LOGDIR}/${INST_NAME}.log"

}

######################################################################################################
# is_user() -- Check to see if a username exists..
######################################################################################################
is_user(){
	id -u "$1" >/dev/null 2>&1
	return $?
}

######################################################################################################
# inst_user_create() Find or create the user account the service will run under.
######################################################################################################
inst_user_create(){

	# If we don't need a user, our user will be root..
	if [ $NEEDSUSER -lt 1 ]; then
		if [ -z "$INST_USER" ]; then
			INST_USER='root'
		    INST_GROUP=$(id -ng $INST_USER)
		fi
		return 0
	fi

	# If not specific username, then name after the service..
    if [ -z "$INST_USER" ]; then
		INST_USER="$INST_NAME"
	fi

    # If still no INST_USER, get the underlying user account..
    if [ -z "$INST_USER" ]; then

        INST_USER=$(who am i | sed -n -e 's/^\([[:alnum:]]*\)\s*.*$/\1/p')
        if [ "$INST_USER" = 'root' ]; then
            #get the 1st user name with a bash shell who is not root..
            INST_USER=$(awk -F':' '{ if($7 ~ /\/bin\/bash/ && $1 !~ /root/) {print $1; exit} };0' /etc/passwd)
        fi
        # punt!
        if [ -z "$INST_USER" ]; then
            INST_USER=$(whoami)
        fi
    else
        # Check the id of the INST_USER..
        id -u "$INST_USER" >/dev/null 2>&1
        # If no such user, create the user as a system user..
        if [[ ! $? -eq 0 ]]; then
            if [ $IS_DEBIAN -gt 0 ]; then
				if [ ! -z "$INST_GROUP" ]; then
					if [ $(grep -c "$INST_GROUP" /etc/group) -lt 1 ]; then
						if [ "$INST_GROUP" = "$INST_USER" ]; then
							adduser --system --no-create-home  --group --gecos "${INST_PROD} user account" "$INST_USER"
						else
							addgroup --system "$INST_GROUP"
							adduser --system --no-create-home  --ingroup "$INST_GROUP" --gecos "${INST_PROD} user account" "$INST_USER"
						fi
					else
						adduser --system --no-create-home  --ingroup "$INST_GROUP" --gecos "${INST_PROD} user account" "$INST_USER"
					fi
				else
					adduser --system --no-create-home --gecos "${INST_PROD} user account" "$INST_USER"
				fi
            else
                useradd --user-group --no-create-home --system --shell /sbin/nologin  "$INST_USER"
            fi
        fi
    fi

    INST_GROUP=$(id -ng $INST_USER)

    echo "${INST_NAME} service account set to ${INST_USER}:${INST_GROUP}"
}

######################################################################################################
# inst_user_remove() Delete the user account..
######################################################################################################
inst_user_remove(){

	# Don't delete root
	echo "inst_user_remove: INST_USER == ${INST_USER}"
	if [[ -z "$INST_USER" ]] || [[ "$INST_USER" = 'root' ]]; then
		return 1
	fi

	# Don't delete a user with a real login account
	if [ $(cat /etc/passwd | grep -E "^${INST_USER}:.*$" | grep -c -E '/nologin|/false'	) -lt 1 ]; then
		return 1
	fi

	# Remove the user account if it exists..
	id "$INST_USER" >/dev/null 2>&1
	if [ $? -eq 0 ]; then

		echo "Removing ${INST_DESC} user account.."
		INST_GROUP="$(id -ng "$INST_USER")"

		if [ $IS_DEBIAN -gt 0  ]; then
			userdel -r $INST_USER >/dev/null 2>&1
		else
		  /usr/sbin/userdel -r -f "$INST_USER" >/dev/null 2>&1
		  /usr/sbin/groupdel "$INST_GROUP" >/dev/null 2>&1
		fi
	fi

}

######################################################################################################
# create_data_dir() Create the service data dir..
######################################################################################################
data_dir_create(){

    if [ $NEEDSDATA -lt 0 ]; then
		return 1
	fi

	if [ -z "$INST_USER" ]; then
		inst_user_create
	fi

	# Create the service data directory..
	[ -z "$INST_DATADIR" ] && INST_DATADIR="/var/lib/${INST_NAME}"

	if [ ! -d "$INST_DATADIR" ];then
		echo "Creating ${INST_DATADIR}.."
		mkdir -p "$INST_DATADIR"
	fi

	if [ ! -z "$INST_DATAFILE" ]; then
		#~ echo "# ${INST_NAME} data file -- $(date)" > "$INST_DATAFILE"
		touch "$INST_DATAFILE"
	fi

	chown -R "${INST_USER}:${INST_GROUP}" "$INST_DATADIR"
	chmod 1754 "$INST_DATADIR"

	if [ ! -d "$INST_DATADIR" ]; then
		echo "Error: could not update ${INST_DATADIR} data directory.."
		return 1
	fi

}

######################################################################################################
# data_dir_remove() Remove the service data dir..
######################################################################################################
data_dir_remove(){

    if [ $NEEDSDATA -lt 0 ]; then
		return 1
	fi

	[ -z "$INST_DATADIR" ] && INST_DATADIR="/var/lib/${INST_NAME}"

	if [ -d "$INST_DATADIR" ]; then
		echo "Removing ${INST_DATADIR} data directory.."
		rm -Rf "INST_DATADIR"
	fi

}

######################################################################################################
# data_dir_update() Update the service data dir..
######################################################################################################
data_dir_update(){

	data_dir_create

}

######################################################################################################
# create_log_dir() Create the service log dir..
######################################################################################################
log_dir_create(){

	if [ $NEEDSLOG -lt 1 ]; then
		return 1
	fi

	if [ -z "$INST_USER" ]; then
		inst_user_create
	fi

	 # Create the service log dir & file..
	[ -z "$INST_LOGDIR" ] && INST_LOGDIR="/var/log/${INST_NAME}"

	if [ ! -d "$INST_LOGDIR" ];then
		echo "Creating ${INST_LOGDIR}.."
		mkdir -p "$INST_LOGDIR"
	fi

	chown "${INST_USER}:${INST_GROUP}" "$INST_LOGDIR"
	chmod 1754 "$INST_LOGDIR"

	[ -z "$INST_LOGFILE" ] && INST_LOGFILE="${INST_LOGDIR}/${INST_NAME}.log"
	echo "Creating ${INST_LOGFILE}.."

	date > "$INST_LOGFILE"

	chown "${INST_USER}:${INST_GROUP}" "$INST_LOGFILE"
	chmod 644 "$INST_LOGFILE"

    return 0
}

######################################################################################################
# log_dir_update() Update the service log dir..
######################################################################################################
log_dir_update(){
	log_dir_create
}

######################################################################################################
# log_dir_remove() Update the service log dir..
######################################################################################################
log_dir_remove(){

	[ -z "$INST_LOGDIR" ] && INST_LOGDIR="/var/log/${INST_NAME}"

	if [ -d "$INST_LOGDIR" ]; then
		echo "Removing ${INST_LOGDIR} log directory.."
		rm -Rf "$INST_LOGDIR"
	fi

}

######################################################################################################
# log_rotate_script_create() Create the log rotate script..
# LOG_DIR="/var/log/${INST_NAME}"
# LOG_FILE="${LOG_DIR}/${INST_NAME}.log"
# log_rotate_script_create "$LOG_FILE"
######################################################################################################
log_rotate_script_create(){

	local LLOG_FILE="$1"

	if [ -z "$LLOG_FILE" ]; then
		LLOG_FILE="/var/log/${INST_NAME}/${INST_NAME}.log"
	fi

	local LBASENAME="$(basename "$LLOG_FILE")"
	LBASENAME="${LBASENAME%%.*}"

	INSTPATH="/etc/logrotate.d"

	if [ ! -d "$INSTPATH" ]; then
		mkdir -p "$INSTPATH"
	fi

	LOG_ROTATE_SCRIPT="${INSTPATH}/${LBASENAME}"

	error_echo "Creating log rotate script ${LOG_ROTATE_SCRIPT}."

	cat >"$LOG_ROTATE_SCRIPT" <<LOGROTATESCR;
${LLOG_FILE} {
    missingok
    weekly
    notifempty
    compress
    rotate 5
    size 20k
}
LOGROTATESCR

}

######################################################################################################
# log_rotate_script_remove() Remove the log rotate script..
######################################################################################################
log_rotate_script_remove(){
	local LLOG_FILE="$1"

	if [ -z "$LLOG_FILE" ]; then
		LLOG_FILE="/var/log/${INST_NAME}/${INST_NAME}.log"
	fi
	
	local LBASENAME="$(basename "$LLOG_FILE")"
	LBASENAME="${LBASENAME%%.*}"

	INSTPATH="/etc/logrotate.d"

	LOG_ROTATE_SCRIPT="${INSTPATH}/${LBASENAME}"

	if [ -f "$LOG_ROTATE_SCRIPT" ]; then
		error_echo "Removing ${LOG_ROTATE_SCRIPT} log rotate script.."
		rm -f "$LOG_ROTATE_SCRIPT"
	else
		error_echo "${LOG_ROTATE_SCRIPT} log rotate script not found."
	fi

}

######################################################################################################
# pid_dir_create() Create a location for the process ID PID file..
######################################################################################################
pid_dir_create(){

	if [ $USE_SYSTEMD -gt 0 ]; then
		if [ $# -gt 1 ]; then
			systemd_tmpfilesd_conf_create $@
		else
			systemd_tmpfilesd_conf_create 'd' "$INST_NAME" '0750' "$INST_USER" "$INST_GROUP" '10d'
		fi
		
	else
		[ -z "$INST_PIDDIR" ] && INST_PIDDIR="/var/run/${INST_NAME}"
		[ -z "$INST_PID" ] && INST_PID="${INST_PIDDIR}/${INST_NAME}.pid"

		if [ ! -d "$INST_PIDDIR" ]; then
			error_echo "Creating ${INST_PIDDIR}.."
			mkdir -p "$INST_PIDDIR"
			touch "$INST_PID"
		fi

		chown -R "${INST_USER}:${INST_GROUP}" "$INST_PIDDIR"
	fi

}

######################################################################################################
# pid_dir_remove() Remove a location for the process ID PID file..
######################################################################################################
pid_dir_remove(){

	if [ $USE_SYSTEMD -gt 0 ]; then
		systemd_tmpfilesd_conf_remove
	else

		if [ ! -z "$INST_PID" ]; then
			INST_PIDDIR=$(readlink -f $(dirname "$INST_PID"))
		else
			INST_PIDDIR="/var/run/${INST_NAME}"
			INST_PID="${INST_PIDDIR}/${INST_NAME}.pid"
		fi

		if [ -d "$INST_PIDDIR" ]; then
			error_echo "Removing ${INST_PIDDIR} pid directory.."
			rm -Rf "$INST_PIDDIR"
		fi
	fi
}


var_escape(){
	local LVAR="$1"
	
	[ $DEBUG -gt 0 ] && error_echo "Escaping string '${LVAR}'"
	
	# escape the escapes..
	LVAR="$(echo "$LVAR" | sed -e 's/\\/\\\\/g')"
	# escape the $s
	LVAR="$(echo "$LVAR" | sed -e 's/\$/\\\$/g')"
	# escape the `s
	LVAR="$(echo "$LVAR" | sed -e 's/`/\\`/g')"
	
	echo "$LVAR"

}

######################################################################################################
# env_file_create() Create the service config file.  Pass the names of the VARS to be written to the env file..
######################################################################################################
env_file_create(){

	if [ $IS_DEBIAN -gt 0 ]; then
		INST_ENVFILE="/etc/default/${INST_NAME}"
	else
		INST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

    error_echo "Creating env file ${INST_ENVFILE}.."

    if [ -f "$INST_ENVFILE" ]; then
        if [ ! -f "${INST_ENVFILE}.org" ]; then
            cp "$INST_ENVFILE" "${INST_ENVFILE}.org"
        fi
        [ $INST_ENVFILE_LOCK -lt 1 ] && mv -f "$INST_ENVFILE" "${INST_ENVFILE}.bak"
    fi

    # Put in a commented Header..
    [ $INST_ENVFILE_LOCK -lt 1 ] && echo "# ${INST_ENVFILE} -- $(timestamp_get_iso8601)" >"$INST_ENVFILE"

	if [ $INST_ENVFILE_LOCK -lt 1 ]; then
		for ARG in $@
		do
			echo "${ARG}=\"${!ARG}\"" >>"$INST_ENVFILE"
		done
	fi

}


######################################################################################################
# env_file_update() Update the service config file with new values, only changing vars that have values..
######################################################################################################
env_file_update(){
	local LINST_ENVFILE=
	local LARG=
	local LARG_VAL=
	
	if [ $IS_DEBIAN -gt 0 ]; then
		LINST_ENVFILE="/etc/default/${INST_NAME}"
	else
		LINST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

	if [ ! -f "$LINST_ENVFILE" ]; then
		error_exit "Could not find config file ${LINST_ENVFILE}.."
	fi

	for LARG in $@
	do
		# If our (indirect reference) variable isn't empty..
		if [ ! -z "${!LARG}" ]; then
			# escape the value
			LARG_VAL=$(echo "${!LARG}" | sed -e 's/#/\\#/g')

			LARG_VAL="$(var_escape "$LARG_VAL")"

			eval $LARG=\$LARG_VAL

			if [ $INST_ENVFILE_LOCK -lt 1 ]; then

				error_echo "Updating ${LINST_ENVFILE} with value ${LARG}=\"${!LARG}\""
				
				# Update the default file..
				sed -i -e "s#^${LARG}=.*#${LARG}=\"${!LARG}\"#" "$LINST_ENVFILE"

				if [ $(grep -c -E "${LARG}=\"${!LARG}\"" $LINST_ENVFILE) -lt 1 ]; then
					error_echo "Could not write value  ${LARG}=\"${!LARG}\" to ${LINST_ENVFILE}"
					grep -E "${LARG}=" $LINST_ENVFILE
					error_echo sed -i -e "s#^${LARG}=.*#${LARG}=\"${!LARG}\"#" "$LINST_ENVFILE"
					exit 1
				fi
			else
				error_echo "Env file ${LINST_ENVFILE} is locked. Cannot update with value ${LARG}=\"${!LARG}\""
			fi

		fi
	done
}

######################################################################################################
# env_file_read() Load the var values in the env file..
######################################################################################################
env_file_read(){
	local LINST_ENVFILE=

	if [ $IS_DEBIAN -gt 0 ]; then
		LINST_ENVFILE="/etc/default/${INST_NAME}"
	else
		LINST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

	if [ -f "$LINST_ENVFILE" ]; then
		. "$LINST_ENVFILE"
	else
		return 1
	fi
}

######################################################################################################
# env_file_show() Show the var values in the env file..
######################################################################################################
env_file_show(){
	local LINST_ENVFILE=
	local LVAR=

	if [ $IS_DEBIAN -gt 0 ]; then
		LINST_ENVFILE="/etc/default/${INST_NAME}"
	else
		LINST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

	. "$LINST_ENVFILE"

	for LVAR in $(cat "$LINST_ENVFILE" | grep -E '^[^# ].*=.*$' | sed -n -e 's/^\([^=]*\).*$/\1/p' | xargs)
	do
		echo "${LVAR}=\"${!LVAR}\""
	done
}

######################################################################################################
# env_file_remove() Delete the default env file..
######################################################################################################
env_file_remove(){
	local LINST_ENVFILE=

	if [ $IS_DEBIAN -gt 0 ]; then
		LINST_ENVFILE="/etc/default/${INST_NAME}"
	else
		LINST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

	if [ -f "$LINST_ENVFILE" ]; then
		error_echo "Removing env file ${LINST_ENVFILE}.."
		rm -f "$LINST_ENVFILE"
	else
		error_echo "${LINST_ENVFILE} env not found."
	fi

}

######################################################################################################
# service_is_installed() Check to see that the service is installed.  
#   Returns 1 if installed (i.e. opposite of is_service()
######################################################################################################
service_is_installed(){

	if [ $IS_DEBIAN -gt 0 ]; then
		INST_ENVFILE="/etc/default/${INST_NAME}"
	else
		INST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

	if [ $USE_UPSTART -gt 0 ]; then
		INIT_SCRIPT="/etc/init/${INST_NAME}.conf"
	elif [ $USE_SYSTEMD -gt 0 ]; then
		INIT_SCRIPT="/lib/systemd/system/${INST_NAME}.service"
	else
		if [ $IS_DEBIAN -gt 0 ]; then
			INIT_SCRIPT="/etc/init.d/${INST_NAME}"
		else
			INIT_SCRIPT="/etc/rc.d/init.d/${INST_NAME}"
		fi
	fi

	if [ ! -f "$INST_ENVFILE" ]; then
		return 0
	fi

	if [ ! -f "$INIT_SCRIPT" ]; then
		return 0
	fi

	return 1
}

######################################################################################################
# ifaces_get( bIncludeVirtuals ) return a space-delimited list of network interface devices..
######################################################################################################
ifaces_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local bINCLUDE_VIRTUAL="${1:-0}"
	local LIFACES=
	local LIFACE=

	for LIFACE in $(ls -1 /sys/class/net/ | grep -v -E '^lo$' )
	do
		# Skip any virtual interfaces..
		if [ $bINCLUDE_VIRTUAL -lt 1 ] && [ $(ls -l /sys/class/net/ | grep "${LIFACE} ->" | grep -c '/virtual/') -gt 0 ]; then
			[[ "$LIFACE" != "ppp"* ]] && continue
		fi
		LIFACES="${LIFACES} ${LIFACE}"
	done

	if [ ! -z "$LIFACES" ]; then
		[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ ) -- Interfaces: ${LIFACES}"
		echo "$LIFACES"
		return 0
	fi

	[ $VERBOSE -gt 0 ] && error_echo "Error: no network interfaces are linked."
	return 1
}


######################################################################################################
# ifacess_get_links() returns a space-delimited list of LINKED network interface devices..
######################################################################################################
ifaces_get_links(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local bINCLUDE_VIRTUAL="${1:-0}"
	local LIFACE=
	local LIFACES=
	local LIS_WIRELESS=


	# Don't match the loopback interface
	for LIFACE in $(ls -1 '/sys/class/net' | grep -v -E '^lo$' | sort | xargs)
	do

		# Skip virtual interfaces..
		if [ $bINCLUDE_VIRTUAL -lt 1 ] && [ $(ls -l /sys/class/net/ | grep "${LIFACE} ->" | grep -c '/virtual/') -gt 0 ]; then
			[[ "$LIFACE" != "ppp"* ]] && continue
		fi

		# Check to see if the nic is wireless..
		iface_is_wireless "$LIFACE"
		LIS_WIRELESS=$?

		if [ $LIS_WIRELESS -eq 0 ]; then
			# wlx2824ff1a1c0d  IEEE 802.11  ESSID:"soledad"
 			#~ if [ $(iwconfig "$LIFACE" 2>&1 | grep -c -E 'ESSID:".+"') -gt 0 ]; then
			# wlp2s0    IEEE 802.11  ESSID:off/any
			if [ $(iwconfig "$LIFACE" 2>&1 | grep -c -E 'ESSID:[^off]') -gt 0 ]; then
				LIFACES="${LIFACES} ${LIFACE}"
			fi
		else
			if [ $(ethtool "$LIFACE" 2>&1 | grep -c 'Link detected: yes') -gt 0 ]; then
				LIFACES="${LIFACES} ${LIFACE}"
			fi
		fi
	done

	if [ ! -z "$LIFACES" ]; then
		# Put the intface with the gateway first..
		for LIFACE in $LIFACES
		do
			# If the interface has a gateway..
			if [ $(networkctl status "$LIFACE" | grep -c 'Gateway: ') -gt 0 ]; then
				LIFACES=$(echo $LIFACES | sed -n -e "s/ *${LIFACE} *//p")
				LIFACES="${LIFACE} ${LIFACES}"
				break
			fi
		done
		
		[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ ) -- Linked Interfaces: ${LIFACES}"
		echo "$LIFACES"
		return 0
	fi

	[ $VERBOSE -gt 0 ] && error_echo "Error: no network interfaces are linked."

	return 1
}

########################################################################################
# iface_validate( $NETDEV) Validates an interface name. returns 0 == valid; 1 == invalid
########################################################################################
iface_validate(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"

	if [ -z "$LIFACE" ]; then
		return 1
	fi

	#~ if [ $(ls -1 '/sys/class/net' | grep -c -E "^${LIFACE}\$") -gt 0 ]; then
	if [ -e "/sys/class/net/${LIFACE}" ]; then
		return 0
	fi

	[ $VERBOSE -gt 0 ] && error_echo "Error: ${LIFACE} is not a valid network interface."
	return 1
}

echo_return(){
	$@
	RET=$?
	[ $RET ] && echo 0 || echo 1
	return $RET
}

########################################################################################
# iface_is_wireless( $NETDEV) Validates an interface as wireless. returns 0 == valid; 1 == invalid
########################################################################################
iface_is_wireless(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	if [ -z "$LIFACE" ]; then
		return 1
	fi
	if [ -e "/sys/class/net/${LIFACE}/wireless" ]; then
		[ $DEBUG -gt 0 ] && error_echo "Error: ${LIFACE} is a wireless network interface."
		return 0
	fi
	[ $DEBUG -gt 0 ] && error_echo "Error: ${LIFACE} is not a wireless network interface."
	return 1
}

########################################################################################
# iface_is_wired( $NETDEV) Validates an interface as not wireless. returns 0 == valid; 1 == invalid
########################################################################################
iface_is_wired(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	if [ -z "$LIFACE" ]; then
		return 1
	fi
	
	if [ -e "/sys/class/net/${LIFACE}" ]; then
		if [ ! -e "/sys/class/net/${LIFACE}/wireless" ]; then
			return 0
		fi
	fi
	[ $DEBUG -gt 0 ] && error_echo "Error: ${LIFACE} is not a wired network interface."
	return 1
}

########################################################################################
# iface_has_link( $NETDEV) Tests to see if an interface is linked. returns 0 == linked; 1 == no link;
########################################################################################
iface_has_link(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LIS_WIRELESS=
	
	if [ -z "$LIFACE" ]; then
		return 1
	fi

	# Check to see if the nic is wireless..
	iface_is_wireless "$LIFACE"
	LIS_WIRELESS=$?

	if [ $LIS_WIRELESS -eq 0 ]; then
		if [ $(iwconfig "$LIFACE" 2>&1 | grep -c 'ESSID:') -gt 0 ]; then
			return 0
		fi
	else
		#~ if [ $(networkctl status "$LIFACE" 2>&1 | grep -c 'State: routable') -gt 0 ]; then
		if [ $(ethtool "$LIFACE" 2>&1 | grep -c 'Link detected: yes') -gt 0 ]; then
			return 0
		fi
	fi
	
	[ $VERBOSE -gt 0 ] && error_echo "Error: ${LIFACE} has no link."
	return 1

}

########################################################################################
#
# Get the primary nic
#
# Return the 1st nic that has a link status..
#
########################################################################################

iface_primary_geta() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	#~ echo "$(ls -1 '/sys/class/net' | grep -v -E '^lo$' | sort | head -n1)"
	local LIFACE="$(ls -1 '/sys/class/net' | sort | grep -m1 -v -E '^lo$')"

	if [ ! -z "$LIFACE" ]; then
		if [ $(ethtool "$LIFACE" | egrep -c 'Link detected: yes') -lt 1 ]; then
			[ $VERBOSE -gt 0 ] && error_echo "Warning: no link detected on primary interface ${LIFACE}.."
		fi
	else
		[ $VERBOSE -gt 0 ] && error_echo "Warning: no primary interface detected.."
		return 1
	fi
	echo "$LIFACE"
	return 0
}

########################################################################################
# iface_primary_getb( ) Get the 1st linked nic with a gateway or 1st physical nic
########################################################################################
iface_primary_getb() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local bINCLUDE_VIRTUAL="${1:-0}"
	local bLINKED_ONLY="${2:-0}"
	
	local LIFACE=
	local LIFACES=

	LIFACES=$(ifaces_get_links $bINCLUDE_VIRTUAL)
	if [ ! -z "$LIFACES" ]; then
		for LIFACE in $LIFACES
		do
			if [ $(networkctl status "$LIFACE" | grep -c " Gateway: ") -gt 0 ]; then
				echo "$LIFACE"
				return 0
			fi
		done
	fi

	if [ $bLINKED_ONLY -lt 1 ]; then
		LIFACE=$(ifaces_get $bINCLUDE_VIRTUAL | awk '{ print $1 }' )	
		if [ ! -z "$LIFACE" ]; then
			echo "$LIFACE"
			return 0
		fi
	fi

	error_echo "Error: no primary network interface found.."
	return 1

}


iface_primary_get() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local PREFER_WIRELESS=${1:-0}
	local HASLINK=0
	local IFACE=''
	local IFACES=''
	local bRet=0

	if [ $PREFER_WIRELESS -gt 0 ]; then
		IFACES=$(iwconfig 2>&1 | grep 'ESSID' | awk '{print $1}')
		# Fallback if there are no wireless devices..
		if [ -z "$IFACES" ]; then
			IFACES=$(ls -1 /sys/class/net | sort | grep -v 'lo')
		fi
	else
		IFACES=$(ls -1 /sys/class/net | sort | grep -v 'lo')
	fi

	if [ -z "$IFACES" ]; then
		error_echo "Error: no network interfaces found.."
		exit 1
	fi

	# Find the 1st (sorted alpha) networking interface with a good link status..
	for IFACE in $IFACES
	do
		#Check the link status..
		if [ $(ethtool "$IFACE" | grep -c 'Link detected: yes') -gt 0 ]; then
			HASLINK=1
			break
		fi
	done

	if [ $HASLINK -gt 0 ]; then
		[ $VERBOSE -gt 0 ] && error_echo "Link detected on ${IFACE}.."
		INST_IFACE="$IFACE"
		echo "$IFACE"
		return 0
	fi

	# No link...try to wait a bit for the network to be established..
	[ $VERBOSE -gt 0 ] && error_echo "No link detected on any network interface...waiting 10 seconds to try again.."
	sleep 10

	# 2nd try..
	for IFACE in $IFACES
	do
		#Check the link status..
		if [ $(ethtool "$IFACE" | grep -c 'Link detected: yes') -gt 0 ]; then
			HASLINK=1
			break
		fi
	done

	if [ $HASLINK -gt 0 ]; then
		[ $VERBOSE -gt 0 ] && error_echo "Link detected on ${IFACE}.."
	else
		# Still no good -- our fallback: return the 1st nic..
		#IFACE="$(ls -1 /sys/class/net | sort | grep -m1 -v 'lo')"
		IFACE=${IFACES[0]}
		error_echo "No link found on any network device.  Defaulting to ${IFACE}.."
		bRet=1
	fi

	INST_IFACE="$IFACE"
	echo "$IFACE"

	[ $DEBUG -gt 0 ] && error_echo "Primary INST_IFACE == ${INST_IFACE}"

	return $bRet
}

iface_secondary_get() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	local LSKIPDEV="$1"
	local LHASLINK=0
	[ ! -z "$LSKIPDEV" ] && LSKIPDEV="|${LSKIPDEV}"
	
	# Get the 2nd entry..
	local LIFACE=$(ls -1 /sys/class/net | sort | egrep -v "lo${LSKIPDEV}" | sed -n 2p)

	if [ ! -z "$LIFACE" ]; then
		if [ $(ethtool "$LIFACE" | egrep -c 'Link detected: yes') -lt 1 ]; then
			[ $VERBOSE -gt 0 ] && error_echo "Warning: no link detected on secondary interface ${LIFACE}.."
		fi
	else
		[ $VERBOSE -gt 0 ] && error_echo "Warning: no secondary interface detected.."
		return 1
	fi
	echo "$LIFACE"
	return 0
}

########################################################################################
# iface_secondary_getb( ) Get the linked 1st nic without a gateway or 2nd physical nic
########################################################################################
iface_secondary_getb() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local bINCLUDE_VIRTUAL="${1:-0}"
	local LIFACE=
	local LIFACES=

	LIFACES=$(ifaces_get_links $bINCLUDE_VIRTUAL)
	if [ ! -z "$LIFACES" ]; then
		for LIFACE in $LIFACES
		do
			# If we con't have a gateway && we're != to the primary..
			if [ $(networkctl status "$LIFACE" | grep -c " Gateway: ") -lt 1 ] && [ "$LIFACE" != "$(iface_primary_getb)" ]; then
				echo "$LIFACE"
				return 0
			fi
		done
	fi

	# Else, just get the 2nd physical adaptor..
	LIFACE=$(ifaces_get $bINCLUDE_VIRTUAL | awk '{ print $2 }' )	
	if [ ! -z "$LIFACE" ]; then
		echo "$LIFACE"
		return 0
	fi

	error_echo "Error: no primary network interface found.."
	return 1

}



########################################################################################
#
# iface_wireless_get()  Get the first wireless interface device name..
#
########################################################################################
iface_wireless_get() {
	iw dev | grep -m1 'Interface' | awk '{ print $2 }'
}

########################################################################################
#
# default_octet_get()  Get the default static IP for this subnet based on hostname..
#
########################################################################################
default_octet_get() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	case "$(hostname)" in
		scserver)
			echo '198'
			;;
		squeezenas)
			echo '222'
			;;
		squeezenas-mini)
			echo '111'
			;;
		alunas)
			echo '5'
			;;
		medianas)
			echo '10'
			;;
		backupnas)
			echo '15'
			;;
		mountaintop-nas)
			echo '222'
			;;
		unifi-box)
			echo '234'
			;;
		*)
			# bash regular expression matching: don't quote the pattern to match!
			# If the hostname *contains* speedbox, this is a mini-server 
			# running lcwa-speedtest..

			# set nocasematch option
			shopt -s nocasematch
			
			if [[ "$(hostname)" =~ SPEEDBOX ]]; then
				echo '234'
			else
				# Default static IP for unknown hostname..
				echo '123'
			fi

			# unset nocasematch option
			shopt -u nocasematch
			;;
	esac
}

########################################################################################
#
# Validate an IPv4 address..returns 0 == valid; 1 == invalid
#
########################################################################################

ipaddress_validate_old(){
    local  LIP=$1
    local  LVALID_IP=1

	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ -z "$LIP" ]; then
		return 1
	fi

	# Can't use sipcalc as it will validate a interface name too
	#~ if [ ! -z "$(which sipcalc)" ]; then
		#~ LVALID_IP=$(sipcalc -c "$LIP" | egrep -c 'ERR')
	#~ else
		if [[ $LIP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
			OIFS=$IFS
			IFS='.'
			LIP=($LIP)
			IFS=$OIFS
			[[ ${LIP[0]} -le 255 && ${LIP[1]} -le 255 \
				&& ${LIP[2]} -le 255 && ${LIP[3]} -le 255 ]]
			LVALID_IP=$?
		fi
	#~ fi
	if [ $LVALID_IP -gt 0 ]; then
		error_echo "Error: ${LIP} is not a valid ip address."
	fi
    return $LVALID_IP
}

########################################################################################
# ipaddress_validate( IPADDR ) See if the arg is a valid ipv4 address..
########################################################################################

ipaddress_validate(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	local LIP=$1
	local LVALID_IP=1

	if [ -z "$LIP" ]; then
		[ $VERBOSE -gt 0 ] && error_echo "${FUNCNAME} error: null address"
		return 1
	fi

	if [ "$LIP" == 'dhcp' ]; then
		return 0
	fi

	if [[ $LIP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		local OIFS=$IFS
		local IFS='.'
		LIP=($LIP)
		IFS=$OIFS
		[[ ${LIP[0]} -le 255 && ${LIP[1]} -le 255 \
			&& ${LIP[2]} -le 255 && ${LIP[3]} -le 255 ]]
		LVALID_IP=$?
		IFS=$OIFS
	fi
	if [ $LVALID_IP -gt 0 ]; then
		[ $VERBOSE -gt 0 ] && error_echo "Error: ${LIP} is not a valid ip address."
	fi
	return $LVALID_IP
}



########################################################################################
#
# ipaddress_get( [$IFACE] ) Get the ipaddress of the [optional $IFACE]
#
########################################################################################

ipaddress_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	local LNETDEV="$1"
	local LIPADDR=

	if [ -z "$LNETDEV" ]; then
		#~ LIPADDR=$(ip -4 addr | grep -v -E 'inet .* lo' | grep -m1 -E 'inet ' | sed -n -e 's/^.*inet \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\/.*/\1/p')
		LIPADDR="$(networkctl status | sed -n -e 's/^\s\+Address: \([0-9\.]\+\).*$/\1/p')"
	else
		#~ LIPADDR=$(ip -4 addr list $LNETDEV | grep -m1 -E 'inet ' | sed -n -e 's/^.*inet \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\/.*/\1/p')
		LIPADDR="$(networkctl status "$LNETDEV" | sed -n -e 's/^\s\+Address: \([0-9\.]\+\).*$/\1/p')"
	fi

	[ $DEBUG -gt 0 ] && error_echo "IP address for ${LNETDEV} is ${LIPADDR}"

	echo "$LIPADDR"

}

ipaddr_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	# FLAW: ip cmd only returns an ipv4 addr if there is a link..
	#~ local LIPADDR=$(ip -4 addr | grep -v -E 'inet .* lo' | grep -m1 -E 'inet ' | sed -n -e 's/^.*inet \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\/.*/\1/p')
	local LIPADDR="$(networkctl status | sed -n -e 's/^\s\+Address: \([0-9\.]\+\).*$/\1/p')"

	[ $DEBUG -gt 0 ] && error_echo "Primary IP address == ${LIPADDR}"
	
	echo "$LIPADDR"
}

ipaddr_primary_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	# FLAW: ip cmd only returns an ipv4 addr if there is a link..
	#~ local LIPADDR=$(ip -4 addr | grep -v -E 'inet .* lo' | grep -m1 -E 'inet ' | sed -n -e 's/^.*inet \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\/.*/\1/p')
	local LIPADDR="$(networkctl status | sed -n -e 's/^\s\+Address: \([0-9\.]\+\).*$/\1/p')"
	
	# Alternative: Get the IP of the 1st linked network device..
	#~ local LDEV=$(iface_primary_get)
	#~ local LIPADDR=$(iface_ipaddress_get "$LDEV")

	[ $DEBUG -gt 0 ] && error_echo "Primary IP address == ${LIPADDR}"
	
	echo "$LIPADDR"
}

ipaddr_secondary_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	# FLAW: ip cmd only returns an ipv4 addr if there is a link..
	#~ local LIPADDR=$(ip -4 addr | sort | grep -v -E 'inet .* lo' | grep -m1 -E 'inet ' | sed -n -e 's/^.*inet \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\/.*/\1/p')
	local LIPADDR=$(ip -4 addr | sort | grep -v -E 'inet .* lo' | grep -E 'inet ' | sed -n -e 's/^.*inet \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\/.*/\1/p' | sed -n 2p)

	# Alternative: Get the IP of the 2nd linked network device..
	#~ local LDEV=$(iface_secondary_get)
	#~ local LIPADDR=$(iface_ipaddress_get "$LDEV")


	[ $DEBUG -gt 0 ] && error_echo "Secondary IP address == ${LIPADDR}"
	
	echo "$LIPADDR"
}




ipaddrs_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	local LIPADDRS=$(ip -br a | grep -v -E '^lo.*' | awk '{ print $3 }' | sed -n -e 's#^\(.*\)/.*$#\1#p')
	
	[ $DEBUG -gt 0 ] && error_echo "IP addresses == ${LIPADDRS}"
	
	echo "$LIPADDRS"
}

subnet_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LSUBNET=

	if [ -z "$INST_IFACE" ]; then
		iface_primary_get
	fi

	LSUBNET=$(iface_ipaddress_get "$INST_IFACE")

	LSUBNET=$(echo $LSUBNET | sed -n 's/\(.\{1,3\}\)\.\(.\{1,3\}\)\.\(.\{1,3\}\)\..*/\1\.\2\.\3\.0\/24/p')

	INST_SUBNET="$LSUBNET"

	[ $DEBUG -gt 0 ] && error_echo "INST_SUBNET of ${INST_IFACE} == ${INST_SUBNET}"

}


########################################################################################
#
# iface_subnet_get( $NETDEV ) Get the subnet ipaddress of the $NETDEV interface
#
########################################################################################

iface_subnet_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LSUBNET=$(ip -br a | grep "$LIFACE" | awk '{ print $3 }' | sed -n 's#\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.\)[0-9]\{1,3\}/\([0-9]\{1,2\}\).*$#\10/\2#p')

	[ $DEBUG -gt 0 ] && error_echo "INST_SUBNET of ${LIFACE} == ${LSUBNET}"
	echo "$LSUBNET"
}

iface_gateway_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	#~ local LGATEWAY="$(route -n | grep -E -o "^.*([0-9]{1,3}[\.]){3}[0-9]{1,3}.*UG.*${LIFACE}" | awk '{ print $2 }')"
	local LGATEWAY="$(networkctl status "$LIFACE" | grep 'Gateway' | awk '{ print $2 }')"

	if [ ! -z "$LGATEWAY" ]; then
		echo "$LGATEWAY"
		return 0
	fi

	[ $QUIET -lt 1 ] && error_echo "Error: Could not get gateway address for ${LIFACE}."
	return 1
}


########################################################################################
#
# ipaddress_subnet_get( $IPADDR ) Get the subnet ipaddress of the $IPADDR
#
########################################################################################

ipaddress_subnet_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local IPADDR="$1"
	local LSUBNET=

	if [ -z "$IPADDR" ]; then
		IPADDR="$(ipaddress_get)"
	fi

	LSUBNET=$(echo "$IPADDR" | sed -n 's/\(.\{1,3\}\)\.\(.\{1,3\}\)\.\(.\{1,3\}\)\..*/\1\.\2\.\3\.0\/24/p')
	echo "$LSUBNET"

	INST_SUBNET="$LSUBNET"

	[ $DEBUG -gt 0 ] && error_echo "INST_SUBNET of ${INST_IFACE} == ${INST_SUBNET}"

	if [ -z "$LSUBNET" ]; then
		return 1
	fi
	return 0
}

########################################################################################
#
# ipaddr_subnet_get( $IPADDR ) Get the subnet ipaddress of the $IPADDR
#
########################################################################################

ipaddr_subnet_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIPADDR="$1"
	local LSUBNET=

	if [ -z "$LIPADDR" ]; then
		LIPADDR="$(ipaddress_get)"
	fi

	LSUBNET=$(ip -br a | grep "$LIPADDR" | awk '{ print $3 }' | sed -n 's#\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.\)[0-9]\{1,3\}/\([0-9]\{1,2\}\).*$#\10/\2#p')

	# Punt!
	[ -z "$LSUBNET" ] && LSUBNET=$(echo "$LIPADDR" | sed -n 's/\(.\{1,3\}\)\.\(.\{1,3\}\)\.\(.\{1,3\}\)\..*/\1\.\2\.\3\.0\/24/p')
	
	[ $DEBUG -gt 0 ] && error_echo "Subnet of ${LIPADDR} == ${LSUBNET}"

	echo "$LSUBNET"

	if [ -z "$LSUBNET" ]; then
		return 1
	fi
	return 0
}


########################################################################################
#
# iface_ipaddress_get( $IFACE ) Get the ipaddress of the $IFACE
#
########################################################################################

iface_ipaddress_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LIPADDR=

	# avoid parsing ifconfig
	# use ip
	# or ifdata
	# or hostname --all-ip-addresses
	# or networkctl

	if [ -z "$LIFACE" ]; then
		#~ LIPADDR=$(hostname --all-ip-addresses | sed -n -e 's/^\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\).*$/\1/p')
		#~ LIPADDR=$(ip -br a | sort | grep -m1 -E -v '^lo.*' | awk '{ print $3 }' | sed -n -e 's#\(.*\)/\+.*$#\1#p')
		LIPADDR="$(networkctl status | sed -n -e 's/^\s\+Address: \([0-9\.]\+\).*$/\1/p')"
	else
		#~ if [ ! -z "$(which ifdata)" ]; then
			#~ LIPADDR=$(ifdata -pa "$LIFACE")
		#~ else
			#~ LIPADDR=$(ip -4 addr list $LIFACE | grep -m1 -E 'inet ' | sed -n -e 's/^.*inet \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\/.*/\1/p')
		#~ fi
		LIPADDR="$(networkctl status "$LIFACE" | sed -n -e 's/^\s\+Address: \([0-9\.]\+\).*$/\1/p')"
	fi

	[ $DEBUG -gt 0 ] && error_echo "IP address for ${LIFACE} is ${LIPADDR}"

	echo "$LIPADDR"
}


iface_hwaddress_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	local LIFACE="$1"

	if [ -z "$LIFACE" ]; then
		return 1
	fi
	
	#~ local LHWADDR="$(ifconfig "$LIFACE" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')"
	#~ local LHWADDR="$(networkctl status "$LIFACE" | grep 'HW Address:' | awk '{ print $3 }')"
	#~ local LHWADDR="$(networkctl status "$LIFACE" | sed -n -e 's/^.*HW Address: \([^\s]\+\)\s*.*$/\1/p')"

	local LHWADDR="$(cat "/sys/class/net/${LIFACE}/address")"

	if [ ! -z "$LHWADDR" ]; then
		echo "$LHWADDR"
		return 0
	fi

	[ $VERBOSE -gt 0 ] && error_echo "Error: Could not get hardware mac address for ${LIFACE}."
	return 1
}


########################################################################################
#
# ipaddress_iface_get( $IPADDR ) Get the interface device configured with $IPADDR
#
########################################################################################
ipaddress_iface_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIPADDR="$1"
	local LIFACE=
	ipaddress_validate "$LIPADDR"

	if [ $? -gt 0 ]; then
		error_echo "${LIPADDR} is not a valid IP address.."
		return 1
	fi

	#~ LIFACE=$(netstat -ie | grep -B1 "$LIPADDR" | sed -n -e 's/^\([^ ]\+\)\s.*$/\1/p')
	#~ # Strip any trailing :
	#~ LIFACE=$(echo $local | sed -e 's/^\(.*\):/\1/')

	LIFACE=$(ip -br a | grep "$LIPADDR" | awk '{ print $1 }')


	[ $DEBUG -gt 0 ] && error_echo "Interface for IP address ${LIPADDR} is ${local}"

	echo "$local"
}



######################################################################################################
# Firewall related functions...
######################################################################################################

firewall_open_port(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LPROTOCOL="$1"
	local LPORT="$2"
	local LIFACE=

	for LIFACE in $(ifaces_get)
	do
		iface_firewall_open_port "$LIFACE" "$LPROTOCOL" "$LPORT"
	done
}

firewall_close_port(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LPROTOCOL="$1"
	local LPORT="$2"
	local LIFACE=

	for LIFACE in $(ifaces_get)
	do
		iface_firewall_close_port "$LIFACE" "$LPROTOCOL" "$LPORT"
	done
}


iface_firewall_zone_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LFWZONE=

	if [ -z "$LIFACE" ]; then
		LIFACE="$(iface_primary_get)"
	fi

	if [ $USE_FIREWALLD -gt 0 ]; then
		LFWZONE="$(firewall-cmd "--get-zone-of-interface=${LIFACE}")"
	fi

	[ $DEBUG -gt 0 ] && error_echo "Firewall zone of ${LIFACE} == ${LFWZONE}"
	echo "$LFWZONE"

}

ipaddr_firewall_zone_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIPADDR="$1"
	local LFWZONE=

	if [ -z "$LIPADDR" ]; then
		LIPADDR="$(ipaddress_get)"
	fi

	if [ $USE_FIREWALLD -gt 0 ]; then
		LFWZONE="$(firewall-cmd "--get-zone-of-source=${LIPADDR}")"
	fi

	[ $DEBUG -gt 0 ] && error_echo "Firewall zone of ${LIPADDR} == ${LFWZONE}"
	echo "$LFWZONE"

}

########################################################################################
# ifaces_detect()  Re-detect network devices using udev..DEPRECATED??
#########################################################################################
ifaces_detect(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local DEV
	local NETDEVS
	local NETRULES

	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	# Only do this on Ubuntu systems..
	if [ $ISFEDORA -gt 0 ]; then
		return 0
	fi

	###################################################################################################
	# Re-detect the nic(s).  If we've cloned this system, make sure the mac address really comes from
	# this system's nic by forcing udev to regenerate the 70-persistent-net.rules file.

	# As of ubuntu 18.04, this rules file is no longer present
	NETRULES='/etc/udev/rules.d/70-persistent-net.rules'
	if [ ! -f "$NETRULES" ]; then
		[ $VERBOSE -gt 0 ] && error_echo "Cannot find network rules file: ${NETRULES}.."
		return 1
	fi

	mv -f "$NETRULES" "${NETRULES}.not"

	if [ $ALL_NICS -gt 0 ]; then
		NETDEVS=$(ls -1 /sys/class/net | sort | egrep -v '^lo$' )
	else
		NETDEVS=$(ls -1 /sys/class/net | sort | egrep -v -m1 '^lo$' )
	fi

	echo -e 'Detecting network devices..'
	for DEV in $NETDEVS
	do
		echo -e "${DEV}.."
		echo add > "/sys/class/net/${DEV}/uevent"
		sleep 1
	done
        sleep 5
	echo ' '

	if [ ! -f "$NETRULES" ]; then
	  [ $VERBOSE -gt 0 ] && error_echo "Warning: udev did not regenerate ${NETRULES} file."
	  [ $VERBOSE -gt 0 ] && error_echo "This file will probably be regenerated upon next boot."
	else
	  [ $VERBOSE -gt 0 ] && echo "New ${NETRULES} file successfully generated.."
	fi

}


########################################################################################
# iface_firewall_check_port [netdev] [udp|tcp] [portno] -- checks the firewall to see if a port is already open
#								   Returns 0 if the port is closed, 1 if open
########################################################################################

iface_firewall_check_port(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LPROTOCOL=$2
	local LPORT=$3
	local LIPADDR=$4
	local LFWZONE=
	local LSUBNET=

	if [ -z "$LIFACE" ]; then
		LIFACE="$(iface_primary_get)"
	else
		iface_validate "$LIFACE"
		# Bad interface name??
		if [ $? -gt 0 ]; then
			exit 1
		fi
	fi

	if [ $USE_FIREWALLD -gt 0 ]; then
		LPORT="${LPORT//:/-}"
		LFWZONE="$(iface_firewall_zone_get "$LIFACE")"

		if [ "$(firewall-cmd "--permanent" "--zone=${LFWZONE}" "--query-port=${LPORT}/${LPROTOCOL}" 2>&1)" = 'yes' ]; then
			return 1
		else
			return 0
		fi

	else
		# translate hyphens into colons for ufw port ranges..
		LPORT="${LPORT//-/:}"
		LSUBNET="$(iface_subnet_get "$LIFACE" "$LIPADDR")"

		#~ echo "^${LPORT}/${LPROTOCOL}\s+ALLOW\s+${LSUBNET}"
		#~ ufw status | grep -E "^${LPORT}/${LPROTOCOL}\s+ALLOW\s+${LSUBNET}"

		if [ $(ufw status | grep -c -E "^${LPORT}/${LPROTOCOL}\s+ALLOW\s+${LSUBNET}") -gt 0 ]; then
			return 1
		else
			return 0
		fi
	fi
}


iface_firewall_open_port(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LPROTOCOL=$2
	local LPORT=$3
	local LIPADDR=$4
	local LFWZONE=
	local LSUBNET=

	if [ -z "$LIFACE" ]; then
		LIFACE="$(iface_primary_get)"
	else
		iface_validate "$LIFACE"
		# Bad interface name??
		if [ $? -gt 0 ]; then
			exit 1
		fi
	fi

	LSUBNET="$(iface_subnet_get "$LIFACE" "$LIPADDR")"

	iface_firewall_check_port "$LIFACE" "$LPROTOCOL" "$LPORT" "$LIPADDR"

	if [ $? -gt 0 ]; then
		LSUBNET="$(iface_subnet_get "$LIFACE")"
		error_echo "${LPROTOCOL} port ${LPORT} already open for ${LIFACE} ${LSUBNET}"
		return 1
	fi

	if [ $USE_FIREWALLD -gt 0 ]; then
		LPORT="${LPORT//:/-}"
		LFWZONE="$(iface_firewall_zone_get "$LIFACE")"
		echo "Opening ${LIFACE} ${LFWZONE} for ${LPROTOCOL} port ${LPORT}"
		firewall-cmd "--permanent" "--zone=${LFWZONE}" "--add-port=${LPORT}/${LPROTOCOL}"
	else
		LPORT="${LPORT//-/:}"
		LSUBNET="$(iface_subnet_get "$LIFACE")"
		echo "Opening ${LIFACE} ${LSUBNET} for ${LPROTOCOL} port ${LPORT}"
		[ ! -z "$LSUBNET" ] && ufw allow proto "${LPROTOCOL}" to any port "${LPORT}" from "$LSUBNET" >/dev/null
	fi

}

iface_firewall_close_port(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LPROTOCOL=$2
	local LPORT=$3
	local LFWZONE=
	local LSUBNET=

	if [ -z "$LIFACE" ]; then
		LIFACE="$(iface_primary_get)"
	else
		iface_validate "$LIFACE"
		# Bad interface name??
		if [ $? -gt 0 ]; then
			exit 1
		fi
	fi

	iface_firewall_check_port "$LIFACE" "$LPROTOCOL" "$LPORT"

	if [ $? -lt 1 ]; then
		LSUBNET="$(iface_subnet_get "$LIFACE")"
		error_echo "${LPROTOCOL} port ${LPORT} not open for ${LIFACE} ${LSUBNET}"
		return 1
	fi

	if [ $USE_FIREWALLD -gt 0 ]; then
		LPORT="${LPORT//:/-}"
		LFWZONE="$(iface_firewall_zone_get "$LIFACE")"
		echo "Closing ${LIFACE} ${LFWZONE} for ${LPROTOCOL} port ${LPORT}"
		firewall-cmd "--permanent" "--zone=${LFWZONE}" "--remove-port=${LPORT}/${LPROTOCOL}"
	else
		LPORT="${LPORT//-/:}"
		LSUBNET="$(iface_subnet_get "$LIFACE")"
		echo "Closing ${LIFACE} ${LSUBNET} for ${LPROTOCOL} port ${LPORT}"
		[ ! -z "$LSUBNET" ] && ufw delete allow proto "${LPROTOCOL}" to any port "${LPORT}" from "$LSUBNET"
	fi

}

########################################################################################
########################################################################################
########################################################################################
########################################################################################
########################################################################################
########################################################################################
########################################################################################

########################################################################################
# iface_firewall_check_port [netdev] [udp|tcp] [portno] -- checks the firewall to see if a port is already open
#								   Returns 0 if the port is closed, 1 if open
########################################################################################

ipaddr_firewall_check_port(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIPADDR="$1"
	local LPROTOCOL=$2
	local LPORT=$3
	local LFWZONE=
	local LSUBNET=


	if [ $USE_FIREWALLD -gt 0 ]; then
		LPORT="${LPORT//:/-}"
		LFWZONE="$(ipaddr_firewall_zone_get "$LIPADDR")"

		if [ "$(firewall-cmd "--permanent" "--zone=${LFWZONE}" "--query-port=${LPORT}/${LPROTOCOL}" 2>&1)" = 'yes' ]; then
			return 1
		else
			return 0
		fi

	else
		# Translate hyphens into colons for ufw port ranges..
		LPORT="${LPORT//-/:}"
		LSUBNET="$(ipaddr_subnet_get "$LIPADDR")"

		#~ echo "^${LPORT}/${LPROTOCOL}\s+ALLOW\s+${LSUBNET}"
		#~ ufw status | grep -E "^${LPORT}/${LPROTOCOL}\s+ALLOW\s+${LSUBNET}"

		if [ $(ufw status | grep -c -E "^${LPORT}/${LPROTOCOL}\s+ALLOW\s+${LSUBNET}") -gt 0 ]; then
			return 1
		else
			return 0
		fi
	fi
}


ipaddr_firewall_open_port(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIPADDR="$1"
	local LPROTOCOL=$2
	local LPORT=$3
	local LFWZONE=
	local LSUBNET=

	if [ -z "$LIFACE" ]; then
		LIFACE="$(iface_primary_get)"
	else
		iface_validate "$LIFACE"
		# Bad interface name??
		if [ $? -gt 0 ]; then
			exit 1
		fi
	fi

	LSUBNET="$(ipaddr_subnet_get "$LIPADDR")"

	ipaddr_firewall_check_port "$LIPADDR" "$LPROTOCOL" "$LPORT"

	if [ $? -gt 0 ]; then
		error_echo "${LPROTOCOL} port ${LPORT} already open for ${LSUBNET}"
		return 1
	fi

	if [ $USE_FIREWALLD -gt 0 ]; then
		# translate colons into hyphens for port ranges
		LPORT="${LPORT//:/-}"
		LFWZONE="$(ipaddr_firewall_zone_get "$LIPADDR")"
		echo "Opening ${LSUBNET} ${LFWZONE} for ${LPROTOCOL} port ${LPORT}"
		# firewall-cmd uses hyphens to specify port ranges
		firewall-cmd "--permanent" "--zone=${LFWZONE}" "--add-port=${LPORT}/${LPROTOCOL}"
	else
		# translate hyphens into colons for port ranges
		# for castbridge.., i.e. 49152-49183
		# ufw allow 49152:49183/tcp
		# ufw allow proto tcp to any port 49152:49183 from 192.168.1.0/24
		LPORT="${LPORT//-/:}"
		echo "Opening ${LSUBNET} for ${LPROTOCOL} port ${LPORT}"
		ufw allow proto "${LPROTOCOL}" to any port "${LPORT}" from "$LSUBNET" >/dev/null
	fi

}

ipaddr_firewall_close_port(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIPADDR="$1"
	local LPROTOCOL="$2"
	local LPORT="$3"
	local LFWZONE=
	local LSUBNET=

	ipaddr_firewall_check_port "$LIPADDR" "$LPROTOCOL" "$LPORT"

	LSUBNET="$(ipaddr_subnet_get "$LIPADDR")"

	if [ $? -lt 1 ]; then
		error_echo "${LPROTOCOL} port ${LPORT} not open for ${LSUBNET}"
		return 1
	fi

	if [ $USE_FIREWALLD -gt 0 ]; then
		LPORT="${LPORT//:/-}"
		LFWZONE="$(ipaddr_firewall_zone_get "$LIPADDR")"
		echo "Closing ${LSUBNET} ${LFWZONE} for ${LPROTOCOL} port ${LPORT}"
		firewall-cmd "--permanent" "--zone=${LFWZONE}" "--remove-port=${LPORT}/${LPROTOCOL}"
	else
		LPORT="${LPORT//-/:}"
		echo "Closing ${LIFACE} ${LSUBNET} for ${LPROTOCOL} port ${LPORT}"
		ufw delete allow proto "${LPROTOCOL}" to any port "${LPORT}" from "$LSUBNET"
	fi

}



######################################################################################################
# conf_file_create() Create the service config file..
######################################################################################################
conf_file_create(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $NEEDSCONF -lt 1 ]; then
		return 1
	fi

	[ -z "$INST_CONF" ] && INST_CONF="/etc/${INST_NAME}/${INST_NAME}.conf"

	CONFIG_FILE_DIR="$(dirname "$INST_CONF")"

	if [ ! -d "$CONFIG_FILE_DIR" ]; then
		mkdir -p "$CONFIG_FILE_DIR"
	fi

	# Make a backup of any pre-existing config file..
	if [ -f "$INST_CONF" ]; then
		if [ ! -f "${INST_CONF}.org" ]; then
			cp "$INST_CONF" "${INST_CONF}.org"
		fi
		cp "$INST_CONF" "${INST_CONF}.bak"
	fi

    echo "Creating config file ${INST_CONF}.."
    echo "# ${INST_CONF} -- $(date)" >"$INST_CONF"

    # The calling script must write the body of the file..

}

######################################################################################################
# conf_file_remove() Remove the service config file..
######################################################################################################
conf_file_remove(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $NEEDSCONF -lt 1 ]; then
		return 1
	fi

	[ -z "$INST_CONF" ] && INST_CONF="/etc/${INST_NAME}/${INST_NAME}.conf"
	CONFIG_FILE_DIR="$(dirname "$INST_CONF")"

	if [ -f "$INST_CONF" ]; then
		echo "Removing config file ${INST_CONF}.."
		rm "$INST_CONF"
	fi

	if [ -d "$CONFIG_FILE_DIR" ]; then
		echo "Removing config directory ${CONFIG_FILE_DIR}.."
		rm -Rf "$CONFIG_FILE_DIR"
	fi
}

######################################################################################################
# conf_file_remove() Remove the service config dir..
######################################################################################################
conf_dir_remove(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	[ -z "$INST_CONF" ] && INST_CONF="/etc/${INST_NAME}/${INST_NAME}.conf"
	CONFIG_FILE_DIR="$(dirname "$INST_CONF")"

	if [ -d "$CONFIG_FILE_DIR" ]; then
		echo "Removing config directory ${CONFIG_FILE_DIR}.."
		rm -Rf "$CONFIG_FILE_DIR"
	fi

}

######################################################################################################
# service_priority_set() Sets values to run the daemon at a higher/normal priority
######################################################################################################
service_priority_set(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	if [ $NEEDSPRIORITY -gt 0 ]; then
		if [ $USE_UPSTART -gt 0 ]; then
			INST_NICE=-19
			INST_RTPRIO=45
			INST_MEMLOCK='unlimited'
		elif [ $USE_SYSTEMD -gt 0 ]; then
			INST_NICE=-19
			INST_RTPRIO='infinity'
			INST_MEMLOCK='infinity'
		else
			INST_NICE=-19
			INST_RTPRIO=45
			INST_MEMLOCK=
		fi
	else
		INST_NICE=
		INST_RTPRIO=
		INST_MEMLOCK=
	fi

}


######################################################################################################
# is_service( service_name ) -- returns 0 if the 
######################################################################################################
is_service(){
	local LSERVICE_NAME="$1"
	local LSERVICE_FILE=
	local LUNIT_DIR=
	
	[ -z "$LSERVICE_NAME" ] && LSERVICE_NAME="$INST_NAME"
	
	if [ $USE_SYSTEMD -gt 0 ]; then
		# Likely places to find unit files..
		for LUNIT_DIR in '/lib/systemd/system' '/etc/systemd/system'
		do
			LSERVICE_FILE="${LUNIT_DIR}/${LSERVICE_NAME}.service"
			if [ -f "$LSERVICE_FILE" ]; then
				systemctl is-active --quiet "$LSERVICE_FILE" && return 0 || return 1
			fi
		done
		return 1
	elif [ $USE_UPSTART -gt 0 ]; then
		LSERVICE_FILE="/etc/init/${LSERVICE_NAME}.conf"
	else
		if [ $IS_DEBIAN -gt 0 ]; then
			LSERVICE_FILE="/etc/init.d/${LSERVICE_NAME}"
		else
			LSERVICE_FILE="/etc/rc.d/init.d/${LSERVICE_NAME}"
		fi
	fi
	
	[ -f "${LSERVICE_FILE}" ] && return 0 || return 1
	
}

######################################################################################################
# service_create() Create the service init file..
######################################################################################################
service_create(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $USE_SYSV -eq 0 ]; then
		error_echo "${FUNCNAME}( $@ ) sysv_init_file_create is deprecated.  Use systemd"
	fi

	if [ $USE_UPSTART -gt 0 ]; then
		error_echo "${FUNCNAME}( $@ ) upstart_conf_file_create is deprecated.  Use systemd"
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_unit_file_create $@
	else
		error_echo "${FUNCNAME}( $@ ) Use of sysv is depricated. User systemd."
	fi

	service_debug_create $@

}

######################################################################################################
# service_tmpfiles_create() Create the run-time directories / tmp files 
######################################################################################################
service_tmpfiles_create(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $USE_UPSTART -gt 0 ]; then
		error_echo "${FUNCNAME}( $@ ) upstart_tmpfiles_create not implimented."
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_tmpfilesd_conf_create $@
	else
		error_echo "${FUNCNAME}( $@ ) sysv_tmpfiles_create not implimented."
	fi

}

######################################################################################################
# service_tmpfiles_create() Create the run-time directories / tmp files 
######################################################################################################
service_tmpfiles_remove(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $USE_UPSTART -gt 0 ]; then
		error_echo "${FUNCNAME}( $@ ) upstart_tmpfiles_create not implimented."
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_tmpfilesd_conf_remove
	else
		error_echo "${FUNCNAME}( $@ ) sysv_tmpfiles_create not implimented."
	fi

}


######################################################################################################
# service_prestart_set() Update service init file with prestart args..
######################################################################################################
service_prestart_set(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $USE_UPSTART -gt 0 ]; then
		error_echo "${FUNCNAME}( $@ ) upstart_conf_file_prestart_set $@ not implimented."
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_unit_file_prestart_set $@
	else
		error_echo "${FUNCNAME}( $@ ) sysv_init_file_create $@ not implimented."
	fi

}

######################################################################################################
# service_fork_set() Update service init file with forking type..
######################################################################################################
service_fork_set(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $USE_UPSTART -gt 0 ]; then
		upstart_conf_file_fork_set $@
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_unit_file_fork_set
	else
		sysv_init_file_create $@
	fi

}


######################################################################################################
# service_start_after_set() Set the service to start after another service..
######################################################################################################
service_start_after_set(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	if [ $USE_UPSTART -gt 0 ]; then
		upstart_conf_file_start_after_set $@
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_unit_file_start_after_set $@
	else
		sysv_init_file_start_after_set $@
	fi
}

######################################################################################################
# service_debug_create() Create a bash script for debugging the service
######################################################################################################
service_debug_create(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	EXEC_ARGS="$@"
	DEBUG_SCRIPT="${INST_BIN}_debug.sh"

	if [ $IS_DEBIAN -gt 0 ]; then
		INST_ENVFILE="/etc/default/${INST_NAME}"
	else
		INST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

	echo "Creating ${DEBUG_SCRIPT}"

cat >"$DEBUG_SCRIPT" <<DEBUG_SCR1;
#!/bin/bash

. ${INST_ENVFILE}

PID_DIR="\$(dirname "$INST_PID")"
if [ ! -d "\$PID_DIR" ]; then
	mkdir -p "\$PID_DIR"
fi
chown -R "${INST_USER}:${INST_GROUP}" "\$PID_DIR"

LOG_DIR="\$(dirname "$INST_LOGFILE")"
if [ ! -d "\$LOG_DIR" ]; then
	mkdir -p "\$LOG_DIR"
fi

DEBUG_LOG="${LOG_DIR}/${INST_NAME}_debug.log"

date >"\$DEBUG_LOG"

chown -R "${INST_USER}:${INST_GROUP}" "\$LOG_DIR"

echo "Starting ${INST_DESC} and writing output to \${DEBUG_LOG}"

sudo -u "$INST_USER" ${INST_BIN} ${EXEC_ARGS} >"\$DEBUG_LOG" 2>&1 &
tail -f "\$DEBUG_LOG"

DEBUG_SCR1
chmod 755 "$DEBUG_SCRIPT"
}

######################################################################################################
# service_debug_remove() Remove the bash debugging script
######################################################################################################
service_debug_remove(){
	DEBUG_SCRIPT="${INST_BIN}_debug.sh"
	if [ -f "$DEBUG_SCRIPT" ]; then
		echo "Removing ${DEBUG_SCRIPT}"
		rm "${DEBUG_SCRIPT}"
	fi
}

######################################################################################################
# service_update() Update the service script
######################################################################################################
service_update(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	if [ $USE_UPSTART -gt 0 ]; then
		upstart_conf_file_create $@
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_unit_file_create $@
	else
		sysv_init_file_create $@
	fi

	service_debug_create $@
}

######################################################################################################
# service_enable() Enable the service control links..
######################################################################################################
service_enable(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $USE_UPSTART -gt 0 ]; then
		sysv_init_file_disable $@
		upstart_conf_file_enable $@
	elif [ $USE_SYSTEMD -gt 0 ]; then
		sysv_init_file_disable $@
		systemd_unit_file_enable $@
	else
		sysv_init_file_enable $@
	fi

	return $?

}

######################################################################################################
# service_disable() Disable the service, i.e. prevent it from autostarting..
######################################################################################################
service_disable(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	if [ $REMOVEALL -gt 0 ]; then
		upstart_conf_file_disable $@
		systemd_unit_file_disable $@
		sysv_init_file_disable $@
	else
		if [ $USE_UPSTART -gt 0 ]; then
			upstart_conf_file_disable $@
		elif [ $USE_SYSTEMD -gt 0 ]; then
			systemd_unit_file_disable $@
		else
			sysv_init_file_disable $@
		fi
	fi

}

######################################################################################################
# service_remove() Uninstall the service and remove all scripts, config files, etc.
######################################################################################################
service_remove(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"

	service_stop $@
	service_disable $@

	if [ $REMOVEALL -gt 0 ]; then
		upstart_conf_file_remove $@
		systemd_unit_file_remove $@
		sysv_init_file_remove $@
	else
		if [ $USE_UPSTART -gt 0 ]; then
			upstart_conf_file_remove $@
		elif [ $USE_SYSTEMD -gt 0 ]; then
			systemd_unit_file_remove $@
		else
			sysv_init_file_remove $@
		fi
	fi

	service_debug_remove $@

	return $?
}

######################################################################################################
# service_start() Start the service..
######################################################################################################
service_start() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	local LSERVICE="$1"
	
	if [ -z "$LSERVICE" ]; then
		LSERVICE="$INST_NAME"
	fi

	error_echo "Starting ${LSERVICE} service.."
	
	if [ $USE_UPSTART -gt 0 ]; then
		initctl start "$LSERVICE" >/dev/null 2>&1
	elif [ $USE_SYSTEMD -gt 0 ]; then
		if [ $(echo "$LSERVICE" | grep -c -e '.*\..*') -lt 1 ]; then
			LSERVICE="${LSERVICE}.service"
		fi
		systemctl restart "$LSERVICE" >/dev/null 2>&1
	else
		if [ $IS_DEBIAN -gt 0 ]; then
			service "$LSERVICE" start >/dev/null 2>&1
		else
			"/etc/rc.d/init.d/${LSERVICE}" start >/dev/null 2>&1
		fi
	fi
	return $?
}

######################################################################################################
# service_stop() Stop the service..
######################################################################################################
service_stop() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	local LSERVICE="$1"
	
	if [ -z "$LSERVICE" ]; then
		LSERVICE="$INST_NAME"
	fi
	
	error_echo "Stopping ${LSERVICE} service.."

	if [ $USE_UPSTART -gt 0 ]; then
		initctl stop "$LSERVICE" >/dev/null 2>&1
	elif [ $USE_SYSTEMD -gt 0 ]; then
		if [ $(echo "$LSERVICE" | grep -c -e '.*\..*') -lt 1 ]; then
			LSERVICE="${LSERVICE}.service"
		fi
		systemctl stop "$LSERVICE" >/dev/null 2>&1
	else
		if [ $IS_DEBIAN -gt 0 ]; then
			"/etc/init.d/${LSERVICE}" stop >/dev/null 2>&1
		else
			"/etc/rc.d/init.d/${LSERVICE}" stop >/dev/null 2>&1
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

######################################################################################################
# systemd_tmpfilesd_conf_create() Create the systemd-tmpfiles conf file.  Call with execution args in a string
# systemd_tmpfilesd_conf_create 'd' servicename 0750 username usergroup age
######################################################################################################
systemd_tmpfilesd_conf_create(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local L_TYPE="$1"
	local L_INST_NAME="$2"
	local L_MODE="$3"
	local L_UID="$4"
	local L_GID="$5"
	local L_AGE="$6"

	# Strip any path info from L_INST_NAME
	L_INST_NAME="${L_INST_NAME##*/}"

	local LCONF_FILE="/usr/lib/tmpfiles.d/${INST_NAME}.tmpfile.conf"
	local L_DATA=
    echo "Creating systemd-tempfiles conf file ${LCONF_FILE}.."

	# #Type Path        Mode UID      GID      Age Argument
	# d /var/run/lighttpd 0750 www-data www-data 10d -
	L_DATA="$(printf "%s /var/run/%s %s %s %s %s -" "$L_TYPE" "$L_INST_NAME" "$L_MODE" "$L_UID" "$L_GID" "$L_AGE")"

    if [ $DEBUG -gt 0 ]; then
		echo "      L_TYPE = ${L_TYPE}"
		echo " L_INST_NAME = ${L_INST_NAME}"
		echo "      L_MODE = ${L_MODE}"
		echo "       L_UID = ${L_UID}"
		echo "       L_GID = ${L_GID}"
		echo "       L_AGE = ${L_AGE}"
		echo "$L_DATA"
	fi

	if [ ! -z "$L_DATA" ]; then
		echo '#Type Path        Mode UID      GID      Age Argument' >"$LCONF_FILE"
		echo "$L_DATA" >>"$LCONF_FILE"
	fi
	if [ ! -f "$LCONF_FILE" ]; then
		error_echo "ERROR: Could not create ${LCONF_FILE}"
		return 1
	fi
}

######################################################################################################
# systemd_tmpfilesd_conf_remove() Remove the systemd-tmpfiles conf file.
######################################################################################################
systemd_tmpfilesd_conf_remove(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LSERVICE="$1"
	
	if [ -z "$LSERVICE" ]; then
		LSERVICE="$INST_NAME"
	fi
	
	local LCONF_FILE="/usr/lib/tmpfiles.d/${LSERVICE}.tmpfile.conf"
	if [ -f "$LCONF_FILE" ]; then
		echo "Removing systemd-tempfiles conf file ${LCONF_FILE}.."
		rm -f "$LCONF_FILE"
	fi
}

######################################################################################################
# systemd_unit_file_create() Create the systemd unit file.  Call with execution args in a string
######################################################################################################
systemd_unit_file_create(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LEXEC_ARGS="$@"
	local LUNIT=
	local LUNIT_FILE=
	local LSZDATE=
	
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		LUNIT="$INST_NAME"
	else
		LUNIT="${INST_NAME}.service"
	fi
	LUNIT_FILE="/lib/systemd/system/${LUNIT}"
    echo "Creating systemd unit file ${LUNIT_FILE}.."
    
	if [ -f "$LUNIT_FILE" ]; then
		if [ ! -f "${LUNIT_FILE}.org" ]; then
			cp -p "$LUNIT_FILE" "${LUNIT_FILE}.org"
		fi
	fi
  

    LSZDATE="$(date)"

	if [ $IS_DEBIAN -gt 0 ]; then
		INST_ENVFILE="/etc/default/${INST_NAME}"
	else
		INST_ENVFILE="/etc/sysconfig/${INST_NAME}"
	fi

cat >"$LUNIT_FILE" <<SYSTEMD_SCR1;
## ${LUNIT_FILE} -- ${LSZDATE}
## systemctl service unit file

[Unit]
Description=$INST_DESC
After=network-online.target

[Service]
#UMask=0002
Nice=${INST_NICE}
LimitRTPRIO=${INST_RTPRIO}
LimitMEMLOCK=${INST_MEMLOCK}
EnvironmentFile=${INST_ENVFILE}
RuntimeDirectory=${INST_NAME}
#WorkingDirectory=${INST_NAME}
Type=simple
User=${INST_USER}
Group=${INST_GROUP}
ExecStartPre=${INST_PRE_EXEC_ARGS}
ExecStart=${INST_BIN} ${LEXEC_ARGS}
PIDFile=${INST_PID}
RestartSec=5
Restart=on-failure

[Install]
WantedBy=multi-user.target

SYSTEMD_SCR1

	# If no pid file, remove the reference..
	if [ -z "$INST_PID" ]; then
		sed -i '/PIDFile=/d' "$LUNIT_FILE"
	fi
	
	# If no prestart args, remove the reference..
	if [ -z "$INST_PRE_EXEC_ARGS" ]; then
		sed -i '/ExecStartPre=/d' "$LUNIT_FILE"
	fi
	

	systemd_unit_file_startas_set

	systemd_unit_file_priority_set
	
	

	return 0
}

######################################################################################################
# systemd_unit_file_pidfile_set() Insert or update the PIDFile path
######################################################################################################
systemd_unit_file_pidfile_set(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LUNIT=
	local LUNIT_FILE=
	local L_INST_NAME=
	local L_PIDFILE=

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		LUNIT="$INST_NAME"
	else
		LUNIT="${INST_NAME}.service"
	fi
	LUNIT_FILE="/lib/systemd/system/${LUNIT}"

	L_INST_NAME="$(echo "$INST_NAME" | sed -e 's/^\(.*\)\..*$/\1/')"

	L_PIDFILE="/var/run/${L_INST_NAME}/${L_INST_NAME}.pid"

# [Service]
# RuntimeDirectory=squeezelite
# PIDFile=/var/run/squeezelite/squeezelite.pid
	
    if [ -f "$LUNIT_FILE" ]; then
    
		if [ $(grep -c -E 'PIDFile=.*$' "$LUNIT_FILE") -gt 0 ]; then
			echo "Changing ${LUNIT_FILE} PIDFile to ${L_PIDFILE}"
			sed -i "s/^PIDFile=.*\$/PIDFile=${L_PIDFILE}/" "$LUNIT_FILE"
		else
			echo "Inserting \"PIDFile=${L_PIDFILE}\" into ${LUNIT_FILE}.."
			#~ sed -i "0,/^\[Service\].*\$/s//\[Service\]\PIDFile=${L_PIDFILE}/" "$LUNIT_FILE"
			sed -i "0,/^\[Service\].*\$/s##\[Service\]\nPIDFile=${L_PIDFILE}#" "$LUNIT_FILE"
		fi

	fi
}

######################################################################################################
# systemd_unit_file_pidfile_remove() Insert or update the PIDFile path
######################################################################################################
systemd_unit_file_pidfile_remove(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

    if [ -f "$UNIT_FILE" ]; then
		if [ $(grep -c -E '^PIDFile.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Deleting ${UNIT_FILE} PIDFile"
			sed -i '/^PIDFile.*$/d' "$UNIT_FILE"
		fi
	fi
	
}

######################################################################################################
# systemd_unit_file_runtimedir_set() Insert or update the RuntimeDirectory path
######################################################################################################
systemd_unit_file_runtimedir_set(){
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

	local L_INST_NAME="$(echo "$INST_NAME" | sed -e 's/^\(.*\)\..*$/\1/')"

# [Service]
# RuntimeDirectory=squeezelite
# PIDFile=/var/run/squeezelite/squeezelite.pid
	
    if [ -f "$UNIT_FILE" ]; then
    
		if [ $(grep -c -E 'RuntimeDirectory=.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Changing ${UNIT_FILE} RuntimeDirectory to ${L_INST_NAME}"
			sed -i "s/^RuntimeDirectory=.*\$/RuntimeDirectory=${L_INST_NAME}/" "$UNIT_FILE"
		else
			echo "Inserting \"RuntimeDirectory=${L_INST_NAME}\" into ${UNIT_FILE}.."
			sed -i "0,/^\[Service\].*\$/s//\[Service\]\nRuntimeDirectory=${L_INST_NAME}/" "$UNIT_FILE"
		fi
	fi
	
}

######################################################################################################
# systemd_unit_file_runtimedir_remove() Delete the RuntimeDirectory path
######################################################################################################
systemd_unit_file_runtimedir_remove(){
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

    if [ -f "$UNIT_FILE" ]; then
		# Delete any existing RuntimeDirectory
		if [ $(grep -c -E '^RuntimeDirectory.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Deleting ${UNIT_FILE} RuntimeDirectory"
			sed -i '/^RuntimeDirectory.*$/d' "$UNIT_FILE"
		fi
	fi
	
}

######################################################################################################
# systemd_unit_file_workingdir_set() Insert or update the WorkingDirectory path
######################################################################################################
systemd_unit_file_workingdir_set(){
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

	local L_INST_NAME="$(echo "$INST_NAME" | sed -e 's/^\(.*\)\..*$/\1/')"
	local L_WORKINGDIR="/var/run/${L_INST_NAME}"
	

# [Service]
# WorkingDirectory=/var/run/squeezelite
	
    if [ -f "$UNIT_FILE" ]; then
    
		if [ $(grep -c -E 'WorkingDirectory=.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Changing ${UNIT_FILE} WorkingDirectory to ${L_INST_NAME}"
			sed -i "s/^WorkingDirectory=.*\$/WorkingDirectory=${L_WORKINGDIR}/" "$UNIT_FILE"
		else
			echo "Inserting \"WorkingDirectory=${L_WORKINGDIR}\" into ${UNIT_FILE}.."
			#~ sed -i "0,/^\[Service\].*\$/s//\[Service\]\nRestart=${TYPE_ARGS}/" "$UNIT_FILE"
			#~ sed -i "0,/^\[Service\].*\$/s//\[Service\]\WorkingDirectory=${L_WORKINGDIR}/" "$UNIT_FILE"
			sed -i "0,/^\[Service\].*\$/s##\[Service\]\nWorkingDirectory=${L_WORKINGDIR}#" "$UNIT_FILE"
			
		fi
	fi
	
}

######################################################################################################
# systemd_unit_file_runtimedir_remove() Delete the RuntimeDirectory path
######################################################################################################
systemd_unit_file_workingdir_remove(){
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

    if [ -f "$UNIT_FILE" ]; then
		# Delete any existing WorkingDirectory
		if [ $(grep -c -E '^WorkingDirectory.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Deleting ${UNIT_FILE} WorkingDirectory"
			sed -i '/^WorkingDirectory.*$/d' "$UNIT_FILE"
		fi
	fi
}

######################################################################################################
# systemd_unit_file_prestart_set() Insert or update the pre-start command
######################################################################################################
systemd_unit_file_prestart_set(){
	EXEC_ARGS="$@"

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

    if [ -f "$UNIT_FILE" ]; then
		# Delete any existing ExecStartPre
		if [ $(grep -c -E '^ExecStartPre.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Deleting ${UNIT_FILE} ExecStartPre"
			sed -i '/^ExecStartPre.*$/d' "$UNIT_FILE"
		fi

		# Add in the prestart..
		if [ ! -z "$EXEC_ARGS" ]; then
			# Escape the args..
			EXEC_ARGS="$(echo "$EXEC_ARGS" | sed -e 's/[\/&]/\\&/g')"
			echo "Setting ${UNIT_FILE} ExecStartPre=-${EXEC_ARGS}"
			#~ ExecStartPre=-/bin/rm -f /etc/apcupsd/powerfail
			sed -i -e "s/^ExecStart.*\$/ExecStartPre=-${EXEC_ARGS}\n&/" "$UNIT_FILE"
		fi

	fi

}

######################################################################################################
# systemd_unit_file_fork_set() Insert or update the fork type command
######################################################################################################
systemd_unit_file_fork_set(){
	TYPE_ARGS="$@"

	if [ -z "$TYPE_ARGS" ]; then
		TYPE_ARGS='Type=forking'
	fi

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

    if [ -f "$UNIT_FILE" ]; then
		if [ $(grep -c -E '^Type=.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Changing ${UNIT_FILE} type to ${TYPE_ARGS}"
			sed -i "s/^Type=.*\$/${TYPE_ARGS}/" "$UNIT_FILE"
		else
			echo "Inserting \"${TYPE_ARGS}\" into ${UNIT_FILE}.."
			sed -i "0,/^\[Service\].*\$/s//\[Service\]\n${TYPE_ARGS}/" "$UNIT_FILE"
		fi
	fi
}

######################################################################################################
# systemd_unit_file_restart_set() Insert or update the restart type
######################################################################################################
systemd_unit_file_restart_set(){
	RESTART_ARGS="$@"

	if [ -z "$RESTART_ARGS" ]; then
		RESTART_ARGS='on-failure'
	fi

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

	#Restart=on-failure
	#Restart=on-abort

    if [ -f "$UNIT_FILE" ]; then
		if [ $(grep -c -E '^Restart=.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Changing ${UNIT_FILE} Restart to ${RESTART_ARGS}"
			sed -i "s/^Restart=.*\$/Restart=${RESTART_ARGS}/" "$UNIT_FILE"
		else
			echo "Inserting \"Restart=${RESTART_ARGS}\" into ${UNIT_FILE}.."
			sed -i "0,/^\[Service\].*\$/s//\[Service\]\nRestart=${TYPE_ARGS}/" "$UNIT_FILE"
		fi
	fi
}

######################################################################################################
# systemd_unit_file_bindsto_set() Insert or update the bindsto= value
######################################################################################################
systemd_unit_file_bindsto_set(){
	BINDSTO_ARGS="$@"

	if [ -z "$BINDSTO_ARGS" ]; then
		exit 0
	fi

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

	# [Unit]
	# BindsTo=lms.service

    if [ -f "$UNIT_FILE" ]; then
		if [ $(grep -c -E 'BindsTo=.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Changing ${UNIT_FILE} BindsTo to ${BINDSTO_ARGS}"
			sed -i "s/^BindsTo=.*\$/BindsTo=${BINDSTO_ARGS}/" "$UNIT_FILE"
		else
			echo "Inserting \"BindsTo=${BINDSTO_ARGS}\" into ${UNIT_FILE}.."
			sed -i "0,/^\[Unit\].*\$/s//\[Unit\]\nBindsTo=${BINDSTO_ARGS}/" "$UNIT_FILE"
		fi
	fi
}

######################################################################################################
# systemd_unit_file_wants_set() Insert or update the wants= value
######################################################################################################
systemd_unit_file_wants_set(){
	WANTS_ARGS="$@"

	if [ -z "$WANTS_ARGS" ]; then
		exit 0
	fi

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

	# [Unit]
	# Wants=squeezelite.service

    if [ -f "$UNIT_FILE" ]; then
		if [ $(grep -c -E 'Wants=.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Changing ${UNIT_FILE} Wants to ${WANTS_ARGS}"
			sed -i "s/^Wants=.*\$/Wants=${WANTS_ARGS}/" "$UNIT_FILE"
		else
			echo "Inserting \"Wants=${WANTS_ARGS}\" into ${UNIT_FILE}.."
			sed -i "0,/^\[Unit\].*\$/s//\[Unit\]\nWants=${WANTS_ARGS}/" "$UNIT_FILE"
		fi
	fi
}


######################################################################################################
# systemd_unit_file_start_before_set() Insert or update the Before= value
######################################################################################################
systemd_unit_file_start_before_set(){
	BEFORE_ARGS="$@"

	if [ -z "$BEFORE_ARGS" ]; then
		exit 0
	fi

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"

	# [Unit]
	# Before=squeezelite.service

    if [ -f "$UNIT_FILE" ]; then
		if [ $(grep -c -E 'Before=.*$' "$UNIT_FILE") -gt 0 ]; then
			echo "Changing ${UNIT_FILE} Before to ${BEFORE_ARGS}"
			sed -i "s/^Before=.*\$/Before=${BEFORE_ARGS}/" "$UNIT_FILE"
		else
			echo "Inserting \"Before=${BEFORE_ARGS}\" into ${UNIT_FILE}.."
			sed -i "0,/^\[Unit\].*\$/s//\[Unit\]\nBefore=${BEFORE_ARGS}/" "$UNIT_FILE"
		fi
	fi
}

######################################################################################################
# systemd_unit_file_start_after_set() Set the start after value
######################################################################################################
systemd_unit_file_start_after_set(){
	START_AFTER="$@"

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"
    if [ -f "$UNIT_FILE" ]; then
		#After=network.target mnt-Media.mount
		if [ $(grep -E -i -c "^After=.* *${START_AFTER} *$" "$UNIT_FILE") -gt 0 ]; then
			echo "Changing ${UNIT_FILE} After to ${START_AFTER}"
			sed -i "s/^After=.*\$/After=${START_AFTER}/" "$UNIT_FILE"
		else
			echo "Inserting \"After=${START_AFTER}\" in ${UNIT_FILE}.."
			#~ sed -i -e "s/^After=\(.*\)\$/After=\1 ${START_AFTER}/I" "$UNIT_FILE"
			sed -i -e "s/^After=.*\$/After=${START_AFTER}/I" "$UNIT_FILE"
		fi
	fi
}

######################################################################################################
# systemd_unit_file_startas_set() Comment out or update the systemd startas uid & gid
######################################################################################################
systemd_unit_file_startas_set(){
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"
    if [ -f "$UNIT_FILE" ]; then
		echo "Setting \"startas\" in ${UNIT_FILE}.."
		#~ User=lms
		#~ Group=lms
		if [[ -z "$INST_USER" ]] || [[ "$INST_USER" = 'root' ]]; then
			sed -i -e 's/^.*\(User=.*\)$/#\1/' "$UNIT_FILE"
			sed -i -e 's/^.*\(Group=.*\)$/#\1/' "$UNIT_FILE"
		else
			sed -i -e "s/^.*User=.*\$/User=${INST_USER}/" "$UNIT_FILE"
			sed -i -e "s/^.*Group=.*\$/Group=${INST_GROUP}/" "$UNIT_FILE"
		fi
	fi
}

######################################################################################################
# systemd_unit_file_priority_set() Comment out or update the systemd scheduling priority
######################################################################################################
systemd_unit_file_priority_set(){
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"
    if [ -f "$UNIT_FILE" ]; then

		echo "Setting scheduling priority in ${UNIT_FILE}.."
		#~ Nice=0
		#~ LimitRTPRIO=infinity
		#~ LimitMEMLOCK=infinity

		# If no rtprio setting, comment the limit out
		if [ -z "$INST_RTPRIO" ]; then
			sed -i -e 's/^\(LimitRTPRIO=.*\)$/#\1/' "$UNIT_FILE"
		else
			sed -i -e "s/^.*LimitRTPRIO=.*\$/LimitRTPRIO=${INST_RTPRIO}/" "$UNIT_FILE"
		fi

		if [ -z "$INST_MEMLOCK" ]; then
			sed -i -e 's/^\(LimitMEMLOCK=.*\)$/#\1/' "$UNIT_FILE"
		else
			sed -i -e "s/^.*LimitMEMLOCK=.*\$/LimitMEMLOCK=${INST_MEMLOCK}/" "$UNIT_FILE"

		fi

		# If no nice setting, comment the niceness out
		if [ -z "$INST_NICE" ]; then
			sed -i -e 's/^\(Nice=.*\)$/#\1/' "$UNIT_FILE"
		else
			sed -i -e "s/^.*Nice=.*\$/Nice=${INST_NICE}/" "$UNIT_FILE"
		fi
	fi
}


######################################################################################################
# systemd_unit_file_logto_set() Set the log stdout & stderr to file value.
# Requires systemd version >= 236
######################################################################################################
systemd_unit_file_logto_set(){
	local LSTDLOGFILE="$1"
	local LERRLOGFILE="$2"
	local LLOG_TYPE=
	local SECTION=
	local ENTRY=
	
	if [ $(systemctl --version | head -n 1 | awk '{print $2}') -ge 240 ]; then
		LLOG_TYPE='append:'
	else
		LLOG_TYPE='file:'
	fi
	
	[ $(systemd --version | grep 'systemd' | awk '{print $2}') -ge 240 ] && LLOG_TYPE='append:' || LLOG_TYPE='file:'
	
	if [ -z "$LERRLOGFILE" ]; then
		LERRLOGFILE="$1"
	fi

	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"
    if [ -f "$UNIT_FILE" ]; then
		#StandardOutput=file:|append:/var/log/logfile
		if [ $(grep -E -i -c "^StandardOutput=.*$" "$UNIT_FILE") -gt 0 ]; then
			echo "Logging ${UNIT_FILE} StandardOutput to ${LLOGFILE}"
			sed -i "s#^StandardOutput=.*\$#StandardOutput=${LLOG_TYPE}${LLOGFILE}#" "$UNIT_FILE"
		else
			echo "Inserting \"StandardOutput=${LLOG_TYPE}${LLOGFILE}\" into ${UNIT_FILE}.."

			SECTION="Service"
			ENTRY="StandardOutput=${LLOG_TYPE}${LSTDLOGFILE}"
			sed -i -e '/\['$SECTION'\]/{:a;n;/^$/!ba;i\'"$ENTRY"'' -e '}' "$UNIT_FILE"

			#~ sed -i "0,#^\[Service\].*\$#s##\[Service\]\nStandardOutput=file:${LLOGFILE}#" "$UNIT_FILE"
			#~ sed '/^anothervalue=.*/a after=me' test.txt
			#~ sed -i "#^\[Service\].*#a StandardOutput=file:${LLOGFILE}" "$UNIT_FILE"
			#~ sed -i "0,/^\[Unit\].*\$/s//\[Unit\]\nWants=${WANTS_ARGS}/" "$UNIT_FILE"

		fi
		#StandardError=file:|append:/var/log/logfile
		if [ $(grep -E -i -c "^StandardError=.*$" "$UNIT_FILE") -gt 0 ]; then
			echo "Logging ${UNIT_FILE} StandardError to ${LLOGFILE}"
			sed -i "s#^StandardError=.*\$#StandardError=${LLOG_TYPE}${LLOGFILE}#" "$UNIT_FILE"
		else
			echo "Inserting \"StandardError=${LLOG_TYPE}${LLOGFILE}\" into ${UNIT_FILE}.."
			SECTION="Service"
			ENTRY="StandardError=${LLOG_TYPE}${LERRLOGFILE}"
			sed -i -e '/\['$SECTION'\]/{:a;n;/^$/!ba;i\'"$ENTRY"'' -e '}' "$UNIT_FILE"
			#~ sed -i "0,#^\[Service\].*\$#s##\[Service\]\nStandardError=file:${LLOGFILE}#" "$UNIT_FILE"
			#~ sed -i "#^\[Service\].*#a StandardError=file:${LLOGFILE}" "$UNIT_FILE"
		fi
	fi
	
	touch "$LSTDLOGFILE"
	chown "${INST_USER}:${INST_GROUP}" "$LSTDLOGFILE"
	touch "$LERRLOGFILE"
	chown "${INST_USER}:${INST_GROUP}" "$LERRLOGFILE"
}






######################################################################################################
# systemd_unit_file_Update() Update the systemd unit file with new values
######################################################################################################
systemd_unit_file_update(){
    systemd_unit_file_create $@
}

######################################################################################################
# systemd_unit_file_enable() Enable the systemd service unit file
######################################################################################################
systemd_unit_file_enable(){
	systemctl daemon-reload >/dev/null 2>&1

	local LUNIT="$1"
	local LUNIT_FILE=

	if [ -z "$LUNIT" ]; then
		LUNIT="${INST_NAME}.service"
	fi

	if [ $(echo "$LUNIT" | grep -c -e '.*\..*') -lt 1 ]; then
		LUNIT="${LUNIT}.service"
	fi
	
	LUNIT_FILE="/lib/systemd/system/${LUNIT}"

	if [ -f "$LUNIT_FILE" ]; then
		echo "Enabling ${LUNIT_FILE} systemd unit file.."
			
		systemctl stop "$LUNIT" >/dev/null 2>&1
		systemctl enable "$LUNIT" >/dev/null 2>&1
	else
		error_echo "Cannot find ${LUNIT_FILE} systemd unit file.."
	fi
}

systemd_unit_file_start() {
	systemctl daemon-reload >/dev/null 2>&1

	local LUNIT="$1"
	local LUNIT_FILE=

	if [ -z "$LUNIT" ]; then
		LUNIT="${INST_NAME}.service"
	fi

	if [ $(echo "$LUNIT" | grep -c -e '.*\..*') -lt 1 ]; then
		LUNIT="${LUNIT}.service"
	fi

	LUNIT_FILE="/lib/systemd/system/${LUNIT}"
	if [ -f "$LUNIT_FILE" ]; then
		echo "Starting ${LUNIT_FILE} systemd unit file.."
			
		systemctl start "$LUNIT" >/dev/null 2>&1
		systemctl -l --no-pager status "$LUNIT"
	else
		error_echo "Cannot find ${LUNIT_FILE} systemd unit file.."
	fi
}

systemd_unit_file_stop() {
	local LUNIT="$1"
	local LUNIT_FILE=

	if [ -z "$LUNIT" ]; then
		LUNIT="${INST_NAME}.service"
	fi

	if [ $(echo "$LUNIT" | grep -c -e '.*\..*') -lt 1 ]; then
		LUNIT="${LUNIT}.service"
	fi

	LUNIT_FILE="/lib/systemd/system/${LUNIT}"
	if [ -f "$LUNIT_FILE" ]; then
		echo "Stopping ${LUNIT_FILE} systemd unit file.."
			
		systemctl stop "$LUNIT" >/dev/null 2>&1
		systemctl -l --no-pager status "$LUNIT"
	else
		error_echo "Cannot find ${LUNIT_FILE} systemd unit file.."
	fi
}

systemd_unit_file_status() {
	local LUNIT="$1"
	local LUNIT_FILE=

	if [ -z "$LUNIT" ]; then
		LUNIT="${INST_NAME}.service"
	fi

	if [ $(echo "$LUNIT" | grep -c -e '.*\..*') -lt 1 ]; then
		LUNIT="${LUNIT}.service"
	fi

	LUNIT_FILE="/lib/systemd/system/${LUNIT}"
	if [ -f "$LUNIT_FILE" ]; then
		systemctl -l --no-pager status "$LUNIT"
	else
		error_echo "Cannot find ${LUNIT_FILE} systemd unit file.."
	fi
}


######################################################################################################
# systemd_unit_file_disable() Disable the systemd service unit file
######################################################################################################
systemd_unit_file_disable(){
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"
	if [ -f "$UNIT_FILE" ]; then
		echo "Disabling ${UNIT_FILE} systemd unit file.."
		systemctl stop "$UNIT" >/dev/null 2>&1
		systemctl disable "$UNIT" >/dev/null 2>&1
	fi
	systemctl daemon-reload >/dev/null 2>&1
}

######################################################################################################
# systemd_unit_file_remove() Remove the systemd service unit file
######################################################################################################
systemd_unit_file_remove(){
	if [ $(echo "$INST_NAME" | grep -c -e '.*\..*') -gt 0 ]; then
		UNIT="$INST_NAME"
	else
		UNIT="${INST_NAME}.service"
	fi
	UNIT_FILE="/lib/systemd/system/${UNIT}"
	DEBUG_FILE="$(echo "$UNIT_FILE" | sed -e 's#^\(.*\)\.\(.*\)$#\1_debug.\2#')"

	for FILE in "$UNIT_FILE" "$DEBUG_FILE"
	do
		if [ -f "$FILE" ]; then
			echo "Removing ${FILE} systemd unit file.."
			rm "$FILE"
		fi
	done
	systemctl daemon-reload >/dev/null 2>&1
}




######################################################################################################
# upstart_conf_file_enable() Enable the upstart conf file (delete the manual override)
######################################################################################################
upstart_conf_file_enable(){
	INIT_SCRIPT="/etc/init/${INST_NAME}.conf"
	if [ -f "$INIT_SCRIPT" ]; then
		echo "Enabling ${INIT_SCRIPT} upstart conf file.."
	fi
	INIT_OVERRIDE="/etc/init/${INST_NAME}.override"
	if [ -f "$INIT_OVERRIDE" ]; then
		rm "$INIT_OVERRIDE"
	fi
	initctl reload-configuration >/dev/null 2>&1
}

######################################################################################################
# upstart_conf_file_disable() Disable the upstart conf file (create a manual override)
######################################################################################################
upstart_conf_file_disable(){
	INIT_SCRIPT="/etc/init/${INST_NAME}.conf"
	if [ -f "$INIT_SCRIPT" ]; then
		echo "Disabling ${INIT_SCRIPT} upstart conf file.."
		INIT_OVERRIDE="/etc/init/${INST_NAME}.override"
		echo 'manual' >"$INIT_OVERRIDE"
	fi
	initctl reload-configuration >/dev/null 2>&1
}

######################################################################################################
# upstart_conf_file_remove() Remove the upstart conf file
######################################################################################################
upstart_conf_file_remove(){
	INIT_SCRIPT="/etc/init/${INST_NAME}.conf"
	INIT_OVERRIDE="/etc/init/${INST_NAME}.override"
	INIT_DEBUG_SCRIPT="/etc/init/${INST_NAME}_debug.conf"
	INIT_DEBUG_OVERRIDE="/etc/init/${INST_NAME}_debug.override"
	for FILE in "$INIT_SCRIPT" "$INIT_OVERRIDE" "$INIT_DEBUG_SCRIPT" "$INIT_DEBUG_OVERRIDE"
	do
		if [ -f "$FILE" ]; then
			echo "Removing ${FILE} upstart conf file.."
			rm "$FILE"
		fi
	done
	initctl reload-configuration >/dev/null 2>&1
}

######################################################################################################
# sysv_init_file_enable() Update sysv service control links
######################################################################################################
sysv_init_file_enable(){
	if [ $IS_DEBIAN -gt 0 ]; then
		INIT_SCRIPT="/etc/init.d/${INST_NAME}"
	else
		INIT_SCRIPT="/etc/rc.d/init.d/${INST_NAME}"
	fi
	if [ -f "$INIT_SCRIPT" ]; then
		echo "Enabling ${INST_NAME} sysv service control links.."
		if [ $IS_DEBIAN -gt 0 ]; then
			update-rc.d -f "$INST_NAME" remove >/dev/null 2>&1
			update-rc.d -f "$INST_NAME" defaults >/dev/null 2>&1
		else
			chkconfig --del "$INST_NAME" >/dev/null 2>&1
			chkconfig --add "$INST_NAME" >/dev/null 2>&1
			chkconfig --level 35 "$INST_NAME" on >/dev/null 2>&1
		fi
	fi
}

######################################################################################################
# sysv_init_file_disable() Update sysv service control links
######################################################################################################
sysv_init_file_disable(){
	if [ $IS_DEBIAN -gt 0 ]; then
		INIT_SCRIPT="/etc/init.d/${INST_NAME}"
	else
		INIT_SCRIPT="/etc/rc.d/init.d/${INST_NAME}"
	fi
	if [ -f "$INIT_SCRIPT" ]; then
		echo "Disabling ${INST_NAME} sysv service control links.."
		if [ $IS_DEBIAN -gt 0 ]; then
			update-rc.d -f "$INST_NAME" remove >/dev/null 2>&1
		else
			chkconfig --del "$INST_NAME" >/dev/null 2>&1
		fi
	fi
}

sysv_init_file_remove(){
	if [ $IS_DEBIAN -gt 0 ]; then
		INIT_SCRIPT="/etc/init.d/${INST_NAME}"
	else
		INIT_SCRIPT="/etc/rc.d/init.d/${INST_NAME}"
	fi
	if [ -f "$INIT_SCRIPT" ]; then
		echo "Removing ${INIT_SCRIPT} sysv init file"
		rm "$INIT_SCRIPT"
	fi

}

main_disable_service(){
	service_disable
}

main_enable_service(){
	service_enable
}

main_update_service(){

	if [ $FORCE -lt 1 ]; then
		service_is_installed
		if [ $? -gt 0 ]; then
			error_exit "${INST_NAME} is not installed.  Cannot update ${INST_NAME}.."
		fi
	fi

	service_stop
	service_disable

	env_file_update
	env_file_read
	log_dir_update
	service_update

	service_enable
	service_start

}

main_remove_service(){

	if [ $FORCE -lt 1 ]; then
		service_is_installed

		if [ $? -lt 1 ]; then
			error_exit "${INST_NAME} is not installed.  Cannot remove ${INST_NAME}.."
		fi
	fi

	env_file_read
	service_stop
	service_disable
	service_remove
	log_dir_remove
	data_dir_remove
	conf_file_remove
	env_file_remove
	inst_user_remove

	echo "${INST_NAME} is uninstalled."

}

main_install_service(){
	# Get our default values
	service_inst_prep

	# Get the service account
	inst_user_create

	# Create a data dir
	data_dir_create

	# Create a log dir
	log_dir_create
	log_rotate_script_create

	# Create the env var file
	env_file_create

	# Create the config file
	conf_file_create

	# Create the service init script
	service_create

	# Create the service control links..
	service_enable

}

pass_get_root(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	echo " YXJnbGViYXJnbGUK " | openssl enc -base64 -d	
}

pass_get_daadmin(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	echo " ZnVmZXJhbAo= " | openssl enc -base64 -d
}

####################################################################################
# ping_wait()  See if an IP is reachable via ping. Returns 0 if the host is reachable
####################################################################################
ping_wait(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"

	local LIP_ADDR="$1"
	local LPING_COUNT=$2
	local i=0
	
	if [ -z "$LIP_ADDR" ]; then
		return 1
	fi


	if [ -z $LPING_COUNT ]; then
		LPING_COUNT=5
	fi


	for (( i=0; i<$LPING_COUNT; i++ ))
	do
		"$PING_BIN" $PING_OPTS "$LIP_ADDR" > /dev/null 2>&1

		if [ $? -gt 0 ]; then
			if [ $VERBOSE -gt 2 ]; then
				error_echo "${LIP_ADDR} is not ready.."
			fi
			sleep 1
		else
			if [ $VERBOSE -gt 2 ]; then
				error_echo "${LIP_ADDR} is ready.."
			fi
			return 0
		fi
	done

	return 1
}

########################################################################
# is_scserver -- echos 1 if scserver is available on the local subnet
########################################################################
is_scserver() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"

	# If we are scserver, return 0 to force downloading zips, rather than fetching from ourselves!
	if [ "$(hostname)" = "$SCSERVER" ]; then
		echo '0'
		return 1
	fi

	ping_wait "$SCSERVER_IP"
	if [ $? -eq 0 ]; then
		echo '1'
		return 0
	else
		echo '0'
		return 1
	fi

	return 0
}

########################################################################
# ami_scserver -- returns 1 if hostname == scserver
########################################################################
ami_scserver(){
	if [ $(hostname | grep -c -i -E '^scserver$') -gt 0 ]; then
		return 1
	fi
	return 0
}

########################################################################
# script_dir_fetch( /scriptdirpath -- copies files from scserver to
#     the scriptdirpath via robocopy|rsync|scp
########################################################################
script_dir_fetch(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LSCRIPTDIR="$1"
	local LTARGETDIR=
	local LUSER=
	local LGROUP=
	local LPASS=
	local LIS_ROOT=0
	local LROBOCOPY="$(which robocopy)"
	local LRSYNC="$(which rsync)"
	local LSCP="$(which scp)"
	local LSSHPASS="$(which sshpass)"
	local LCOPYCMD=
	local LTO_NULL='>/dev/null'

	[ $VERBOSE -gt 0 ] && LTO_NULL=

	if [ -z "$LSCRIPTDIR" ]; then
		error_echo "${FUNCNAME}( $@ ) target script directory name required."
		return 1
	fi

	# Get the password for the SCRIPTDIR
	# We need root for anything off /usr or /var, all else should be daadmin
	if [ $(echo "$LSCRIPTDIR" | grep -c -E '^/usr/.*|^/var/.*') -gt 0 ]; then
		LIS_ROOT=1
		LUSER='root'
		LGROUP=$(id -ng $LUSER)
		LPASS="$(pass_get_root)"
	else
		LIS_ROOT=0
		LUSER='daadmin'
		LGROUP=$(id -ng $LUSER)
		LPASS="$(pass_get_daadmin)"
	fi

	# Setup sshpass
	if [ ! -z "$LSSHPASS" ]; then
		LSSHPASS="${LSSHPASS} -p ${LPASS}"
	fi

	error_echo ' '

	# Change to the target dir..we should NOT need to create the dir as all the zipped scripts include relative paths..
	# Cope with 'Aux' script dirs.  Zip files for Aux dirs won't contain full relative paths..
	if [ $(echo "$LSCRIPTDIR" | grep -c 'Aux') -gt 0 ]; then
		LTARGETDIR="$(echo "$LSCRIPTDIR" | sed -e 's#Aux##')"
	else
		LTARGETDIR="$LSCRIPTDIR"
	fi

	# Create the target directory..
	if [ ! -d "$LTARGETDIR" ]; then
		error_echo "Creating directory ${LTARGETDIR}"
		mkdir -p "$LTARGETDIR"
	fi

	# Construct the COPYCMD using our most capable available utility..
	if [ ! -z "$LROBOCOPY" ]; then
		LCOPYCMD="${LROBOCOPY} --quiet --password=${LPASS} -se ${LUSER}@scserver:${LSCRIPTDIR} ${LTARGETDIR} ${LTO_NULL}"
	elif [ ! -z "$LRSYNC" ]; then
		LCOPYCMD="${LSSHPASS} ${LRSYNC} -avzP ${LUSER}@scserver:${LSCRIPTDIR} ${LTARGETDIR} ${LTO_NULL}"
	elif [ ! -z "$LSCP" ]; then
		LCOPYCMD="${LSSHPASS} ${LSCP} -rp ${LUSER}@scserver:${LSCRIPTDIR} ${LTARGETDIR} ${LTO_NULL}"
	fi

	if [ -z "$LCOPYCMD" ]; then
		error_echo "${FUNCNAME}( $@ ) Error: Could not construct a copy command to fetch from ${LSCRIPTDIR}."
		return 1
	fi

	error_echo "Fetching files for ${LTARGETDIR}"

	eval "$LCOPYCMD"

	error_echo "Making scripts executable in ${LTARGETDIR}.."
	[ $VERBOSE -gt 0 ] && find "$LTARGETDIR" -name '*.sh' -print -exec chmod 755 {} \; || find "$LTARGETDIR" -name '*.sh' -exec chmod 755 {} \; 

	# Fixup permissions..
	#~ if [ $(echo "$LTARGETDIR" | grep -c 'lms') -gt 0 ]; then
		#~ LUSER='lms'
		#~ LGROUP=$(id -ng $LUSER)
		#~ error_echo "Fixing up ownership in ${LTARGETDIR} for ${LUSER}:${LGROUP}"
		#~ chown -R "${LUSER}:${LGROUP}" "$LTARGETDIR"
	if [ $LIS_ROOT -lt 1 ]; then
		error_echo "Fixing up ownership in ${LTARGETDIR} for ${LUSER}:${LGROUP}"
		chown -R "${LUSER}:${LGROUP}" "$LTARGETDIR"
	fi

	return 0
}

########################################################################
# domain_check( URL ) -- echos 0 if domain is reachable, otherwise 1
########################################################################
domain_check(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LURL="$1"
	local LHOST=$(echo "$LURL" | sed -n -e 's#^.*://\([^/]\+\)/.*$#\1#p')
	local LRET=
	[ $VERBOSE -gt 0 ] && error_echo "Checking URL ${LURL} for host ${LHOST}"
	#~ host -W 3 "$LHOST"  > /dev/null 2>&1

	LRET=$(host -W 3 "$LHOST"  2>&1 | grep -c -i "host ${LHOST} not found")
	echo "$LRET"

	[ $LRET -gt 0 ] && error_echo "${FUNCNAME} Error: ${LHOST} is not a valid domain."

	return $LRET
}


########################################################################
# script_zip_download( /scriptdirpath ) -- downloads zip files from
#     hegardtfoundation.org and unzips them to the scriptdirpath
########################################################################
script_zip_download(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LSCRIPTDIR="$1"
	local LZIPFILE="$(basename "$LSCRIPTDIR").zip"
	local LTARGETDIR="$(dirname "$LSCRIPTDIR")"
	local LZIPURL=
	local LUSER=
	local LGROUP=
	local LPASS=
	local LIS_ROOT=0
	local LTO_NULL='>/dev/null'

	[ $VERBOSE -gt 0 ] && LTO_NULL=

	if [ -z "$LSCRIPTDIR" ]; then
		error_echo "${FUNCNAME}( $@ ) target script directory name required."
		return 1
	fi

	# Get the password for the SCRIPTDIR
	# We need root for anything off /usr or /var, all else should be daadmin
	if [ $(echo "$LSCRIPTDIR" | grep -c -E '^/usr/.*|^/var/.*') -gt 0 ]; then
		LIS_ROOT=1
		LUSER='root'
		LGROUP=$(id -ng $LUSER)
		LPASS="$(pass_get_root)"
	else
		LIS_ROOT=0
		LUSER='daadmin'
		LGROUP=$(id -ng $LUSER)
		LPASS="$(pass_get_daadmin)"
	fi

	# Change to the target dir..we should NOT need to create the dir as all the zipped scripts include relative paths..
	# Cope with 'Aux' or 'binx86_64' script dirs.  Zip files for Aux dirs won't contain full relative paths..
	if [ $(echo "$LSCRIPTDIR" | grep -c 'Aux') -gt 0 ]; then
		# Aux zips should be downloaded & unzipped in the child dir.
		LTARGETDIR="$(echo "$LSCRIPTDIR" | sed -e 's#Aux##')"
		LSCRIPTDIR="$LTARGETDIR"
	elif [ $(echo "$LSCRIPTDIR" | grep -c $(uname -m)) -gt 0 ]; then
		# bin zips should be downloaded & unzipped in the parent dir.
		# e.g. LSCRIPTDIR = /usr/local/bini686 || /usr/local/binx86_64
		LSCRIPTDIR="$(echo "$LSCRIPTDIR" | sed -e "s#$(uname -m)##")"
		LTARGETDIR="$(dirname "$LSCRIPTDIR")"
	fi

	error_echo "Downloading and installing ${LZIPFILE} to ${LSCRIPTDIR}"

	if [ ! -d "$LSCRIPTDIR" ]; then
		[ $VERBOSE -gt 0 ] && error_echo "Creating directory ${LSCRIPTDIR}"
		mkdir -p "$LSCRIPTDIR"
	fi
		
	cd "$LTARGETDIR"

	if [ "$LTARGETDIR" != "$(pwd)" ]; then
		error_echo "${FUNCNAME} Error: could not change to ${LTARGETDIR}."
		return 1
	fi

	if [ ! -f "$LZIPFILE" ]; then
		USERAGENT='Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36'
		LZIPURL="http://www.hegardtfoundation.org/slimstuff/${LZIPFILE}"

		[ $VERBOSE -gt 0 ] && error_echo "Downloading ${LZIPURL} to ${LTARGETDIR}"

		if [ $(domain_check "$LZIPURL") -lt 1 ]; then
			[ $VERBOSE -gt 0 ] && wget -v -U "$USERAGENT" "$LZIPURL" || wget --quiet -U "$USERAGENT" "$LZIPURL" 
		fi

		if [ -f "$LZIPFILE" ]; then
			[ $VERBOSE -gt 0 ] && error_echo "Unzipping ${LZIPFILE}"
			[ $VERBOSE -gt 0 ] && unzip -o "$LZIPFILE" || unzip -q -o "$LZIPFILE" 
			rm "$LZIPFILE"

			[ $VERBOSE -gt 0 ] && error_echo "Making scripts executable in ${LSCRIPTDIR}.."
			[ $VERBOSE -gt 0 ] && find "$LSCRIPTDIR" -name '*.sh' -print -exec chmod 755 {} \; || find "$LSCRIPTDIR" -name '*.sh' -exec chmod 755 {} \;

			if [ $LIS_ROOT -lt 1 ]; then
				[ $VERBOSE -gt 0 ] && error_echo "Fixing up ownership in ${LSCRIPTDIR} for ${LUSER}:${LGROUP}"
				chown -R "${LUSER}:${LGROUP}" "$LSCRIPTDIR"
			fi
			
		else
			echo "${FUNCNAME} Error: Could not download ${LZIPFILE}"
		fi
	fi

	return 0
}

########################################################################
# args_clean( args ) -- removes line-feeds from an arg list
########################################################################
args_clean() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LARGS="$*"
	LARGS="$(echo "$LARGS" | sed ':a;N;$!ba;s/\n/ /g')"
	echo "$LARGS"
}

########################################################################
# scripts_get( scriptdirs ) -- arbitrates between fetching scripts from
#      scserver or downloading zipfiles from hegardtfoundation.org
########################################################################
scripts_get(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LSCRIPTDIRS="$1"

	# Replace any line-feeds with spaces..
	LSCRIPTDIRS="$(echo "$LSCRIPTDIRS" | sed ':a;N;$!ba;s/\n/ /g')"

	local LDIR=

	local LIS_SCSERVER=$(is_scserver)

	for LDIR in $LSCRIPTDIRS
	do
		if [ $LIS_SCSERVER -gt 0 ]; then
			script_dir_fetch "$LDIR"
		else
			script_zip_download "$LDIR"
		fi
	done
	
}


