#!/bin/bash

SCRIPT_VERSION=20201221.124923

# Bash script to create application / service.xml profiles for firewall
# rules for our commonly added services.

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"

SCRIPTNAME="$(basename "$(readlink -f "$0")")"
INST_NAME="${SCRIPTNAME%%.*}"

is_root


DEBUG=0
TEST=0
VERBOSE=0
QUIET=0
FORCE=0
MAKE_PUBLIC=0


SERVICES=


prep_firewall_app_iperf3(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=iPerf3 speed test tool for TCP/UDP
		description=iPerf3 is a tool for active measurements of the maximum achievable bandwidth on IP networks
		ports=5201/tcp|5201/udp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>iperf3 is a tool for active measurements of the maximum achievable bandwidth on IP networks.</description>
		  <port protocol="udp" port="5201"/>
		  <port protocol="tcp" port="5201"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	
}


prep_firewall_app_lighttpd(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=Web Server (lighttpd, HTTP + HTTPS)
		description=A fast webserver with minimal memory footprint
		ports=80,443/tcp

		[Lighttpd HTTP]
		title=Web Server (lighttpd, HTTP)
		description=A fast webserver with minimal memory footprint
		ports=80/tcp

		[Lighttpd HTTPS]
		title=Web Server (lighttpd, HTTPS)
		description=A fast webserver with minimal memory footprint
		ports=443/tcp

		[Lighttpd Full]
		title=Web Server (lighttpd, HTTP + HTTPS)
		description=A fast webserver with minimal memory footprint
		ports=80,443/tcp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>A fast webserver with minimal memory footprint.</description>
		  <port protocol="tcp" port="80"/>
		  <port protocol="tcp" port="443"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}

prep_firewall_app_lms(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=Logitech Media Server
		description=All ports for LMS and Castbridge
		ports=3483,9000,9090,49152:49183/tcp|3483/udp

		[SlimDiscovery]
		title=Slim Devices Discovery
		description=UDP port allowing LMS and Squeezebox device discovery
		ports=3483/udp

		[SlimProto]
		title=Slim Devices Protocol
		description=Port for LMS streaming to Squeezebox Devices
		ports=3483/tcp

		[SlimHTTP]
		title=Slim Devices WebUI
		description=HTTP port for the LMS webUI
		ports=9000/tcp

		[SlimCLI]
		title=Slim Devices CLI
		description=Port for CLI to LMS
		ports=9090/tcp

		[Castbridge]
		title=Slim Castbridge Communication Ports
		description=Port range for LMS streaming to Chromecast-like devices via Castbridge
		ports=49152:49183/tcp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>A Media server primarily for streaming audio content to SlimDevices and software clones.</description>
		  <port protocol="udp" port="3483"/>
		  <port protocol="tcp" port="3483"/>
		  <port protocol="tcp" port="9000"/>
		  <port protocol="tcp" port="9090"/>
		  <port protocol="tcp" port="49152-49183"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}

prep_firewall_app_minidlna(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=MiniDLNA Server
		description=MiniDLNA is a simple media server software with the aim to be fully compliant with DLNA/UPNP-AV clients.
		ports=8200/tcp|1900/udp		
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>MiniDLNA is a simple media server software with the aim to be fully compliant with DLNA/UPNP-AV clients. Enable this service if you run minidlna service.</description>
		  <port protocol="tcp" port="8200"/>
		  <port protocol="udp" port="1900"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}

prep_firewall_app_mochad(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=mochad tcp to x10 interface
		description=mochad is a TCP gateway daemon for the X10 CM15A, CM15Pro and CM19A controllers
		ports=1099/tcp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>mochad is a TCP gateway daemon for the X10 CM15A, CM15Pro and CM19A controllers.</description>
		  <port protocol="tcp" port="1099"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}

