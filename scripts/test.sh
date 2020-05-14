#!/bin/bash

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"


TESTONLY=1
DEBUG=1

# Fixup hostname, /etc/hostname & /etc/hosts with new hostname
hostname_fix(){
	local LOLDHOSTNAME="$1"
	local LNEWHOSTNAME="$2"
	
	local LCONFFILE='/etc/hostname'
	local LHOSTSFILE='/etc/hosts'
	
	if [ ! -z "$(which hostnamectl)" ]; then
		error_echo "Changing hostname from ${LOLDHOSTNAME} to ${LNEWHOSTNAME}.."
		hostnamectl set-hostname "$LNEWHOSTNAME"
	fi

	if [ -f "$LCONFFILE" ]; then
		error_echo "Fixing up ${LCONFFILE} with changed hostname ${LNEWHOSTNAME}.."
		[ ! -f "${LCONFFILE}.org" ] && cp "$LCONFFILE" "${LCONFFILE}.org"
		cp "$LCONFFILE" "${LCONFFILE}.bak"
		sed -i "s/$LOLDHOSTNAME/$LNEWHOSTNAME/g" "$LCONFFILE"
		grep -i "$LNEWHOSTNAME" "$LCONFFILE"
	fi
	
	if [ -f "$LHOSTSFILE" ]; then
		error_echo "Fixing up ${LHOSTSFILE} with changed hostname ${LNEWHOSTNAME}.."
		[ ! -f "${LHOSTSFILE}.org" ] && cp "$LHOSTSFILE" "${LHOSTSFILE}.org"
		cp "$LHOSTSFILE" "${LHOSTSFILE}.bak"
		sed -i "s/$LOLDHOSTNAME/$LNEWHOSTNAME/g" "$LHOSTSFILE"
		grep -i "$LNEWHOSTNAME" "$LHOSTSFILE"
	fi
	
}

hostname_check(){
	local LOLDNAME="$(hostname)"
	local LNEWNAME=

	# If hostname begins with 'lcnn', make LCnn
	if [ "$(hostname | grep -c -E '^lc[0-9]{2}.*$')" -gt 0 ]; then
		LNEWNAME="$(hostname | sed -e 's/^lc/LC/')"
		hostname_fix "$LOLDNAME" "$LNEWNAME"
		return 0
	fi

	# If the current hostname doesn't conform to our specs, prompt for a new hostname
	[ "$(hostname | grep -c -E '^LC[0-9]{2}.*$')" -lt 1 ] && error_echo "WARNING: The hostname of this system does not begin with 'LCnn'."
	while [ "$(hostname | grep -c -E '^LC[0-9]{2}.*$')" -lt 1 ]
	do	
		error_echo ' '
		error_echo " Please enter a new hostname:"
		read LNEWNAME
		if [ "$(echo "$LNEWNAME" | grep -c -E '^LC[0-9]{2}.*$')" -gt 0 ]; then
			hostname_fix "$LOLDNAME" "$LNEWNAME"
		else
			error_echo "Error: ${LNEWNAME} is not a valid LCnn----- hostname."
		fi
	done
	[ "$(hostname | grep -c -E '^LC[0-9]{2}.*$')" -lt 1 ] && error_echo "WARNING: The hostname of this system needs to be changed using hostnamectl set-hostname."
}

hostname_check
