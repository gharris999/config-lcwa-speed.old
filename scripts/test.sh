#!/bin/bash

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"


SCRIPT="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT")"
SCRIPTNAME=$(basename $0)

INST_LOGFILE="${SCRIPTNAME}.log"

TESTONLY=1
DEBUG=1


disp_log_msg(){
	error_echo "$@"
	error_log "$@"
}

######################################################################################################
# error_echo() -- echo a message to stderr
######################################################################################################
error_echo(){
	echo "$@" 1>&2;
}



# adapted from raspi-config
rpi_do_change_locale() {
	local LLOCALE="$1"
	local LLOCALE_LINE=
	local LLOCALE_ENCODING=
	local LCONF_FILE=
	local LLOCALE_CURRENT="$(locale | grep 'LANG=' | sed -n -e 's/^LANG=\(.*\)$/\1/p')"
	
	if [ "$LLOCALE" = "$LLOCALE_CURRENT" ]; then
		error_echo "Locale ${LLOCALE_CURRENT} already set to ${LLOCALE}"
		return 0
	fi
	
	error_echo "Attempting to change locale to ${LLOCALE}"
	
	if ! LLOCALE_LINE="$(grep -E "^${LLOCALE} " /usr/share/i18n/SUPPORTED)"; then
		error_echo "Error: Locale ${LLOCALE} is not supported."
		return 1
	fi
	
	LLOCALE_ENCODING="$(echo $LLOCALE_LINE | cut -f2 -d " ")"
	
	[ $DEBUG -gt 0 ] && error_echo "LLOCALE_ENCODING == ${LLOCALE_ENCODING}"
	
	LCONF_FILE='/etc/locale.gen'
	[ ! -f "${LCONF_FILE}.org" ] && cp -p "$LCONF_FILE" "${LCONF_FILE}.org"
	
	# Comment all non-commented lines..
	sed -i 's/^\([^#]\)/# \1/g' "$LCONF_FILE"
	cp -p "$LCONF_FILE" "${LCONF_FILE}.blip"

	# Uncomment our locale
	sed -i "s/^# ${LLOCALE} ${LLOCALE_ENCODING}/${LLOCALE} ${LLOCALE_ENCODING}/" "$LCONF_FILE"
	
	if [ $(grep -c -E "^${LLOCALE} ${LLOCALE_ENCODING}" "$LCONF_FILE") -lt 1 ]; then
		echo "$LLOCALE $LLOCALE_ENCODING" >> "$LCONF_FILE"
	fi
	
	
	LCONF_FILE='/etc/default/locale'
	[ ! -f "${LCONF_FILE}.org" ] && cp -p "$LCONF_FILE" "${LCONF_FILE}.org"
	sed -i "s/^\s*LANG=\S*/LANG=$LLOCALE/" "$LCONF_FILE"
	
	dpkg-reconfigure -f noninteractive locales

}


back_to_default(){
	
	error_echo "Restoring original locale.."
	
	LCONF_FILE='/etc/locale.gen'
	if [ -f "${LCONF_FILE}.org" ]; then
		cp -p "${LCONF_FILE}.org" "$LCONF_FILE"
	fi
	
	LCONF_FILE='/etc/default/locale'
	if [ -f "${LCONF_FILE}.org" ]; then
		cp -p "${LCONF_FILE}.org" "$LCONF_FILE"
	fi
	
	dpkg-reconfigure -f noninteractive locales

}
	

#~ rpi_locale_set(){

	if [ "$1" = "--revert" ]; then
		back_to_default
	fi
	
	#~ en_US.UTF-8 UTF-8
	rpi_do_change_locale 'en_US.UTF-8'
	
#~ }