prep_firewall_app_nmbd(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=Samba NETBIOS Name Service daemon
		description=The nmbd server daemon understands and replies to NetBIOS name service requests
		ports=137,138/udp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>NETBIOS Name Service. The nmbd server daemon understands and replies to NetBIOS name service requests.</description>
		  <port protocol="udp" port="137"/>
		  <port protocol="udp" port="138"/>
		  <helper name="netbios-ns"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}

prep_firewall_app_rsyncd(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=Rsync in daemon mode.
		description=Rsync in daemon mode works as a central server, in order to house centralized files and keep them synchronized.
		ports=873/tcp|873/udp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>Rsync in daemon mode works as a central server, in order to house centralized files and keep them synchronized.</description>
		  <port protocol="tcp" port="873"/>
		  <port protocol="udp" port="873"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}

prep_firewall_app_smbd(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=Samba Server Message Block daemon
		description=The Samba smbd server daemon acts as client and server on Windows SMB file and printer sharing networks.
		ports=139,445/tcp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>The Samba smbd server daemon acts as client and server on Windows SMB file and printer sharing networks.</description>
		  <port protocol="tcp" port="139"/>
		  <port protocol="tcp" port="445"/>
		  <helper name="netbios-ns"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}

prep_firewall_app_squeezelite(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=squeezelite slimproto player
		description=Squeezelite ports for slim discovery and slim streaming protocol
		ports=3483/tcp|1024:65535/udp

		[SQSlimDiscovery]
		title=Slim Devices Discovery
		description=UDP port allowing LMS and Squeezebox device discovery
		ports=1024:65535/udp

		[SQSlimProto]
		title=Slim Devices Protocol
		description=Port for LMS streaming to Squeezebox Devices
		ports=3483/tcp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>Squeezelite ports for slim discovery and slim streaming protocol.</description>
		  <port protocol="udp" port="3483"/>
		  <port protocol="tcp" port="3483"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi

	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}

prep_firewall_app_unifi(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[unifi]
		title=Ubiquiti UniFi Network Controller
		description=Unifi ports for local ingress and LC management over the internet
		ports=6789,8080,8443,8880,8843,27117/tcp|1900,3478,5514,5656:5699,10001/udp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<!--Port usage documented at https://help.ui.com/hc/en-us/articles/218506997-UniFi-Ports-Used-->
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>Ubiquiti UniFi Network Controller.</description>
		  <port protocol="udp" port="3478"/>
		  <port protocol="udp" port="5514"/>
		  <port protocol="udp" port="5656-5699"/>
		  <port protocol="udp" port="10001"/>
		  <port protocol="udp" port="1900"/>
		  <port protocol="tcp" port="8080"/>
		  <port protocol="tcp" port="8443"/>
		  <port protocol="tcp" port="8880"/>
		  <port protocol="tcp" port="8843"/>
		  <port protocol="tcp" port="6789"/>
		  <port protocol="tcp" port="27117"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi
	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}


prep_firewall_app_x10cmdr(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LAPP_NAME="$1"
	local LAPP_DEF=
	
	if [ $USE_UFW -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF1
		[${LAPP_NAME}]
		title=X10 Commander Server for Heyu and mochad control via x10cmdr iOS and Android Apps
		description=Allows communication via x10cmdr.socket service to x10cmdr.sh script
		ports=3003/tcp
		EOF_APPDEF1
	elif [ $USE_FIREWALLD -gt 0 ]; then
		read -r -d '' LAPP_DEF <<- EOF_APPDEF2
		<?xml version="1.0" encoding="utf-8"?>
		<service>
		  <short>${LAPP_NAME}</short>
		  <description>X10 Commander Server for Heyu and mochad control via x10cmdr iOS and Android Apps</description>
		  <port protocol="tcp" port="3003"/>
		</service>
		EOF_APPDEF2
	else
		error_echo "Error: Cannot determine firewall type. Exiting."
		exit 1
	fi
	
	[ $DEBUG -gt 0 ] && error_echo '######################################################################################################'
	[ $DEBUG -gt 0 ] && error_echo "$LAPP_DEF"

	[ $TEST -lt 1 ] && firewall_app_create "$LAPP_NAME" "$LAPP_DEF"
	[ $TEST -lt 1 ] && firewall_app_info "$LAPP_NAME"
	
}


fn_exists() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
    #~ LC_ALL=C type -t "$1" 
    LC_ALL=C type -t "$1" 2>/dev/null | grep -q 'function'
}



