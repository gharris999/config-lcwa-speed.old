#!/bin/bash

SCRIPT_VERSION=20201220.110638

# Bash script to configure firewall.

# Todo: 
#	
#  If devname is passed as arg and there are multiple interfaces, make sure to at least open
#    the other devs for ssh & scp & 
#  Check processing of cmdline args -- ip addresses / dev names.........done
#  Now test this..
#  Allow for opening a port range (necessary for LMS castbridge plugin
#    See: https://forums.slimdevices.com/showthread.php?104614-Announce-CastBridge-integrate-Chromecast-players-with-LMS-(squeeze2cast)&p=835640&viewfull=1#post835640
#
#	The Bridge installs a web server on a random port from 49152 (can be configured), up to 32 ports, 
#	so your firewall must allow that. If everything seems to work but you have no sound, you propably 
#	have these ports blocked to the Chromcast player cannot get the audio. In Windows, add a rule 
#	authorizing squeeze2cast-win.exe or go into C:\ProgramData\Squeezebox\Cache\InstalledPlugins\Plugins\CastBridge 
#	and launch *once* squeezecast-win.exe where you'll be prompted for authorization

#   So: 32 port range: 49152-49183

#  Modify config-network.sh to optionall allow passing only one device
#    name to config-firewall.sh
#  For Ubuntu, make use of /etc/ufw/applications.d app files?
#
#
#

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"

SCRIPT="$(basename "$(readlink -f "$0")")"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
INST_NAME="${SCRIPT%%.*}"
INST_LOGFILE="/var/log/${SCRIPT}.log"


is_root

DEBUG=0
VERBOSE=0
ADD=0
REMOVE=0
CONFIG_NETWORK_OPTS=

MINIMAL=0
FORCE=0
TEST=0
MAKE_PUBLIC=0
NO_FAILSAFE=0
IP_ADDRESSES=
IF_DEVS=
SERVICES=

PROT=
PORT=
PORTPROT=
PARAMs=
IP_ADDRESSES=
IF_DEVS=

#------------------------------------------------------------------------------
# UDP ports to open for ALL interfaces
#------------------------------------------------------------------------------
#67		BOOTP/DHCP server
#68		BOOTP/DHCP client
#~ UDP_FAILSAFE_PORTS=(67 68)
UDP_FAILSAFE_PORTS=

#------------------------------------------------------------------------------
# UDP ports to open
#------------------------------------------------------------------------------
#137 	NetBIOS name
#138	NetBIOS datagram
#1900	UPnP discovery
#3483	SlimDiscovery
#5201	iperf3 server port
##17784	Net UDAP

#~ UDP_PORTS=(\
#~ 67 \
#~ 68 \
#~ 137 \
#~ 138 \
#~ 1900 \
#~ 3483 \
#~ 5201 \
#~ 17784 \
#~ )
#~ UDP_PORTS=(137 138 1900 3483)
UDP_PORTS=


#------------------------------------------------------------------------------
# TCP ports to open for ALL interfaces
#------------------------------------------------------------------------------
#22			SSH
#~ TCP_FAILSAFE_PORTS=(22)
TCP_FAILSAFE_PORTS=

#------------------------------------------------------------------------------
# TCP ports to open
#------------------------------------------------------------------------------
#80			HTTP
#139		NetBIOS Session Service
#445		SMB file sharing via samba
#548		Apple fire sharing via netatalk
#873		rsyncd daemon service
#3003		x10cmdr service
#3306		MySQL
#3483		SlimProto protocol
#5201		iperf3 server port
#5353		avahi-daemon service
#8080   	HTTP
#8200		DLNA http
#9000		SlimHTTP
##9005		Trioode Spotify LMS Plugin helper app port
#9090		SlimCLI
#9092		SlimMySQL
#10000		webmin
#49152-49183 castbridge

