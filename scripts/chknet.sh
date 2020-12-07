#!/bin/bash

SCRIPT_VERSION=20201206.201123

# Script to check network status on boot.  Called from rc.local
# Version 20200430.01
#

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"

SCRIPT="$(basename "$(readlink -f "$0")")"
INST_LOGFILE="/var/log/${SCRIPT}.log"

DEBUG=0
VERBOSE=0
TEST=0
FORCE=0
MINIMAL=0
PUBLIC=0

#~ IS_FEDORA="$(which firewall-cmd 2>/dev/null | wc -l)"
#~ IS_NETPLAN="$(which netplan 2>/dev/null | wc -l)"

# Dependencies: fping, dhcping, installed via config-network.sh

# Assume fping
PING_BIN="$(which fping)"
PING_OPTS='-q -e -r 1 -t 150'
TRUE_BIN="$(which true)"

if [ -z "$PING_BIN" ]; then
	PING_BIN="$(which ping)"
	PING_OPTS='-c 1 -w 5'
fi

DEFAULT_SUBNETS='192.168.1.1 192.168.0.1 10.0.1.1 10.0.0.1 192.168.1.1'
NETDEVS=
NETLINKS=
NETDEV0=
NETDEV1=
IFACE=
IFACES=
CONFIG_NETWORK_OPTS=


log_msg(){
	error_echo "$@"
	error_log "$@"
}


########################################################################################
# get_links_wait( $NETDEV) Tests to see if an interface is linked. returns 0 == linked; 1 == no link;
########################################################################################
get_links_wait(){
	[ $DEBUG -gt 0 ] && log_msg "${FUNCNAME}( $@ )"

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
		[ $VERBOSE -gt 0 ] && log_msg "No link detected on any network interface...waiting 10 seconds to try again.."
		sleep 10
	done

	if [ ! -z "$LIFACES" ]; then
		echo "$LIFACES"
		return 0
	fi

	# Give up..
	log_msg "No link found on any network device.."
	return 1

}


####################################################################################
# ping_wait()  See if an IP is reachable via ping..
####################################################################################
ping_wait(){
	[ $DEBUG -gt 0 ] && log_msg "${FUNCNAME}( $@ )"

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
				log_msg "${LIP_ADDR} is not ready.."
			fi
			sleep 1
		else
			if [ $VERBOSE -gt 2 ]; then
				log_msg "${LIP_ADDR} is ready.."
			fi
			return 0
		fi
	done

	return 1
}


####################################################################################
# iface_gateway_ping()  Ping the gateway for an interface..
####################################################################################
iface_gateway_ping(){
	[ $DEBUG -gt 0 ] && log_msg "${FUNCNAME}( $@ )"

	local LIFACE="$1"
	local LGATEWAY="$(iface_gateway_get "$LIFACE")"
	local RET=1

	if [ -z "$LGATEWAY" ]; then
		return 1
	fi
	ping_wait "$LGATEWAY" 5
	RET=$?
	echo "$LGATEWAY"
	return $RET
}


####################################################################################
# iface_dhcpsrvr_get()  Get the address of a dhcp server for a linked interface..
####################################################################################
iface_dhcpsrvr_get(){
	[ $DEBUG -gt 0 ] && log_msg "${FUNCNAME}( $@ )"

	local LIFACE="$1"
	local LIFACE_MAC="$(iface_hwaddress_get "$LIFACE")"
	local LSUBNET=
	local LDHCPING=
	local LDHCP_SERVER=


	# Fedora: to allow dhcping to work, we need to temporarily open ports 67-68/udp in the firewall public zone..
	if [ $IS_FEDORA -gt 0 ]; then
		firewall-cmd --zone=public --add-port=67-68/udp >/dev/null 2>&1
	else
		ufw disable >/dev/null 2>&1
	fi

	for LSUBNET in '255.255.255.255' $DEFAULT_SUBNETS
	do
		[ $VERBOSE -gt 0 ] && log_msg "Attempting to get subnet info for ${LIFACE} via dhcping -h ${LIFACE_MAC} -s ${LSUBNET}"

		if [ $DEBUG -gt 0 ]; then
			error_echo dhcping -h "$LIFACE_MAC" -s "$LSUBNET" 1>&2
			dhcping -h "$LIFACE_MAC" -s "$LSUBNET" 1>&2
		fi

		LDHCPING=$(dhcping -h "$LIFACE_MAC" -s "$LSUBNET" 2>&1)

		[ $VERBOSE -gt 0 ] && log_msg "dhcping returned [${LDHCPING}]"

		if [ $(echo "$LDHCPING" | grep -c 'received from\|Got answer from') -gt 0 ]; then

			LDHCPING="$(echo "$LDHCPING" | grep -m1 'received from\|Got answer from')"

			#~ LDHCP_SERVER="$(echo "$LDHCPING" | sed -n -e 's/^received from \([[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\).*$/\1/p')"
			LDHCP_SERVER="$(echo "$LDHCPING" | sed -n -e 's/^[^0-9]*\([[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\.[[:digit:]]\{1,3\}\).*$/\1/p')"
			if [ ! -z "$LDHCP_SERVER" ]; then
				log_msg "dhcp server found at ${LDHCP_SERVER}."
				echo "$LDHCP_SERVER"
				return 0
			else
				log_msg "Could not extract IP address from [${LDHCPING}]."
			fi
		fi

	done

	log_msg "No dhcp server found."
	echo ""
	return 1
}

