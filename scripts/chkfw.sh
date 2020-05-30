#!/bin/bash

# Script to check network status on boot.  Called from rc.local
#
#
 
INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"

SCRIPT="$(basename "$(readlink -f "$0")")"

DEBUG=0
VERBOSE=0
TEST=0
MINIMAL=0

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
		# Find the 1st (sorted alpha) networking interface with a good link status..
		#~ for LIFACE in $(ifaces_get)
		#~ do
			#~ #Check the link status..
			#~ iface_has_link "$LIFACE"
			#~ if [ $? -eq 0 ]; then
				#~ LIFACES="${LIFACES} ${LIFACE}"
			#~ fi
		#~ done
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
	local IP_SUBNET="$(ipaddr_subnet_get)"
	local FW_SUBNET="$(sudo ufw status | grep -m1 ALLOW | awk '{print $3}')"
	local IFACE=

	[ $VERBOSE -gt 0 ] && error_echo "${SCRIPT}: Checking firewall subnet.."

	# If there's no IP or link, don't attempt to change the firewall..
	if [ -z "$IP_SUBNET" ]; then
		IFACE="$(iface_primary_get)"
		iface_has_link "$IFACE"
		if [ $? -gt 0 ]; then
			# if there is no link (e.g. ethernet not plugged in) give up immediatly without changing anything..
			[ $VERBOSE -gt 0 ] && error_echo "Iface ${IFACE} has no ip or link."
			exit 0
		fi
	fi
	
	# Check to see if we have dhcp..
	for n in 1 2 3
	do
		if [ "$IP_SUBNET" = "127.0.0.0/8" ]; then
			[ $VERBOSE -gt 0 ] && error_echo "Waiting 3 seconds for dhcp.."
			sleep 3
			IP_SUBNET="$(ipaddr_subnet_get)"
		else
			break
		fi
	done

	if [ "$FW_SUBNET" != "$IP_SUBNET" ]; then

		[ $VERBOSE -gt 0 ] && error_echo "Iface Subnet: '${IP_SUBNET}' does not match firewall subnet: '${FW_SUBNET}'"
		[ $VERBOSE -gt 0 ] && error_echo "Reconfiguring firewall.."

		if [ $MINIMAL -gt 0 ]; then
			config-firewall.sh --minimal
		else
			config-firewall.sh
		fi
	else
		[ $VERBOSE -gt 0 ] && error_echo "Iface Subnet: '${IP_SUBNET}' matches firewall subnet: '${FW_SUBNET}'"
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
# Get cmd line args..

# Process cmd line args..
SHORTARGS='hdvqmt'
LONGARGS='help,debug,verbose,quiet,minimal,test,notest'
ARGS=$(getopt -o "$SHORTARGS" -l "$LONGARGS"  -n "$(basename $0)" -- "$@")

eval set -- "$ARGS"

while [ $# -gt 0 ]; do
	case "$1" in
		--)
			;;
		-h|--help)
			echo "Syntax: $(basename "$0") [--debug] [--test] [--verbose] [--quiet]"
			exit 0
			;;
		-d|--debug)
			DEBUG=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --debug"
			;;
		-v|--verbose)
			VERBOSE=1
			;;
		-q|--quiet)
			VERBOSE=0
			;;
		-m|--minimal)
			MINIMAL=1
			;;
		-t|--test)
			TEST=1
			;;
		--notest)
			TEST=0
			;;
		*)
			error_echo "${SCRIPT}: Unknown arg ${1}"
			;;
	esac
	shift
done


firewall_subnet_check

exit 0
