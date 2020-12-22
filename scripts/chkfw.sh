#!/bin/bash

SCRIPT_VERSION=20201221.223518

# Script to check ufw firewall status on boot.  Called from rc.local.
#		If our current subnet does not match the subnet in the firewall, 
#		then reconfigure the firewall...

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"

SCRIPT="$(basename "$(readlink -f "$0")")"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
INST_LOGFILE="/var/log/${SCRIPT}.log"

DEBUG=0
VERBOSE=0
FORCE=0
TEST=0
MINIMAL=0
PUBLIC=0
CONFIG_NETWORK_OPTS=


######################################################################################################
# error_echo() -- echo a message to stderr
######################################################################################################
error_echo(){
	echo "$@" 1>&2;
}

error_log(){
	echo "${SCRIPT} $(timestamp_get_iso8601) " "$@" >>"$INST_LOGFILE"
}

log_msg(){
	error_echo "$@"
	error_log "$@"
}


########################################################################################
# get_links_wait( $NETDEV) Tests to see if an interface is linked. returns 0 == linked; 1 == no link;
########################################################################################
get_links_wait(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"

	local LIFACES=
	local LIFACE=
	local n=0

	# Make 5 attempts to find a link..
	for n in 1 2 3 4 5
	do
		LIFACES=$(ifaces_get_links)
		if [ ! -z "$LIFACES" ]; then
			break
		fi
		# No link...try to wait a bit for the network to be established..
		[ $VERBOSE -gt 0 ] && error_echo "No link detected on any network interface...waiting 10 seconds to try again.."
		sleep 10
	done

	if [ ! -z "$LIFACES" ]; then
		echo "$LIFACES"
		return 0
	fi

	# Give up..
	error_echo "No link found on any network device.."
	return 1

}


trim(){
	local LVALUE="$1"
	LVALUE="${LVALUE##*( )}"
	LVALUE="${LVALUE%%*( )}"

	echo $LVALUE

}

firewall_subnet_check(){
	local LFW_SUBNETS="$(ufw status | grep ALLOW | awk '{print $3}' | sort --unique | xargs)"
	local LFW_SUBNET=
	local LNEEDS_FWRECONFIG=0
	local LIFACE="$(iface_primary_getb)"
	local LSUBNET="$(iface_subnet_get "$LIFACE")"

	# If there's no IP or link, don't attempt to change the firewall..
	if [ -z "$LSUBNET" ]; then
		LIFACE="$(iface_primary_get)"
		iface_has_link "$LIFACE"
		if [ $? -gt 0 ]; then
			# if there is no link (e.g. ethernet not plugged in) give up immediatly without changing anything..
			[ $VERBOSE -gt 0 ] && error_echo "Iface ${LIFACE} has no ip or link."
			exit 0
		fi
	fi

	# Try waiting 3 seconds three times to see if we get a dhcp lease..
	for n in 1 2 3
	do
		if [ "$IP_SUBNET" = "127.0.0.0/8" ]; then
			[ $VERBOSE -gt 0 ] && error_echo "Waiting 3 seconds for dhcp.."
			sleep 3
			#~ LSUBNET="$(ipaddr_subnet_get)"
			LSUBNET="$(iface_subnet_get "$LIFACE")"
		else
			break
		fi
	done
	
	[ $VERBOSE -gt 0 ] && error_echo "${SCRIPT}: Checking firewall subnet against ${LIFACE} ${LSUBNET}.."

	for LFW_SUBNET in $LFW_SUBNETS
	do
		if [ "$LFW_SUBNET" = "$LSUBNET" ] || [ "$LFW_SUBNET" = 'Anywhere' ]; then
			[ $VERBOSE -gt 0 ] && error_echo "Iface ${LIFACE} Subnet: '${LSUBNET}' matches firewall subnet: '${LFW_SUBNET}'"
			#~ return 0
		else
			[ $VERBOSE -gt 0 ] && error_echo "Iface ${LIFACE} Subnet: '${LSUBNET}' does not match firewall subnet: '${LFW_SUBNET}'"
			LNEEDS_FWRECONFIG=1
		fi
	done

	if [ $LNEEDS_FWRECONFIG -gt 0 ];  then
		[ $QUIET -lt 1 ] && error_echo "Reconfiguring firewall: ${SCRIPT_DIR}/config-firewall.sh ${CONFIG_NETWORK_OPTS}"
		"${SCRIPT_DIR}/config-firewall.sh" $CONFIG_NETWORK_OPTS
	fi

}


####################################################################################################
####################################################################################################
####################################################################################################
####################################################################################################
# main()
####################################################################################################
####################################################################################################
####################################################################################################
####################################################################################################

error_echo '===================================================================='
error_echo "${SCRIPT_DIR}/${SCRIPT} ${@}"
error_echo '===================================================================='

# Get cmd line args..

# Process cmd line args..
SHORTARGS='hdvqmpt'
LONGARGS='help,debug,verbose,quiet,force,minimal,public,test,notest'
ARGS=$(getopt -o "$SHORTARGS" -l "$LONGARGS"  -n "$(basename $0)" -- "$@")

eval set -- "$ARGS"

while [ $# -gt 0 ]; do
	case "$1" in
		--)
			;;
		-h|--help)
			disp_help
			#echo "Syntax: $(basename "$0") [--debug] [--test] [--verbose] [--quiet] [--minimal]"
			exit 0
			;;
		--debug)
			DEBUG=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --debug"
			;;
		--verbose)
			VERBOSE=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --verbose"
			;;
		--quiet)
			QUIET=1
			VERBOSE=0
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --quiet"
			;;
		--force)
			FORCE=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --force"
			;;
		-t|--test)
			TEST=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --test"
			;;
		--notest)
			TEST=0
			;;
		-m|--minimal)
			MINIMAL=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --minimal"
			;;
		-p|--public)
			PUBLIC=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --public"
			;;
		*)
			error_echo "${SCRIPT}: Unknown arg ${1}"
			;;
	esac
	shift
done

firewall_subnet_check

exit 0