firewall_subnet_check(){
	local LIFACE="$1"
	local IP_SUBNET="$(iface_subnet_get "$LIFACE")"
	local FW_SUBNETS="$(sudo ufw status | grep ALLOW | awk '{print $3}' | sort | uniq | xargs)"
	local FW_SUBNET=
	local IFACE=

	[ $VERBOSE -gt 0 ] && log_msg "${SCRIPT}: Checking firewall subnet against ${LIFACE} ${IP_SUBNET}.."

	# If there's no IP or link, don't attempt to change the firewall..
	if [ -z "$IP_SUBNET" ]; then
		IFACE="$(iface_primary_get)"
		iface_has_link "$LIFACE"
		[ $VERBOSE -gt 0 ] && log_msg "Iface ${LIFACE} has no ip or link."
		exit 0
	fi

	for FW_SUBNET in $FW_SUBNETS
	do
		if [ "$FW_SUBNET" = "$IP_SUBNET" ]; then
			[ $VERBOSE -gt 0 ] && log_msg "Iface ${LIFACE} Subnet: '${IP_SUBNET}' matches firewall subnet: '${FW_SUBNET}'"
			return 0
		fi
	done

	[ $VERBOSE -gt 0 ] && log_msg "Iface ${LIFACE} Subnet: '${IP_SUBNET}' does not match firewall subnet: '${FW_SUBNET}'"
	[ $VERBOSE -gt 0 ] && log_msg "Reconfiguring firewall.."

	if [ $MINIMAL -gt 0 ]; then
		[ $TEST -lt 1 ] && config-firewall.sh --minimal
	else
		[ $TEST -lt 1 ] && config-firewall.sh
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
SHORTARGS='hdvt'
LONGARGS='help,debug,verbose,quiet,force,minimal,public,test,notest'
ARGS=$(getopt -o "$SHORTARGS" -l "$LONGARGS"  -n "$(basename $0)" -- "$@")

eval set -- "$ARGS"

while [ $# -gt 0 ]; do
	case "$1" in
		--)
			;;
		--help)
			disp_help
			exit 0
			;;
		--debug)
			DEBUG=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --debug"
			;;
		--verbose)
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --verbose"
			VERBOSE=1
			;;
		--quiet)
			VERBOSE=0
			;;
		--force)
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --force"
			FORCE=1
			;;
		--minimal)
			MINIMAL=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --minimal"
			;;
		--public)
			PUBLIC=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --public"
			;;
		--test)
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --test"
			TEST=1
			;;
		--notest)
			TEST=0
			;;
		*)
			log_msg "${SCRIPT}: Unknown arg ${1}"
			;;
	esac
	shift
done


#~ [ $DEBUG -gt 0 ] && log_msg "${SCRIPT} $@  -- line ${LINENO}"
[ $VERBOSE -gt 0 ] && log_msg "################################################################################################################################"
[ $VERBOSE -gt 0 ] && log_msg "${SCRIPT}: Checking network connectivity.."

# Checknet workflow:

# Optional primary interface from command line..

# Get linked interfaces
NETLINKS="$(ifaces_get_links)"

# If no link(s), wait awhile, try harder
if [ -z "$NETLINKS" ]; then
	NETLINKS=$(get_links_wait)
	# If no links, give up, quit
	if [ $? -gt 0 ]; then
		log_msg "No network links on any interface.  Exiting."
		exit 0
	fi
fi

[ $VERBOSE -gt 0 ] && log_msg "Interface(s) ${NETLINKS} have links.."