prep_firewall_apps() {
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME}( $@ )"
	local LSERVICES="$1"
	local LPREPONLY=${2:-0}
	local LPUBLIC=${3:-0}
	local LSERVICE=
	local LFUNCTION=
	local LIFACES=
	
	[ $LPUBLIC -lt 1 ] && LIFACES="$(ifaces_get | xargs)"
	
	for LSERVICE in $LSERVICES
	do
		# First off, see if we even have an app for the service, stripping off .service, .socket, etc.
		LFUNCTION="prep_firewall_app_${LSERVICE%.*}"
		if ( ! fn_exists "$LFUNCTION" ); then
			error_echo "Error: No firewall app function \"${LFUNCTION}\" exists for service \"${LSERVICE}\"."
			continue
		fi
		
		
		if ( service_is_enabled "$LSERVICE" ) || [ $FORCE -gt 0 ]; then
		
			if [ $VERBOSE -gt 0 ]; then
				error_echo " "
				error_echo " "
				error_echo '######################################################################################################'
			fi
		
			[ $QUIET -lt 1 ] && error_echo "Creating firewall application profile for \"${LSERVICE%.*}\" on \"${LIFACES}\""
			[ $TEST -lt 1 ] && $LFUNCTION "${LSERVICE%.*}"
			[ $QUIET -lt 1 ] && [ $LPREPONLY -lt 1 ] && error_echo "Opening firewall for service ${LSERVICE}"
			[ $TEST -lt 1 ] && [ $LPREPONLY -lt 1 ] && firewall_app_open "${LSERVICE%.*}" "$LIFACES"
		fi
	done
	
	if [ $VERBOSE -gt 0 ]; then
		error_echo " "
		error_echo " "
		error_echo '######################################################################################################'
		error_echo "Open firewall application profiles:"
		firewall_apps_list
	fi
	
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

DEBUG=0
QUIET=0
VERBOSE=0
TEST=0
PREP_ONLY=0
MAKE_PUBLIC=0
SERVICES=

SHORTARGS='hqvftnpa'
LONGARGS="help,
debug,
quiet,
verbose,
force,
test,
no-open,prep-only,
public,
all"

# Remove line-feeds..
LONGARGS="$(echo "$LONGARGS" | sed ':a;N;$!ba;s/\n//g')"

ARGS=$(getopt -o "$SHORTARGS" -l "$LONGARGS"  -n "$(basename $0)" -- "$@")

[ $? -gt 0 ] && exit $?

eval set -- "$ARGS"

#~ echo "\"$@\""

while [ $# -gt 0 ]; do

	case "$1" in
		--)
			;;
		-h|--help)
			disp_help
			exit 1
			;;
		-d|--debug)
			DEBUG=1
			;;
		-q|--quiet)
			QUIET=1
			VERBOSE=0
			;;
		-v|--verbose)
			QUIET=0
			VERBOSE=1
			;;
		-f|--force)
			FORCE=1
			;;
		-t|--test)
			TEST=1
			;;
		-n|--no-open|--prep-only)
			PREP_ONLY=1
			;;
		-p|--public)
			MAKE_PUBLIC=1
			;;
		-a|--all)
			SERVICES=
			;;
		*)
			SERVICES="${SERVICES} ${1}"
			;;
   esac
   shift
done
	
# These are our standard services we usually create a firewall rule for..
[ -z "$SERVICES" ] && SERVICES="iperf3 lighttpd lms minidlna mochad nmbd rsyncd smbd squeezelite x10cmdr.socket"


# Open all interfaces for our other services.
prep_firewall_apps "$SERVICES" $PREP_ONLY $MAKE_PUBLIC