#~ TCP_PORTS=(\
#~ 22 \
#~ 67 \
#~ 68 \
#~ 80 \
#~ 139 \
#~ 445 \
#~ 548 \
#~ 873 \
#~ 3003 \
#~ 3306 \
#~ 3483 \
#~ 5201 \
#~ 5353 \firewall_app_info
#~ 8080 \
#~ 8200 \
#~ 9000 \
#~ 9090 \
#~ 9092 \
#~ 10000 \
#~ 49152-49183 \
#~ )
#~ TCP_PORTS=(80 139 445 873 3003 3483 5353 8080 8200 9000 9090 49152-49183)
TCP_PORTS=



# The /etc/default/config-firewall file overrides our default UDP and TCP port settings..
#   e.g. for the unifi-box

if [ $IS_DEBIAN -gt 0 ]; then
	CONF_FILE="/etc/default/${INST_NAME}"
else
	CONF_FILE="/etc/sysconfig/${INST_NAME}"
fi

if [ -f "$CONF_FILE" ]; then
	. "$CONF_FILE"
fi


########################################################################################
# firewall_check() Returns 1 if ufw or firewall-cmd is present on the system
########################################################################################
config_firewall_check(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	if [ $USE_FIREWALLD -gt 0 ]; then
		return 1
	elif [ $USE_UFW -gt 0 ]; then
		return 1
	fi
	return 0
}

config_firewall_disable(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	error_echo "Disabling firewall.."
	if [ $USE_FIREWALLD -gt 0 ]; then
		systemctl disable firewalld
		systemctl stop firewalld
	elif [ $USE_UFW -gt 0 ]; then
		ufw disable >/dev/null
	fi
}

config_firewall_enable(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	error_echo "Enabling firewall.."
	if [ $USE_FIREWALLD -gt 0 ]; then
		systemctl enable firewalld
		systemctl restart firewalld
		return 0
	elif [ $USE_UFW -gt 0 ]; then
		echo y | ufw enable >/dev/null
	fi
}

config_firewall_reload(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	error_echo "Reloading firewall.."
	if [ $USE_FIREWALLD -gt 0 ]; then
		firewall-cmd --reload >/dev/null
	elif [ $USE_UFW -gt 0 ]; then
		ufw reload >/dev/null
	fi
}

config_firewall_status_show(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LPUBLIC=${1:-0}
	if [ $USE_FIREWALLD -gt 0 ]; then
		firewall-cmd --reload >/dev/null
		[ $LPUBLIC -gt 0 ] && firewall-cmd --list-all-zones || firewall-cmd --list-all
	else
		ufw reload >/dev/null
		ufw status verbose
	fi
}

firewall_cmd_clear_all(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LFORCE="$2:-0"
	local LFWZONE=
	local LPORTS=
	local LPORT=
	local LPROT=
	local LZONE=
	local LAPP_NAME=

	[ $QUIET -lt 1 ] && error_echo "Removing firewall rules for all ports on ${LIFACE}"

	# Will get the default zone if there's no zone tied to the LIFACE..
	LFWZONE="$(iface_firewall_zone_get "$LIFACE")"

	LPORTS=$(firewall-cmd "--zone=${LFWZONE}" --list-ports)
	for LPORT in $LPORTS
	do
		LPROT=$(basename $LPORT)
		LPORT=$(dirname $LPORT)
		[ $QUIET -lt 1 ] && error_echo "Closing ${LPORT}/${LPROT} in zone ${LFWZONE}"
		[ $TEST -lt 1 ] && firewall-cmd --zone=${LFWZONE} --remove-port=${LPORT}/${LPROT} --permanent
	done

	# Close all services too?
	if [ $LFORCE -gt 0 ]; then
		for LZONE in $(firewall-cmd --get-zones)
		do 
			for LAPP_NAME in $(firewall-cmd --zone=${LZONE} --list-services)
			do
				[ -z "$LAPP_NAME" ] && continue
				[ $QUIET -lt 1 ] && error_echo "Closing ${LAPP_NAME} in zone ${LZONE}"
				[ $TEST -lt 1 ] && firewall-cmd --zone=${LZONE} --remove-service=${LAPP_NAME} --permanent 
			done
		done
	fi

}