##################################################################################################
# if links, try to ping gateway..
for NETDEV in $NETLINKS
do
	GATEWAY="$(iface_gateway_ping "$NETDEV")"
	# If pinged gateway, net is good, quit..
	if [ $? -eq 0 ]; then
		[ $VERBOSE -gt 0 ] && log_msg "Gateway ${GATEWAY} responds to ping from ${NETDEV}, so network is OK.."

		# Check that the firewall is on the correct subnet..
		firewall_subnet_check "$NETDEV"

		exit 0
	else
		[ $VERBOSE -gt 0 ] && log_msg "No ping response to ${NETDEV} from gateway ${GATEWAY}.."
	fi
done

##################################################################################################
# Can't ping gateway, so try dhcping to find the subnet..
# (This will fail for statically configured netdevs without a gateway setting..
for NETDEV in $NETLINKS
do
	# Try to get the subnet via dhcp_ping
	DHCP_SERVER="$(iface_dhcpsrvr_get "$NETDEV")"

	# If dhcp server found, reconfigure network for this netdev for ther dhcp server's subnet..
	if [ ! -z "$DHCP_SERVER" ]; then
		OLD_IP="$(iface_ipaddress_get "$NETDEV")"
		NEW_IP="${DHCP_SERVER%.*}.$(default_octet_get)"

		[ $VERBOSE -gt 0 ] && log_msg "================================================================================================================================"
		[ $VERBOSE -gt 0 ] && log_msg "Reconfiguring static network address for ${NETDEV} from ${OLD_IP} to ${NEW_IP} suggested by dhcp server ${DHCP_SERVER}.."
		[ $VERBOSE -gt 0 ] && log_msg "/usr/local/sbin/config-network.sh --testping --quiet --primary-only \"--iface0=${NETDEV}\" \"--ip0=${NEW_IP}" 2>&1 | tee -a "$INST_LOGFILE"
		if [ $TEST -lt 1 ] || [ $FORCE -gt 0 ]; then
			/usr/local/sbin/config-network.sh --testping --quiet $CONFIG_NETWORK_OPTS --primary-only "--iface0=${NETDEV}" "--ip0=${NEW_IP}"
		else
			echo /usr/local/sbin/config-network.sh --testping --quiet $CONFIG_NETWORK_OPTS --primary-only "--iface0=${NETDEV}" "--ip0=${NEW_IP}"
		fi

		if [ $? -eq 0 ]; then
			[ $VERBOSE -gt 0 ] && log_msg "Reconfiguration successful."
			exit 0
		fi
	else
		[ $VERBOSE -gt 0 ] && log_msg "No dhcp server found for ${NETDEV}.."
	fi

done



##################################################################################################
# Ok, then try to reconfigure the network to all the default subnets..

for NETDEV in $NETLINKS
do
	for NEW_SUBNET in $DEFAULT_SUBNETS
	do
		OLD_IP="$(iface_ipaddress_get "$NETDEV")"
		NEW_IP="${NEW_SUBNET%.*}.$(default_octet_get)"

		if [ "$NEW_IP" != "$OLD_IP" ]; then
		[ $VERBOSE -gt 0 ] && log_msg "================================================================================================================================"
			[ $VERBOSE -gt 0 ] && log_msg "Attempting reconfigure of static network address for ${NETDEV} from ${OLD_IP} to ${NEW_IP} on default subnet ${NEW_SUBNET}.."
			[ $VERBOSE -gt 0 ] && log_msg "/usr/local/sbin/config-network.sh --testping --quiet --primary-only ${CONFIG_NETWORK_OPTS} \"--iface==${NETDEV}\" \"--addr=${NEW_IP}" | tee -a "$INST_LOGFILE"
				if [ $TEST -lt 1 ] || [ $FORCE -gt 0 ]; then
					/usr/local/sbin/config-network.sh --testping --quiet $CONFIG_NETWORK_OPTS --primary-only $CONFIG_NETWORK_OPTS "--iface=${NETDEV}" "--addr=${NEW_IP}"
				else
					echo /usr/local/sbin/config-network.sh --testping --quiet $CONFIG_NETWORK_OPTS --primary-only $CONFIG_NETWORK_OPTS "--iface=${NETDEV}" "--addr=${NEW_IP}"
				fi

			if [ $? -eq 0 ]; then
				[ $VERBOSE -gt 0 ] && log_msg "Network reconfiguration of ${NETDEV} to ${NEW_IP} SUCCESSFUL."
				exit 0
			else
				[ $VERBOSE -gt 0 ] && log_msg "UNSUCCESSFUL reconfigure of static network address on ${NETDEV} from ${OLD_IP} to ${NEW_IP} on default subnet ${NEW_SUBNET}.."
			fi
		fi
	done
done

[ $VERBOSE -gt 0 ] && log_msg "Network reconfiguration unsuccessful."
exit 0
