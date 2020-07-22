#!/bin/bash

# Script to check network status on service start.  Called from lcwa-speed.service
#
#

SCRIPT_VERSION=20200721.174126

 
INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"

SCRIPT="$(basename "$(readlink -f "$0")")"

DEBUG=0
VERBOSE=0
TEST=0
MINIMAL=0

iso_date(){
	date --iso-8601=s
}

########################################################################################
# get_links_wait( $NETDEV) Tests to see if an interface is linked. returns 0 == linked; 1 == no link;
########################################################################################
get_links_wait(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"

	local LIFACES=
	local LIFACE=
	local n=0

	# Make 6 attempts to find a link..
	for n in 1 2 3 4 5 6
	do
		LIFACES=$(ifaces_get_links)
		if [ ! -z "$LIFACES" ]; then
			break
		fi
		# No link...try to wait a bit for the network to be established..
		error_echo "$(iso_date) ${SCRIPT}: No link detected on any network interface...waiting 10 seconds to try again.."
		sleep 10
	done

	if [ ! -z "$LIFACES" ]; then
		error_echo "$(iso_date) ${SCRIPT}: ${LIFACES} has a network link."
		return 0
	fi

	# Give up..
	error_echo "$(iso_date) ${SCRIPT}: No link found on any network device. Exiting."
	return 1

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


get_links_wait

exit $?