########################################################################################
# config_firewall_default_set() Resets the system firewall to all incoming ports closed
########################################################################################
config_firewall_default_set(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE=$(iface_primary_getb)
	local LSUBNET=$(iface_subnet_get "$LIFACE")
	local LFWZONE=
	[ $QUIET -lt 1 ] && error_echo "Setting firewall to defaults.."
	if [ $USE_FIREWALLD -gt 0 ]; then
		# Just remove all files from /etc/firewalld/zones & reload & restart firewalld?
		# See: https://bugzilla.redhat.com/show_bug.cgi?id=1531545

		#~ cp /etc/firewalld/firewalld.conf /etc/firewalld/firewalld.conf.bak
		#~ rm -f /etc/firewalld/firewalld.conf

		[ $TEST -lt 1 ] && rm -rf  /etc/firewalld/zones/*
		[ $TEST -lt 1 ] && firewall-cmd --reload
		
		LFWZONE='public'
		[ $QUIET -lt 1 ] && error_echo "Adding interface ${LIFACE} to zone ${LFWZONE}.."
		[ $TEST -lt 1 ] && firewall-cmd --permanent --zone=${LFWZONE} --add-interface=${LFWZONE} >/dev/null
		
		LFWZONE="$(firewall-cmd --get-default-zone)"
		[ $QUIET -lt 1 ] && error_echo "Adding source ${LSUBNET} to zone ${LFWZONE}.."
		[ $TEST -lt 1 ] && firewall-cmd --zone=${LFWZONE} --change-source=${LSUBNET} --permanent >/dev/null

		#~ firewall-cmd --complete-reload
	elif [ $USE_UFW -gt 0 ]; then
		[ $TEST -lt 1 ] && config_firewall_disable
		[ $TEST -lt 1 ] && ufw --force reset >/dev/null
		[ $TEST -lt 1 ] && ufw default deny incoming >/dev/null
		[ $TEST -lt 1 ] && ufw default allow outgoing >/dev/null
	fi
	[ $TEST -lt 1 ] && config_firewall_enable

}


########################################################################################
# config_firewall_services() -- make sure every interface at least has 
#										 bootpc & ssh open..
########################################################################################

config_firewall_services(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LPARAMS="$1"
	local LSERVICE=
	
	# Always open the firewall for the dhcp client and for ssh..
	for LSERVICE in bootpc ssh
	do
		[ $QUIET -lt 1 ] && error_echo "Opening ${LPARAMS} for ${LSERVICE%.*}"
		[ $TEST -lt 1 ] && firewall_service_open "$LSERVICE" "$LPARAMS"
	done
	
}

########################################################################################
# config_firewall_apps ( szServices_List, bPublic ) -- check to see if a running
#		service has a app/service profile associated and open it.
########################################################################################

config_firewall_apps() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LSERVICES="$1"
	local LPARAMS="$2"
	local LSERVICE=
	
	for LSERVICE in $LSERVICES
	do
		if ( service_is_enabled "$LSERVICE" ); then
		
			if ( ! firewall_app_exists "${LSERVICE%.*}" ); then
				[ $QUIET -lt 1 ] && error_echo "Calling " ${SCRIPT_DIR}/config-firewall-prep-apps.sh --prep-only "$LSERVICE"
				"${SCRIPT_DIR}/config-firewall-prep-apps.sh" --prep-only "$LSERVICE"
			fi
		
			# Exception for squeezelite if lms is enabled since lms already opens SlimDiscovery & SlimProto
			if [ "${LSERVICE%.*}" = 'squeezelite' ] && ( service_is_enabled 'lms' ); then
				continue
			fi
		
			[ $QUIET -lt 1 ] && error_echo "Opening ${LPARAMS} for ${LSERVICE%.*}"
			[ $TEST -lt 1 ] && firewall_app_open "${LSERVICE%.*}" "$LPARAMS"
		fi
	done

}

config_firewall_ports() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LPARAMS="$1"
	local LPARAM=
	local LPORT=
	local LPROT=

	#~ for PORT in ${!UDP_PORTS[*]};
	LPROT='udp'
	for LPORT in "${UDP_PORTS[@]}"
	do
		[ -z "$LPORT" ] && continue
		[ $QUIET -lt 1 ] && error_echo "Opening ${LPORT}/${LPROT} on ${LPARAMS}"
		[ $TEST -lt 1 ] && firewall_port_open "udp" "$LPORT" "$LPARAMS"
	done

	#~ for PORT in ${!TCP_PORTS[*]};
	LPROT='tcp'
	for LPORT in "${TCP_PORTS[@]}"
	do
		[ -z "$LPORT" ] && continue
		[ $QUIET -lt 1 ] && error_echo "Opening ${LPORT}/${LPROT} on ${LPARAMS}"
		[ $TEST -lt 1 ] && firewall_port_open "tcp" "$LPORT" "$LPARAMS"
	done
	
	
	return 0
}


config_firewall_iface_ports_open(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIFACE="$1"
	local LPORT=
	local LPROT=
	local LIPADDR=

	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"


	LIPADDR="$(iface_ipaddress_get "$LIFACE")"

	#~ ifconfig "$LIFACE" >/dev/null 2>&1

	ipaddress_validate "$LIPADDR"

	if [ $? -lt 1 ]; then
		error_echo "Configuring firewall for ${LIFACE}"
	else
		error_echo "Not configuring firewall for ${LIFACE}. No interface information."
		return 1
	fi

	LPROT='udp'
	for LPORT in "${UDP_PORTS[@]}"
	do
		[ -z "$LPORT" ] && continue
		[ $QUIET -lt 1 ] && error_echo "Opening ${LPORT}/${LPROT} on ${LIFACE}"
		[ $TEST -lt 1 ] && iface_firewall_port_open "$LIFACE" "udp" "$LPORT"
	done

	LPROT='tcp'
	for LPORT in "${TCP_PORTS[@]}"
	do
		[ -z "$LPORT" ] && continue
		[ $QUIET -lt 1 ] && error_echo "Opening ${LPORT}/${LPROT} on ${LIFACE}"
		[ $TEST -lt 1 ] && iface_firewall_port_open "$LIFACE" "tcp" "$LPORT"
	done

	return 0
}


########################################################################################
#
# Open ports for an ip address..
#
########################################################################################

config_firewall_ipaddr_ports_open(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LIPADDR="$1"
	local LPORT=
	local LPROT=
	
	ipaddress_validate "$LIPADDR"

	if [ $? -lt 1 ]; then
		error_echo "Configuring firewall for ${LIPADDR}"
	else
		error_echo "Not configuring firewall for ${LIPADDR}. Bad IP Address."
		return 1
	fi

	#~ for PORT in ${!UDP_PORTS[*]};
	LPROT='udp'
	for LPORT in "${UDP_PORTS[@]}"
	do
		[ -z "$LPORT" ] && continue
		[ $QUIET -lt 1 ] && error_echo "Opening ${LPORT}/${LPROT} on ${LIPADDR}"
		[ $TEST -lt 1 ] && ipaddr_firewall_port_open "$LIPADDR" "udp" "$LPORT"
	done

	#~ for PORT in ${!TCP_PORTS[*]};
	LPROT='tcp'
	for LPORT in "${TCP_PORTS[@]}"
	do
		[ -z "$LPORT" ] && continue
		[ $QUIET -lt 1 ] && error_echo "Opening ${LPORT}/${LPROT} on ${LIPADDR}"
		[ $TEST -lt 1 ] && ipaddr_firewall_port_open "$LIPADDR" "tcp" "$LPORT"
	done

	return 0
	
	
}

config_firewall_add(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LPROT="$1"
	local LPORT="$2"
	local LPARAMS="$3"
	
	if [ "$LPROT" != 'udp' ] && [ "$LPROT" != 'tcp' ]; then
		error_echo "Error: Protocol ${LPROT} does not equal udp or tcp"
		return 1
	fi
	
	if ! [[ "$LPORT" =~ ^[0-9]+$ ]]; then
		error_echo "Error: Port ${LPORT} is not an integer"
		return 1
	fi
	
	[ $QUIET -lt 1 ] && error_echo "Opening ${LPORT}/${LPROT} on ${LPARAMS}"
	[ $TEST -lt 1 ] && firewall_port_open "$LPROT" "$LPORT" "$LPARAMS"
	return 0
}

config_firewall_remove(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LPROT="$1"
	local LPORT="$2"
	local LPARAMS="$3"

	if [ "$LPROT" != 'udp' ] && [ "$LPROT" != 'tcp' ]; then
		error_echo "Error: Protocol ${LPROT} != to udp or tcp"
		return 1
	fi
	
	if ! [[ "$LPORT" =~ ^[0-9]+$ ]]; then
		error_echo "Error: Port ${LPORT} must be an integer"
		return 1
	fi
	
	[ $QUIET -lt 1 ] && error_echo "Closing ${LPORT}/${LPROT} on ${LPARAMS}"
	[ $TEST -lt 1 ] && firewall_port_close "$LPROT" "$LPORT" "$LPARAMS"
	return 0
}


#See: http://ubuntu.swerdna.org/ubusambaserver.html#firewall
ufw_samba_fix(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	
	( ! service_is_enabled 'smbd' ) && return 1


	UFWCONF='/etc/default/ufw'

	if [ $(egrep -c '^IPT_MODULES=.*nf_conntrack_netbios_ns' $UFWCONF) -lt 1 ]; then
		error_echo "Adding $UFWCONF netbios-ns module.."
		#IPT_MODULES="nf_conntrack_ftp nf_nat_ftp nf_conntrack_netbios_ns"
		sed -i -e 's/^IPT_MODULES="\(.*\)"$/IPT_MODULES="\1 nf_conntrack_netbios_ns"/' "$UFWCONF"
	  else
		error_echo 'Module "netbios-ns" already enabled..'
	fi

}

help_disp(){
	error_echo "${SCRIPT} [--debug] [--quiet|--verbose] [--test] [--default] [--no-failsafe] [--add portn/tcp|udp] [--remove portn/tcp|udp] [ipaddr1 ipaddr2 ...] [ifdev1 ifdev2 ...]"
}

########################################################################################
########################################################################################
########################################################################################
########################################################################################
#
# main()
#
########################################################################################
########################################################################################
########################################################################################
########################################################################################

error_echo '===================================================================='
error_echo "${SCRIPT_DIR}/${SCRIPT} ${@}"
error_echo '===================================================================='

SHORTARGS='hqvdcfpa'
LONGARGS="help,
quiet,
verbose,
debug,
default,
force,
test,
clear,
min,minimal,
public,all-subnets,
no-failsafe,
services:,
add:,
remove:,
blip"

# Remove line-feeds..
LONGARGS="$(echo "$LONGARGS" | sed ':a;N;$!ba;s/\n//g')"

ARGS=$(getopt -o "$SHORTARGS" -l "$LONGARGS"  -n "$(basename $0)" -- "$@")

eval set -- "$ARGS"

#~ echo "\"$@\""

while [ $# -gt 0 ]; do

	case "$1" in
		--)
			;;
		-h|--help)
			help_disp
			exit 1
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
		-c|--default|--clear|--min|--minimal)
			MINIMAL=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --minimal"
			;;
		-a|-p|--public|--all-subnets)
			# Make this apply to only specific ports / applications / services?
			MAKE_PUBLIC=1
			CONFIG_NETWORK_OPTS="${CONFIG_NETWORK_OPTS} --public"
			;;
		--no-failsafe)
			NO_FAILSAFE=1
			;;
		--services)
			shift
			SERVICES="${SERVICES} ${1}"
			;;
		--add)
			#~ [--add udp|tcp portn] [--add 5201/tcp]
			shift
			PORTPROT="$1"
			PORT=$(echo "$PORTPROT" | sed -n -e 's/^\([[:digit:]]\+\)\/[tcudp]\+.*/\1/p')
			PROT=$(echo "$PORTPROT" | sed -n -e 's/^[[:digit:]]\+\/\([tcudp]\+\).*/\1/p')
			[ -z "$PROT" ] && PROT="$1"
			[ -z "$PORT" ] && PORT="$3"
			ADD=1
			REMOVE=0
			;;
		--remove)
			#~ [--remove udp|tcp portn]
			shift
			PORTPROT="$1"
			PORT=$(echo "$PORTPROT" | sed -n -e 's/^\([[:digit:]]\+\)\/[tcudp]\+.*/\1/p')
			PROT=$(echo "$PORTPROT" | sed -n -e 's/^[[:digit:]]\+\/\([tcudp]\+\).*/\1/p')
			[ -z "$PROT" ] && PROT="$1"
			[ -z "$PORT" ] && PORT="$3"
			ADD=0
			REMOVE=1
			;;
		*)
			[ $VERBOSE -gt 0 ] && error_echo "ARBITRARY ARG ${1}"
			ipaddress_validate "$1"
			if [ $? -eq 0 ]; then
				IP_ADDRESSES="${IP_ADDRESSES} ${1}"
			else
				# This must be a device name..
				IF_DEVS="${IF_DEVS} ${1}"
			fi
			;;
   esac
   shift
done

#Trim leading & trailing spaces..
IP_ADDRESSES="$(echo "$IP_ADDRESSES" | xargs)"
IF_DEVS="$(echo "$IF_DEVS" | xargs)"

[ ! -z "$IP_ADDRESSES" ] && error_echo "Configuring firewall for [${IP_ADDRESSES}]"
[ ! -z "$IF_DEVS" ] && error_echo "Configuring firewall for [${IF_DEVS}]"


if [ $MAKE_PUBLIC -gt 0 ]; then
	PARAMS=""
else
	if [ ! -z "$IP_ADDRESSES" ]; then
		PARAMS="$IP_ADDRESSES"
	elif [ ! -z "$IF_DEVS" ]; then
		PARAMS="$IF_DEVS"
	else
		PARAMS=$(ifaces_get)
	fi
fi

# If we're just adding or removing a port..
if [ $ADD -gt 0 ]; then
	config_firewall_add "$PROT" "$PORT" "$PARAMS"
	config_firewall_status_show $MAKE_PUBLIC
	exit 0
elif [ $REMOVE -gt 0 ]; then
	config_firewall_remove "$PROT" "$PORT"  "$PARAMS"
	config_firewall_status_show $MAKE_PUBLIC
	exit 0
fi

echo "PARAMS == ${PARAMS}"

# Reset the SCRIPT_DIRfirewall to defaults..
config_firewall_default_set

# Open all interfaces for bootpc & ssh
if [ $NO_FAILSAFE -lt 1 ]; then
	config_firewall_services "$PARAMS"
fi


if [ -z "$SERVICES" ]; then
	[ $MINIMAL -gt 0 ] && SERVICES="iperf3" || SERVICES="iperf3 lighttpd lms minidlna mochad nmbd rsyncd smbd squeezelite x10cmdr.socket"
fi

# Open all interfaces for our other services.
config_firewall_apps "$SERVICES" "$PARAMS"

# Open all interfaces for our /etc/default/config-firewall defined ports
config_firewall_ports "$PARAMS"

#Open the firewall for samba..
[ $USE_UFW -gt 0 ] && ufw_samba_fix

config_firewall_enable
config_firewall_status_show

error_echo 'Done!'
exit 0
