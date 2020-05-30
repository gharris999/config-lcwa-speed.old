#!/bin/bash

######################################################################################################
# Bash script for installing Andi Klein's Python LCWA PPPoE Speedtest Logger 
# as a service on systemd, upstart & sysv systems
######################################################################################################
SCRIPT_VERSION=20200529.223409
REQINCSCRIPTVER=20200422

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"

if [[ -z "$INCSCRIPTVER" ]] || [[ $INCSCRIPTVER -lt $REQINCSCRIPTVER ]]; then
	error_exit "Version ${REQINCSCRIPTVER} of ${INCLUDE_FILE} required."
fi

SCRIPT="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT")"
SCRIPTNAME=$(basename $0)

# Make sure we're running under root or sudo credentials
is_root

HAS_PYTHON2=0
[ ! -z "$(which python2 2>/dev/null)" ] && HAS_PYTHON2=1


NOPROMPT=0
QUIET=0
DEBUG=0
UPDATE=0
NO_PAUSE=0
FORCE=0
NO_SCAN=0
TEST_MODE=0
UPDATE_DEPS=0
NO_HOSTNAME_CHANGE=0

NEEDSUSER=1
NEEDSCONF=1
NEEDSDATA=1
NEEDSLOG=1
NEEDSPRIORITY=1
NEEDSPID=0

# Default to only installing python3 dependencies..
FORCE_PYTHON3=1

# Save our HOME var to be restored later..
CUR_HOME="$HOME"

######################################################################################################
# Vars specific to this service install
######################################################################################################

# Change to 1 to prevent updates to the env file
INST_ENVFILE_LOCK=0

# Download all revisions, not just most recent..
# All-revs are necessary in order to switch between branches..
ALLREVS=0

# Delete old local repo and re-clone & re-checkout
CHECKOUT_ONLY=0

# When removing /uninstalling, keep the user, local repo, data & logs..
KEEPLOCALDATA=0
KEEPLOCALREPO=0

INST_NAME='lcwa-speed'
INST_PROD="Andi Klein's Python LCWA PPPoE Speedtest Logger"
INST_DESC='LCWA PPPoE Speedtest Logger git code Daemon'
INST_USER="$INST_NAME"
if [ $IS_DEBIAN -gt 0 ]; then
	INST_GROUP='nogroup'
else
	INST_GROUP="$INST_NAME"
fi

INST_PATH="/usr/local/share/${INST_NAME}"
INST_BIN="$(which python3 2>/dev/null) -u /usr/local/share/${INST_NAME}/src/test_speed1_3.py"

SUPINST_PATH="/usr/local/share/config-${INST_NAME}"

INST_PIDDIR="/var/run/${INST_NAME}"
INST_PID="$INST_PIDDIR/${INST_NAME}.pid"

INST_DATADIR="/var/lib/${INST_NAME}/speedfiles"
INST_LOGDIR="/var/log/${INST_NAME}"
INST_LOGFILE="${INST_LOGDIR}/${INST_NAME}.log"

HOSTNAME=$(hostname | tr [a-z] [A-Z])

#~ export PYTHONPATH=/home/pi/.local/lib/python2.7/site-packages
#~ export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games
#~ sudo -u pi -H sh -c "python /home/pi/git/speedtest/src/test_speed1.py -t 10 -d /home/pi/git/speedtest/src/LCWA_d.txt -s 18002 &"

#~ sudo -u daadmin -H sh -c "python /home/daadmin/git/speedtest/src/test_speed1.py --time 10 --dpfile /home/daadmin/git/speedtest/src/LCWA_d.txt --serverid 18002 &"




######################################################################################################
# Service-specific Vars
######################################################################################################

# Identifiers
#~ LCWA_SERVICE="$INST_NAME"
#~ LCWA_PRODUCT="$INST_PROD"
#~ LCWA_DESC="$INST_DESC"
#~ LCWA_PRODUCTID="f1a4af09-977c-458a-b3f7-f530fb9029c1"				# Random GUID..
#~ LCWA_VERSION="YYYYMMDD.HHMMSS"										# Set at 

# User account and group under which the service will run..
#~ LCWA_USER="$INST_USER"
#~ LCWA_GROUP="nogroup"

# Remote & local repos
#~ LCWA_REPO='https://github.com/pabloemma/LCWA.git'
#~ LCWA_REPO_BRANCH='origin/master'
#~ LCWA_LOCALREPO="/usr/local/share/${LCWA_SERVICE}"

#~ LCWA_SUPREPO='https://github.com/gharris999/config-lcwa-speed.git'
#~ LCWA_SUPREPO_BRANCH='origin/master'
#~ LCWA_LOCALSUPREPO="/usr/local/share/config-${LCWA_SERVICE}"

# Conf, data & log storage locations
#~ LCWA_CONFDIR="/etc/${INST_NAME}"
#~ LCWA_DATADIR="/var/lib/${INST_NAME}"
#~ LCWA_LOGDIR="/var/log/${INST_NAME}"
#~ LCWA_LOGFILE="${LCWA_LOGDIR}/${INST_NAME}.log"
#~ LCWA_ERRFILE="${LCWA_LOGDIR}/${INST_NAME}-error.log"
#~ LCWA_VCLOG="${LCWA_LOGDIR}/${INST_NAME}-update.log"

# Command-line arguments for the daemon
#~ LCWA_OPTIONS=""
#~ LCWA_LOGGERID="UB01"													# Prefix that identifies this speedtest logger
#~ LCWA_TESTFREQ=10														# time between succssive speedtests in minutes
#~ LCWA_DB_KEYFILE="/etc/${INST_NAME}/LCWA_d.txt"						# Key file for shared dropbox folder for posting results
#~ LCWA_OKLA_SRVRID=18002												# Okla speedtest server ID: 18002 == CyberMesa
#~ LCWA_DATADIR="/var/lib/${INST_NAME}/speedfiles"						# Local storage dir for our CSV data

# Command to be launched by the service
#~ LCWA_DAEMON="$(which python3 2>/dev/null) -u ${LCWA_LOCALREPO}/src/test_speed1_3.py"	# -u arg unbuffers python's output for logging.


# Service control variables: pid, priority, memory, etc..
#~ LCWA_PIDFILE="/var/run/${INST_NAME}/${INST_NAME}.pid"
#~ LCWA_NICE=-19
#~ LCWA_RTPRIO=45
#~ LCWA_MEMLOCK=infinity
#~ LCWA_CLEARLOG=1

# Utility Scripts
#~ LCWA_DEBUG_SCRIPT="${LCWA_LOCALSUPREPO}/scripts/${INST_NAME}-debug.sh"
#~ LCWA_UPDATE_SCRIPT="${LCWA_LOCALSUPREPO}/scripts/${INST_NAME}-update.sh"

# Other essential environmental variables
#~ PYTHONPATH=/usr/local/lib/python2.7/site-packages
#~ HOME="/var/lib/${INST_NAME}"

LCWA_SERVICE=
LCWA_PRODUCT=
LCWA_DESC=
LCWA_PRODUCTID=
LCWA_VERSION=

LCWA_USER=
LCWA_GROUP=

LCWA_REPO=
LCWA_REPO_BRANCH=
LCWA_LOCALREPO=

LCWA_SUPREPO=
LCWA_SUPREPO_BRANCH=
LCWA_LOCALSUPREPO=

LCWA_CONFDIR=
LCWA_DATADIR=
LCWA_LOGDIR=
LCWA_LOGFILE=
LCWA_ERRFILE=
LCWA_VCLOG=

LCWA_OPTIONS=
LCWA_LOGGERID=
LCWA_TESTFREQ=
LCWA_DB_KEYFILE=
LCWA_OKLA_SRVRID=

LCWA_DAEMON=
LCWA_EXEC_ARGS=
LCWA_EXEC_ARGS_DEBUG=

LCWA_PIDFILE=
LCWA_NICE=
LCWA_RTPRIO=
LCWA_MEMLOCK=
LCWA_CLEARLOG=

LCWA_DEBUG_SCRIPT=
LCWA_UPDATE_SCRIPT=

#~ PYTHONPATH=
#~ HOME=


env_vars_name(){
	echo "LCWA_SERVICE" \
"LCWA_PRODUCT" \
"LCWA_DESC" \
"LCWA_PRODUCTID" \
"LCWA_VERSION" \
"LCWA_USER" \
"LCWA_GROUP" \
"LCWA_REPO" \
"LCWA_REPO_BRANCH" \
"LCWA_LOCALREPO" \
"LCWA_SUPREPO" \
"LCWA_SUPREPO_BRANCH" \
"LCWA_LOCALSUPREPO" \
"LCWA_CONFDIR" \
"LCWA_DATADIR" \
"LCWA_LOGDIR" \
"LCWA_LOGFILE" \
"LCWA_ERRFILE" \
"LCWA_VCLOG" \
"LCWA_OPTIONS" \
"LCWA_LOGGERID" \
"LCWA_TESTFREQ" \
"LCWA_DB_KEYFILE" \
"LCWA_OKLA_SRVRID" \
"LCWA_DAEMON" \
"LCWA_EXEC_ARGS" \
"LCWA_EXEC_ARGS_DEBUG" \
"LCWA_PIDFILE" \
"LCWA_NICE" \
"LCWA_RTPRIO" \
"LCWA_MEMLOCK" \
"LCWA_CLEARLOG" \
"LCWA_DEBUG_SCRIPT" \
"LCWA_UPDATE_SCRIPT" \
"PYTHONPATH" \
"HOME"
}

######################################################################################################
# defaults_get() Generate default values for the /etc/sysconfig|default/config file
######################################################################################################
env_vars_defaults_get(){

    echo "Getting Defaults.."

	[ -z "$LCWA_SERVICE" ] 			&& LCWA_SERVICE="$INST_NAME"
	[ -z "$LCWA_PRODUCT" ] 			&& LCWA_PRODUCT="$(echo "$INST_NAME" |  tr [a-z] [A-Z])"
	[ -z "$LCWA_DESC" ] 			&& LCWA_DESC="${LCWA_PRODUCT}-TEST Logger"
	[ -z "$LCWA_PRODUCTID" ] 		&& LCWA_PRODUCTID="f1a4af09-977c-458a-b3f7-f530fb9029c1"
	[ -z "$LCWA_VERSION" ] 			&& LCWA_VERSION=20200529.223409
	
	[ -z "$LCWA_USER" ] 			&& LCWA_USER="$INST_USER"
	[ -z "$LCWA_GROUP" ] 			&& LCWA_GROUP="$INST_GROUP"

	[ -z "$LCWA_REPO" ] 			&& LCWA_REPO='https://github.com/pabloemma/LCWA.git'
	[ -z "$LCWA_REPO_BRANCH" ] 		&& LCWA_REPO_BRANCH='origin/master'
	[ -z "$LCWA_LOCALREPO" ] 		&& LCWA_LOCALREPO="$INST_PATH"
	
	[ -z "$LCWA_SUPREPO" ] 			&& LCWA_SUPREPO='https://github.com/gharris999/config-lcwa-speed.git'
	[ -z "$LCWA_SUPREPO_BRANCH" ] 	&& LCWA_SUPREPO_BRANCH='origin/master'
	[ -z "$LCWA_LOCALSUPREPO" ] 	&& LCWA_LOCALSUPREPO="$SUPINST_PATH"

	[ -z "$LCWA_CONFDIR" ] 			&& LCWA_CONFDIR="/etc/${INST_NAME}"
	[ -z "$LCWA_DATADIR" ] 			&& LCWA_DATADIR="/var/lib/${INST_NAME}/speedfiles"
	[ -z "$LCWA_LOGDIR" ] 			&& LCWA_LOGDIR="/var/log/${INST_NAME}"
	[ -z "$LCWA_LOGFILE" ] 			&& LCWA_LOGFILE="${LCWA_LOGDIR}/${INST_NAME}.log"
	[ -z "$LCWA_ERRFILE" ] 			&& LCWA_ERRFILE="${LCWA_LOGDIR}/${INST_NAME}-error.log"
	[ -z "$LCWA_VCLOG" ] 			&& LCWA_VCLOG="${LCWA_LOGDIR}/${INST_NAME}-update.log"
	
	[ -z "$LCWA_OPTIONS" ] 			&& LCWA_OPTIONS=""
	[ -z "$LCWA_LOGGERID" ] 		&& LCWA_LOGGERID="$(hostname | cut -c1-4)"
	[ -z "$LCWA_TESTFREQ" ]			&& LCWA_TESTFREQ='10'
	[ -z "$LCWA_DB_KEYFILE" ]		&& LCWA_DB_KEYFILE="${LCWA_CONFDIR}/LCWA_d.txt"
	[ -z "$LCWA_OKLA_SRVRID" ]		&& LCWA_OKLA_SRVRID='18002'

	[ -z "$LCWA_DAEMON" ] 			&& LCWA_DAEMON="$INST_BIN"
	[ -z "$LCWA_EXEC_ARGS" ] 		&& LCWA_EXEC_ARGS="--time \${LCWA_TESTFREQ} --dpfile \${LCWA_DB_KEYFILE} --serverid \${LCWA_OKLA_SRVRID}"
	[ -z "$LCWA_EXEC_ARGS_DEBUG" ] 	&& LCWA_EXEC_ARGS_DEBUG="--adebug --time \${LCWA_TESTFREQ} --dpfile \${LCWA_DB_KEYFILE} --serverid \${LCWA_OKLA_SRVRID}"
	
	[ -z "$LCWA_NICE" ] 			&& LCWA_NICE="$INST_NICE"
	[ -z "$LCWA_RTPRIO" ]			&& LCWA_RTPRIO="$INST_RTPRIO"
	[ -z "$LCWA_MEMLOCK" ]			&& LCWA_MEMLOCK="$INST_MEMLOCK"
	[ -z "$LCWA_CLEARLOG" ] 		&& LCWA_CLEARLOG=1

	[ -z "$LCWA_DEBUG_SCRIPT" ]		&& LCWA_DEBUG_SCRIPT="${LCWA_LOCALSUPREPO}/scripts/${INST_NAME}-debug.sh"
	[ -z "$LCWA_UPDATE_SCRIPT" ]	&& LCWA_UPDATE_SCRIPT="${LCWA_LOCALSUPREPO}/scripts/${INST_NAME}-update.sh"
	
	[ -z "$PYTHONPATH" ] 			&& PYTHONPATH="$(find /usr -type d -name 'site-packages' -exec readlink -f {} \; 2>/dev/null | head -n 1)"
	
	# Andi's python code needs this variable
	HOME="/var/lib/${INST_NAME}"

    if [ $DEBUG -gt 0 ]; then
		env_vars_show $(env_vars_name)
	fi

}

env_vars_show(){
	for VAR in $@
	do
		echo "${VAR}=\"${!VAR}\""
	done
}


###############################################################################
# db_keyfile_install() -- Creates the LCWA_d.txt dropbox key file from an
#                         encrypted hash.  Prompts for LCWA canonical password.
###############################################################################

db_keyfile_install(){
	
	if [[ -f "$LCWA_DB_KEYFILE" ]] && [[ $FORCE -lt 1 ]]; then
		error_echo "Dropbox keyfile already installed.  Use --force to reinstall."
		return 0
	fi

	error_echo "========================================================================================="
	error_echo "Creating dropbox key file ${LCWA_DB_KEYFILE} from encrypted source."
	error_echo "                Please enter the password when prompted."
	error_echo " "
	echo "U2FsdGVkX18fLV7OVTsMgF+SrMMI05OFtrQcRur6KZ7Ft2+eaC7rRkBJ/stnDggVFro27mMsM2CM4Y4WXEwVuAV9LcajUN+UI0e7e0q3ymYqajoHnX/TBjdUqiEYMNbO" | openssl enc -aes-256-cbc -pbkdf2 -d -a -out "$LCWA_DB_KEYFILE"
	
}

db_keyfile_remove(){
	if [ -f "$LCWA_DB_KEYFILE" ]; then
		error_echo "Removing dropbox key file ${LCWA_DB_KEYFILE}."
		rm -f "$LCWA_DB_KEYFILE"
	fi
}


############################################################################
# apt_install() -- Installs packages via apt-get without prompting.
############################################################################
apt_install(){
	apt-get -y install "$@"
	return $?
}

apt_uninstall(){
	apt remove -y "$@"
	apt autoremove
}


#~ apt packages:

#~ gnupg1 		-- a PGP implementation (deprecated "classic" version)
#~ speedtest		-- binary from ookla.bintray.com apt source
#~ espeak			-- Multi-lingual software speech synthesizer
#~ pulseaudio		-- PulseAudio sound server
#~ build-essential 	-- Debian package development tools, c/c++, make, libc, etc.
#~ python-dev 		-- header files and a static library for Python (default)
#~ git 				-- fast, scalable, distributed revision control system
#~ scons 			-- replacement for make
#~ swig				-- Generate scripting interfaces to C/C++ code
#~ libffi-dev 		-- Foreign Function Interface library (development files)
#~ libffi6			-- Foreign Function Interface library runtime
#~ dnsutils			-- Clients provided with BIND
#~ at-spi2-core		-- Assistive Technology Service Provider Interface (dbus core)
#~ python-gi-cairo	-- Python Cairo bindings for the GObject library


############################################################################
# pkg_deps_install() -- Installs all dependencies available via apt
############################################################################
pkg_deps_install(){
	local LRET=1
	local LIBFFI=
	
	error_echo "========================================================================================="
	error_echo "Installing Package Dependencies.." 
	
	if [ $TEST_MODE -lt 1 ]; then
		# Make 3 attempts to install packages.  RPi's package repositories have a tendency to time-out..
		for n in 1 2 3
		do
	
			if [ $USE_APT -gt 0 ]; then
		
				[ $IS_FOCAL -lt 1 ] && LIBFFI='libffi6' || LIBFFI='libffi7'

				apt_install bc \
							gnupg1 \
							espeak \
							dnsutils \
							whois \
							ufw \
							pulseaudio \
							build-essential \
							git \
							scons \
							swig \
							libffi-dev \
							${LIBFFI} \
							at-spi2-core
				LRET=$?

				if [ $LRET -eq 0 ]; then
					break
				fi
				
			elif [ $USE_YUM -gt 0 ]; then
				#Install dependencies for Fedora..
				dnf groupinstall -y "Development Tools"
				dnf groupinstall -y "C Development Tools and Libraries"
				LRET=$?

				if [ $LRET -gt 0 ]; then
					continue
				fi

				dnf install -y bc \
						gnupg1 \
						espeak \
						bind-utils \
						whois \
						pulseaudio \
						git \
						python3-scons \
						swig \
						libffi-devel \
						libffi \
						at-spi2-core

				LRET=$?

				if [ $LRET -eq 0 ]; then
					break
				fi
			
			fi
				
			# Problem installing the dependencies..
			error_echo "Error installing package dependencies...waiting 10 seconds to try again.."
			sleep 10
		done
	
	fi

	return $LRET
}

pkg_deps_remove(){
	local LIBFFI=
	
	error_echo "Uninstalling Package Dependencies.." 
	if [ $TEST_MODE -lt 1 ]; then
	
		if [ $USE_APT -gt 0 ]; then

			[ $IS_FOCAL -lt 1 ] && LIBFFI='libffi6' || LIBFFI='libffi7'
		
			apt_uninstall gnupg1 \
						  espeak \
						  pulseaudio \
						  scons \
						  swig \
						  libffi-dev \
						  ${LIBFFI} \
						  at-spi2-core
						  
		elif [ $USE_YUM -gt 0 ]; then
		
			dnf remove	gnupg1 \
						espeak \
						python3-scons \
						swig \
						libffi-devel \
						libffi \
						at-spi2-core
		
		fi
	
	fi
	
	return $?
}

############################################################################
# ookla_license_install() -- Runs speedtest under root to generate a
#                            license file, copies it to our data directory.
############################################################################
ookla_license_install(){
	local OOKLA="$(which speedtest 2>/dev/null)"
	
	local LICENSE_SRC='/root/.config/ookla/speedtest-cli.json'
	local LICENSE_DIR="/var/lib/${INST_NAME}/.config/ookla"
	local LICENSE_FILE="${LICENSE_DIR}/speedtest-cli.json"
	
	if [[ -f "$LICENSE_FILE" ]] && [[ $FORCE -lt 1 ]]; then
		error_echo "Ookla speed test licence file ${LICENSE_FILE} already installed.  Use --force to reinstall."
		return 0
	fi
	
	if [ -z "$OOKLA" ]; then
		error_echo "Error: speedtest package is not installed."
		exit 1
	fi
	
	error_echo "Running ${OOKLA} to generate a license file.."

	"$OOKLA" --server-id=18002 --output-header --format=csv
	
	if [ ! -f "$LICENSE_SRC" ]; then
		error_echo "Error: License file ${LICENSE_SRC} not found."
		return 1
	fi
	
	if [ ! -d "$LICENSE_DIR" ]; then
		mkdir -p "$LICENSE_DIR"
	fi
	
	error_echo "Installing ookla license file to ${LICENSE_DIR}.."
	cp -p "$LICENSE_SRC" "$ LICENSE_FILE"
	
	chown -R "${INST_USER}:${INST_GROUP}" "/var/lib/${INST_NAME}"
}

ookla_license_remove(){
	local LICENSE_DIR="/var/lib/${INST_NAME}/.config/ookla"
	local LICENSE_FILE="${LICENSE_DIR}/speedtest-cli.json"
	error_echo "Removing ookla license file ${LICENSE_FILE}.."
	rm "$LICENSE_FILE"
}

############################################################################
# ookla_speedtest_install() -- Installs the apt source and the 
#                              ookla speedtest binary.
############################################################################
ookla_speedtest_install(){
	local DEB_DISTRO=
	local APTLIST_FILE=
	local LRET=1
	
	error_echo "========================================================================================="
	error_echo "Installing Ookla speedtest CLI"

	
	if [[ ! -z "$(which speedtest 2>/dev/null)" ]] && [[ $FORCE -lt 1 ]]; then
		error_echo "Ookla speedtest already installed.  Use --force to reinstall."
		return 0
	fi
	
	# For debian, ubuntu, raspbian, etc.
	if [ $USE_APT -gt 0 ]; then
		DEB_DISTRO="$(lsb_release -sc)"
		APTLIST_FILE='/etc/apt/sources.list.d/speedtest.list'

		export INSTALL_KEY='379CE192D401AB61'
		export DEB_DISTRO="$(lsb_release -sc)"
		apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $INSTALL_KEY
		
		
		if [ -f "$APTLIST_FILE" ]; then
			# Remove any old reference to ookla.bintray.com
			sed -i "/^.*ookla\.bintray\.com.*\$/d" "$APTLIST_FILE"
		else
			error_echo "Creating ${APTLIST_FILE} in apt sources.."
			touch "$APTLIST_FILE"
		fi

		error_echo "Adding ookla ${DEB_DISTRO} source to ${APTLIST_FILE}.."
		echo "deb https://ookla.bintray.com/debian ${DEB_DISTRO} main" >>"$APTLIST_FILE"
		
		error_echo "Updating apt.."
		#~ E: The repository 'https://ookla.bintray.com/debian focal Release' does not have a Release file.
		if [ $(apt-get update 2>&1 | grep -c -E "ookla\.bintray\.com.*${DEB_DISTRO}.*does not have a Release file") -gt 0 ]; then
			DEB_DISTRO='bionic'
			sed -i "/^.*ookla\.bintray\.com.*\$/d" "$APTLIST_FILE"
			error_echo "Adding ookla ${DEB_DISTRO} source to ${APTLIST_FILE}.."
			echo "deb https://ookla.bintray.com/debian ${DEB_DISTRO} main" >>"$APTLIST_FILE"
			error_echo "Updating apt.."
			if [ $(apt-get update 2>&1 | grep -c -E "ookla\.bintray\.com.*${DEB_DISTRO}.*does not have a Release file") -gt 0 ]; then
				error_echo "Error: Could not find a valid package source for ookla speedtest."
				# Install speedtest-cli instead?
				return 1
			fi
		fi
		
		if [ $TEST_MODE -lt 1 ]; then
			# Make 3 attempts to install packages.  RPi's package repositories have a tendency to time-out..
			for n in 1 2 3
			do

				error_echo "Installing Ookla speedtest package.." 
				apt_install speedtest
				LRET=$?

				if [ $LRET -eq 0 ]; then
					break
				fi
				# Problem installing the dependencies..
				error_echo "Error installing Ookla speedtest package...waiting 10 seconds to try again.."
				sleep 10

			done
		fi
		
	# For Fedora, CentOS, RH, etc.
	elif [ $USE_YUM -gt 0 ]; then
	
		error_echo "Adding ookla rpm repo to /etc/yum.repos.d.."
		wget https://bintray.com/ookla/rhel/rpm -O /tmp/bintray-ookla-rhel.repo
		mv -f /tmp/bintray-ookla-rhel.repo /etc/yum.repos.d/
		if [ $TEST_MODE -lt 1 ]; then
			for n in 1 2 3
			do
				error_echo "Installing Ookla speedtest package.." 
				dnf -y --refresh install speedtest
				LRET=$?

				if [ $LRET -eq 0 ]; then
					break
				fi
				# Problem installing the dependencies..
				error_echo "Error installing Ookla speedtest package...waiting 10 seconds to try again.."
				sleep 10

			done
		fi
	
	fi
	
	return $LRET
	
}

############################################################################
# ookla_speedtest_remove() -- uninstalls speedtest & removes the apt source
############################################################################
ookla_speedtest_remove(){
	
	local LLIST_FILE=
	local LSPEEDTEST_BIN="$(which speedtest 2>/dev/null)"
	
	if [ ! -z "$LSPEEDTEST_BIN" ]; then
		error_echo "Uninstalling ${LSPEEDTEST_BIN}"
		if [ $USE_APT -gt 0 ]; then
			[ $TEST_MODE -lt 1 ] && apt remove -y speedtest
			[ $TEST_MODE -lt 1 ] && apt autoremove
			LLIST_FILE='/etc/apt/sources.list.d/speedtest.list'
		elif [ $USE_YUM -gt 0 ]; then
			[ $TEST_MODE -lt 1 ] && dnf remove -y speedtest
			LLIST_FILE='/etc/yum.repos.d/bintray-ookla-rhel.repo'
		fi
	fi
	
	if [ -f "$LLIST_FILE" ]; then
		error_echo "Removing ${LLIST_FILE} from package sources.."
		[ $TEST_MODE -lt 1 ] && rm -f "$LLIST_FILE"
	fi
}




#~ python libs:

#~ via pip/pip3 install
#~ backports.functools_lru_cache -- Backport of functools.lru_cache from Python 3.3 as published at ActiveState.
#~ dropbox						 -- A Python SDK for integrating with the Dropbox API v2. Compatible with Python 2.7 and 3.4+
#~ cairocffi					 -- a set of Python bindings and object-oriented API for cairo. Cairo is a 2D vector graphics library with support for multiple backends including image buffers, PNG, PostScript, PDF, and SVG file output.
#~ matplotlib					 -- Matplotlib is a comprehensive library for creating static, animated, and interactive visualizations in Python.


############################################################################
# python_libs_install() -- Installs python library dependencies
############################################################################
python_libs_install(){
	local CURCD="$(pwd)"
	cd /tmp
	
	echo "Fixing permissions in /var/lib/${INST_NAME}"
	chown -R "root:root" "/var/lib/${INST_NAME}"
	
	error_echo "========================================================================================="
	error_echo "Installing python dependencies to ${HOME}/.cache/pip"

	# systems with python2
	if [ $HAS_PYTHON2 -gt 0 ] && [ $FORCE_PYTHON3 -lt 1 ]; then

		error_echo "Reinstalling python.." 

		#~ [ $TEST_MODE -lt 1 ] && apt install -y --reinstall python 
		[ $TEST_MODE -lt 1 ] && apt_install --reinstall	python \
														python-dev \
														python3-dev \
														python3-pip \
														python-tk \
														python-gi-cairo \
														libfreetype6-dev \
														libpng-dev \
														pkg-config
		
		error_echo "Purging python-pip.." 
		[ $TEST_MODE -lt 1 ] && apt purge -y python-pip
		apt -y autoremove
		error_echo "Reinstalling python-pip.." 
		[ $TEST_MODE -lt 1 ] && wget https://bootstrap.pypa.io/get-pip.py
		[ $TEST_MODE -lt 1 ] && python get-pip.py
		[ $TEST_MODE -lt 1 ] && pip install --upgrade pip
		error_echo "Installing python dependencies.." 

		[ $TEST_MODE -lt 1 ] && pip install --force-reinstall backports.functools_lru_cache \
														dropbox \
														cairocffi \
														matplotlib

		[ $TEST_MODE -lt 1 ] && pip3 install --force-reinstall  backports.functools_lru_cache \
																pydig \
																dropbox \
																cairocffi \
																matplotlib

	else
		
		#python3 installs..
		
		if [ $TEST_MODE -lt 1 ]; then
			# Make 3 attempts to install packages.  RPi's package repositories have a tendency to time-out..
			for n in 1 2 3
			do
				error_echo "Reinstalling python3.." 
				if [ $USE_APT -gt 0 ]; then
					apt_install --reinstall python3 \
											python3-dev \
											python3-tk \
											python3-gi-cairo \
											libfreetype6-dev \
											libpng-dev \
											pkg-config

					LRET=$?
				elif [ $USE_YUM -gt 0 ]; then
					dnf install -y	python3 \
									python3-devel \
									python3-tkinter\
									python3-gobject \
									gtk3 \
									freetype-devel \
									libpng-devel \
									pkgconf-pkg-config
					LRET=$?
				fi

				if [ $LRET -eq 0 ]; then
					break
				fi
				# Problem installing the dependencies..
				error_echo "Error reinstalling python3...waiting 10 seconds to try again.."
				sleep 10

			done
		fi
		
		
		error_echo "Purging python3-pip.." 
		if [ $TEST_MODE -lt 1 ]; then
			if [ $USE_APT -gt 0 ]; then
				apt purge -y python3-pip
				apt -y autoremove
			elif [ $USE_YUM -gt 0 ]; then
				dnf remove -y python3-pip
				dnf autoremove -y
				dnf distro-sync -y
			fi
		fi
		
		error_echo "Reinstalling python3-pip direct from Python Packaging Authority.." 
		[ $TEST_MODE -lt 1 ] && wget https://bootstrap.pypa.io/get-pip.py
		[ $TEST_MODE -lt 1 ] && python3 get-pip.py
		[ $TEST_MODE -lt 1 ] && pip3 install --upgrade pip

		if [ $TEST_MODE -lt 1 ]; then
			# Make 3 attempts to install packages.  RPi's package repositories have a tendency to time-out..
			for n in 1 2 3
			do
				error_echo "Installing python libraries.." 

				pip3 install --force-reinstall  testresources \
												backports.functools_lru_cache \
												pydig \
												dropbox \
												cairocffi \
												matplotlib
				LRET=$?

				if [ $LRET -eq 0 ]; then
					break
				fi
				# Problem installing the dependencies..
				error_echo "Error installing python3 libraries...waiting 10 seconds to try again.."
				sleep 10

			done
		fi
	fi

	
	cd "$CURCD"
	
}

python_libs_remove(){
	
	[ $TEST_MODE -lt 1 ] && pip uninstall backports.functools_lru_cache \
									dropbox \
									cairocffi \
									matplotlib

	[ $TEST_MODE -lt 1 ] && pip3 uninstall pydig

	# systems with python2
	if [ $HAS_PYTHON2 -gt 0 ]; then

		error_echo "Uninstalling python dependencies.." 

		[ $TEST_MODE -lt 1 ] && apt_uninstall	python-tk \
												python-gi-cairo
		

		[ $TEST_MODE -lt 1 ] && pip uninstall --yes	backports.functools_lru_cache \
												dropbox \
												cairocffi \
												matplotlib

		[ $TEST_MODE -lt 1 ] && pip3 uninstall --yes	backports.functools_lru_cache \
												pydig \
												dropbox \
												cairocffi \
												matplotlib

	else
	
		error_echo "Uninstalling python3 dependencies.." 

		[ $TEST_MODE -lt 1 ] && apt_uninstall	python3-tk \
												python3-gi-cairo
		
		error_echo "Installing python3 libraries.." 

		[ $TEST_MODE -lt 1 ] && pip3 uninstall --yes testresources
		[ $TEST_MODE -lt 1 ] && pip3 uninstall --yes backports.functools_lru_cache
		[ $TEST_MODE -lt 1 ] && pip3 uninstall --yes pydig
		[ $TEST_MODE -lt 1 ] && pip3 uninstall --yes dropbox
		[ $TEST_MODE -lt 1 ] && pip3 uninstall --yes cairocffi
		[ $TEST_MODE -lt 1 ] && pip3 uninstall --yes matplotlib

	fi

	cd "$CURCD"

}


######################################################################################################
# inst_dir_create() Create the service install dir..
######################################################################################################
inst_dir_create(){
	INST_PATH="$LCWA_LOCALREPO"
	if [ ! -d "$INST_PATH" ]; then
		echo "Creating ${INST_PATH}.."
		mkdir -p "$INST_PATH"
	fi

}

######################################################################################################
# inst_dir_remove() Remove the service install dir..
######################################################################################################
inst_dir_remove(){
	local LINST_PATH="$1"
	if [ -d "$LINST_PATH" ]; then
		echo "Removing ${LINST_PATH}.."
		rm -Rf "$LINST_PATH"
	fi

}

#------------------------------------------------------------------------------
# in_repo() -- Check to see we are where we are supposed to be..
#------------------------------------------------------------------------------
in_repo(){
	local LLOCAL_REPO="$1"
	
	if [ $(pwd) != "$LLOCAL_REPO" ]; then
		echo "Error: Could not find ${LLOCAL_REPO}"
		echo "${SCRIPTNAME} must exit.."
		exit 1
	fi
}

#------------------------------------------------------------------------------
# git_repo_check() -- Check the repo for a .git dir & the fetch url
#                     return values:
#                     10: repo does not exist -- create it
#                      5: wrong repo -- error, quit
#                      0: repo exists -- update it
#------------------------------------------------------------------------------
git_repo_check(){
	local LREMOTE_REPO="$1"
	local LLOCAL_REPO="$2"
	local LTHIS_REPO=
	
	if [ ! -d "${LLOCAL_REPO}/.git" ]; then
		error_echo "${LLOCAL_REPO} does not exist or is not a git repository."
		# local repo does not exist..set return value to create it
		return 10
	fi

	cd "$LLOCAL_REPO" && in_repo "$LLOCAL_REPO" 
	# Get the URL of the fetch origin of the clone..
	LTHIS_REPO=$(git remote -v show | grep 'fetch' | sed -n -e 's/^origin *\([^ ]*\).*$/\1/p')
	LTHIS_REPO=$(echo "$LTHIS_REPO" | sed -e 's/^[[:space:]]*//')
	LTHIS_REPO=$(echo "$LTHIS_REPO" | sed -e 's/[[:space:]]*$//')

	# We don't care if the source is http:// or git://
	if [ "${LTHIS_REPO##*//}" != "${LREMOTE_REPO##*//}" ]; then
		echo "Error: ${LLOCAL_REPO} is not a git repository for ${LREMOTE_REPO}."
		echo "  git reports ${LTHIS_REPO} as the source."
		return 5
	fi

	# Local repo exists & has the right url -- update it..
	return 0
}

#------------------------------------------------------------------------------
# git_repo_show() -- show the status of the local repo
#------------------------------------------------------------------------------
git_repo_show() {
	local LLOCAL_REPO="$1"

	echo "Getting ${LLOCAL_REPO} status.."
	cd "$LLOCAL_REPO" && in_repo "$LLOCAL_REPO"
	git remote show origin
	echo "Available brances in ${LLOCAL_REPO}:"
	git branch -r
	echo "Status of ${LLOCAL_REPO}:"
	git status
}


#------------------------------------------------------------------------------
# git_repo_clone() -- Clone the remote repo locally..
#------------------------------------------------------------------------------
git_repo_clone(){
	local LREMOTE_REPO="$1"
	local LLOCAL_REPO="$2"
	
	echo "Cloning ${LREMOTE_REPO} to ${LLOCAL_REPO}.."
	# Cloning to --depth 1 (i.e. only most recent revs) results in a dirsize of
	# about 250M for /usr/share/lms/server
	if [ $ALLREVS -gt 0 ]; then
		git clone "$LREMOTE_REPO" "$LLOCAL_REPO"
	else
		git clone --depth 1 "$LREMOTE_REPO" "$LLOCAL_REPO"
	fi

	if [ $? -gt 0 ]; then
		echo "Error cloning ${LREMOTE_REPO}...script must halt."
		exit 1
	fi

	#~ cd "$LLOCAL_REPO" && in_repo "$LLOCAL_REPO"
	#~ git status
	
	git_repo_show "$LLOCAL_REPO"
}

#------------------------------------------------------------------------------
# git_repo_checkout() -- Check out the desired branch..
#------------------------------------------------------------------------------
git_repo_checkout(){
	local LBRANCH="$1"
	local LLOCAL_REPO="$2"

	echo "Checking out branch ${LBRANCH} to ${LLOCAL_REPO}.."

	cd "$LLOCAL_REPO" && in_repo "$LLOCAL_REPO"

	#check out the new branch..
	git checkout "$LBRANCH"

	if [ $? -gt 0 ]; then
		echo "Error checking out branch ${LBRANCH}."
		git_repo_show "$LLOCAL_REPO"
		return 1
	fi
}

#------------------------------------------------------------------------------
# get_repo_create() -- Check and Update or Clone the repo locally and check out a branch
#------------------------------------------------------------------------------
git_repo_create(){
	local LREMOTE_REPO="$1"
	local LREMOTE_BRANCH="$2"
	local LLOCAL_REPO="$3"
	
	# Check and install or update the main repo..
	git_repo_check "$LREMOTE_REPO" "$LLOCAL_REPO"
	
	REPOSTAT=$?
	if [ $REPOSTAT -eq 10 ]; then
		# local repo does not exist...create it..
		#~ get_repo_create "$LCWA_REPO" "$LCWA_REPO_BRANCH" "$LCWA_LOCALREPO"
		git_repo_clone "$LREMOTE_REPO" "$LLOCAL_REPO"
		git_repo_checkout "$LREMOTE_BRANCH" "$LLOCAL_REPO"
	elif [ $REPOSTAT -eq 5 ]; then
		# wrong repo!  Exit!
		git_repo_show "$LREMOTE_REPO" "$LLOCAL_REPO"
		exit 1
	else
		# local repo exists...update it..
		git_repo_clean "$LLOCAL_REPO"
		git_repo_update "$LLOCAL_REPO"
	fi

}

#------------------------------------------------------------------------------
# git_repo_clean() -- Discard any local changes from the repo..
#------------------------------------------------------------------------------
git_repo_clean(){
	local LLOCAL_REPO="$1"
	cd "$LLOCAL_REPO" && in_repo "$LLOCAL_REPO"
	echo "Cleaning ${LLOCAL_REPO}.."
	git reset --hard
	git clean -fd
	if [ $? -gt 0 ]; then
		echo "Error cleaning ${LLOCAL_REPO}...script must halt."
		exit 1
	fi
}

#------------------------------------------------------------------------------
# git_repo_update() -- update the local git repo
#------------------------------------------------------------------------------
git_repo_update(){
	local LLOCAL_REPO="$1"
	cd "$LLOCAL_REPO" && in_repo "$LLOCAL_REPO"
	error_echo "Updating ${LLOCAL_REPO}.."
	git pull
	if [ $? -gt 0 ]; then
		echo "Error updating ${LLOCAL_REPO}...script must halt."
		exit 1
	fi
}

#------------------------------------------------------------------------------
# git_repo_remove() -- delete the local repo
#------------------------------------------------------------------------------
git_repo_remove(){
	local LLOCAL_REPO="$1"
	if [ -d "$LLOCAL_REPO" ]; then
		error_echo "Removing ${LLOCAL_REPO} git local repo.."
		rm -Rf "$LLOCAL_REPO"
	fi
}


######################################################################################################
# lcwa_debug_script_create() Create the startup debugging script..
######################################################################################################
script_debug_install(){
	
	local LLOCAL_DEBUG_SCRIPT="/usr/local/sbin/${INST_NAME}-debug.sh"
	
	# Copy
	if [ -f "$LCWA_DEBUG_SCRIPT" ]; then
		cp -pf "${LCWA_LOCALSUPREPO}/instsrv_functions.sh" /usr/local/sbin
		cp -pf "$LCWA_DEBUG_SCRIPT" "$LLOCAL_DEBUG_SCRIPT"
		chmod 755 "$LLOCAL_DEBUG_SCRIPT"
		touch "--reference=${LCWA_DEBUG_SCRIPT}" "$LLOCAL_DEBUG_SCRIPT"
	elif [ -f "${SCRIPT_DIR}/scripts/${INST_NAME}-debug.sh" ]; then
		cp -pf "${SCRIPT_DIR}/instsrv_functions.sh" /usr/local/sbin
		cp -pf "${SCRIPT_DIR}/scripts/${INST_NAME}-debug.sh" "$LLOCAL_DEBUG_SCRIPT"
		chmod 755 "$LLOCAL_DEBUG_SCRIPT"
		touch "--reference=${SCRIPT_DIR}/scripts/${INST_NAME}-debug.sh" "$LLOCAL_DEBUG_SCRIPT"
	fi

	if [ ! -f "$LLOCAL_DEBUG_SCRIPT" ]; then
		error_echo "Error: could not install ${LLOCAL_DEBUG_SCRIPT}"
		return 1
	fi
	
	error_echo "${LLOCAL_DEBUG_SCRIPT} installed.."

	return 0
}

######################################################################################################
# lcwa_debug_script_remove() Remove the startup debugging script..
######################################################################################################
script_debug_remove(){
	local LLOCAL_DEBUG_SCRIPT="/usr/local/sbin/${INST_NAME}-debug.sh"
	if [ -f "$LLOCAL_DEBUG_SCRIPT" ]; then
		error_echo "Removing ${LLOCAL_DEBUG_SCRIPT}.."
		rm "$LLOCAL_DEBUG_SCRIPT"
	fi

}

######################################################################################################
# lcwa_update_script_create() Create the git/svn update script..
######################################################################################################
script_update_install(){
	local LLOCAL_UPDATE_SCRIPT="/usr/local/sbin/${INST_NAME}-update.sh"
	
	# Copy
	if [ -f "$LCWA_UPDATE_SCRIPT" ]; then
		cp -pf "${LCWA_LOCALSUPREPO}/instsrv_functions.sh" /usr/local/sbin
		cp -pf "${LCWA_LOCALSUPREPO}/scripts/chkfw.sh" /usr/local/sbin
		chmod 755 /usr/local/sbin/chkfw.sh
		cp -pf "$LCWA_UPDATE_SCRIPT" "$LLOCAL_UPDATE_SCRIPT"
		chmod 755 "$LLOCAL_UPDATE_SCRIPT"
		touch "--reference=${LCWA_UPDATE_SCRIPT}" "$LLOCAL_UPDATE_SCRIPT"
	elif [ -f "${SCRIPT_DIR}/scripts/${INST_NAME}-update.sh" ]; then
		cp -pf "${SCRIPT_DIR}/instsrv_functions.sh" /usr/local/sbin
		cp -pf "${SCRIPT_DIR}/scripts/chkfw.sh" /usr/local/sbin
		chmod 755 /usr/local/sbin/chkfw.sh
		cp -pf "${SCRIPT_DIR}/scripts/${INST_NAME}-update.sh" "$LLOCAL_UPDATE_SCRIPT"
		chmod 755 "$LLOCAL_UPDATE_SCRIPT"
		touch "--reference=${SCRIPT_DIR}/scripts/${INST_NAME}-update.sh" "$LLOCAL_UPDATE_SCRIPT"
	fi

	if [ ! -f "$LLOCAL_UPDATE_SCRIPT" ]; then
		error_echo "Error: could not install ${LLOCAL_UPDATE_SCRIPT}"
		return 1
	fi
	
	error_echo "${LLOCAL_UPDATE_SCRIPT} installed.."

}

######################################################################################################
# lcwa_update_script_remove() Remove the git/svn update script..
######################################################################################################
script_update_remove(){
	local LLOCAL_UPDATE_SCRIPT="/usr/local/sbin/${INST_NAME}-update.sh"
	if [ -f "$LLOCAL_UPDATE_SCRIPT" ]; then
		error_echo "Removing ${LLOCAL_UPDATE_SCRIPT}.."
		rm "$LLOCAL_UPDATE_SCRIPT"
	fi

}

crontab_entry_add(){
	local COMMENT="#Everyday, at 5 minutes past midnight, update ${INST_NAME} and restart the service:"
	local EVENT="5 0 * * * ${LCWA_UPDATE_SCRIPT} --debug | $(which logger 2>/dev/null) -t ${LCWA_SERVICE}"
	#~ local EVENT='5 0 * * * /usr/local/share/config-lcwa-speed/scripts/lcwa-speed-update.sh --debug --force --sbin-update'
	#~ local EVENT='5 0 * * * /usr/local/share/config-lcwa-speed/scripts/lcwa-speed-update.sh --debug | /usr/bin/logger -t lcwa-speed'
	local ROOTCRONTAB='/var/spool/cron/crontabs/root'
	
	[ $IS_FEDORA -gt 0 ] && ROOTCRONTAB='/var/spool/cron/root'
	
	[ ! -f "$ROOTCRONTAB" ] && touch "$ROOTCRONTAB"
	
	# Remove any old reference to lcwa-speed-update.sh
	sed -i "/^#.*${INST_NAME}.*$/d" "$ROOTCRONTAB"
	sed -i "/^.*${INST_NAME}-update.*$/d" "$ROOTCRONTAB"

	error_echo "Adding ${EVENT} to ${ROOTCRONTAB}"
	echo "$COMMENT" >>"$ROOTCRONTAB"
	echo "$EVENT" >>"$ROOTCRONTAB"
	
	# Make sure the permissions are correct for root crontab! (i.e. must not be 644!)
	chmod 600 "$ROOTCRONTAB"
	
	# signal crond to reload the file
	sudo touch /var/spool/cron/crontabs	
	
	# Make the entry stick
	error_echo "Restarting root crontab.."
	[ $IS_FEDORA -gt 0 ] && systemctl restart crond || systemctl restart cron
	

	error_echo 'New crontab:'
	error_echo "========================================================================================="
	crontab -l
	error_echo "========================================================================================="
}

crontab_entry_remove(){
	local COMMENT='#Everyday, at 5 minutes past midnight, update ${INST_NAME} and restart the service:'
	local EVENT="5 0 * * * ${LCWA_UPDATE_SCRIPT} --debug"
	local ROOTCRONTAB='/var/spool/cron/crontabs/root'
	
	error_echo "Removing ${EVENT} from ${ROOTCRONTAB}"
	# Remove any old reference to lcwa-speed-update.sh
	sed -i "/^#.*${INST_NAME}.*$/d" "$ROOTCRONTAB"
	sed -i "/^.*${INST_NAME}-update.*$/d" "$ROOTCRONTAB"
	
	# signal crond to reload the file
	sudo touch /var/spool/cron/crontabs	

	# Make the entry stick
	error_echo "Restarting root crontab.."
	systemctl restart cron

	error_echo 'New crontab:'
	error_echo "========================================================================================="
	crontab -l
	error_echo "========================================================================================="
}

# Fixup hostname, /etc/hostname & /etc/hosts with new hostname
hostname_fix(){
	local LOLDHOSTNAME="$1"
	local LNEWHOSTNAME="$2"
	
	local LCONFFILE='/etc/hostname'
	local LHOSTSFILE='/etc/hosts'
	
	if [ ! -z "$(which hostnamectl 2>/dev/null)" ]; then
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

# Check the hostname, prompt for a new name if not LCxx-----
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
	if [ "$(hostname | grep -c -E '^LC[0-9]{2}.*$')" -lt 1 ]; then
		error_echo "========================================================================================="
		error_echo "WARNING: The hostname of this system does not begin with 'LCnn'."
	fi
	
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

#------------------------------------------------------------------------------
# banner_display() -- Script banner and warnings..
#------------------------------------------------------------------------------
banner_display(){
	SERVICE_TYPE=
	if [ $USE_UPSTART -gt 0 ]; then
		SERVICE_TYPE='upstart'
	elif [ $USE_SYSTEMD -gt 0 ]; then
		SERVICE_TYPE='systemd'
	else
		SERVICE_TYPE='sysv'
	fi

	#~ LCWA_REPO
	#~ LCWA_REPO_BRANCH
	#~ LCWA_LOCALREPO


	error_echo "========================================================================================="
	if [ $UNINSTALL -gt 0 ]; then
		echo "This script REMOVES the ${LCWA_DESC} \"${INST_NAME}\" ${SERVICE_TYPE} service,"
		echo "running under the \"${INST_USER}\" system account."
		echo ' '

		if [ $KEEPLOCALREPO -gt 0 ]; then
			echo "The local repo at ${LCWA_LOCALREPO} will be RETAINED."
		else
			echo "The local repo at ${LCWA_LOCALREPO} WILL BE DELETED."
		fi

		echo ' '

		if [ $KEEPLOCALDATA -gt 0 ]; then
			echo "The data dir /var/lib/${INST_NAME}_data and logs at /var/log/${INST_NAME}_log"
			echo "will be RETAINED along with the ${INST_USER} account."
		else
			echo "The data dir /var/lib/${INST_NAME}_data and logs at /var/log/${INST_NAME}_log"
			echo "WILL BE DELETED along with the ${INST_USER} account."
		fi

	else
		echo "This script installs the ${LCWA_DESC} as the ${SERVICE_TYPE} controlled"
		echo "\"${INST_NAME}\" service, running under the \"${INST_USER}\" system account."
		echo ' '
		echo "The source for the git clone will be \"${LCWA_REPO}\"."
		echo ' '
		echo "The destination for the ${LCWA_REPO_BRANCH} code will be \"${LCWA_LOCALREPO}\"."
	fi
	echo ' '
	echo ' '
	if [ $NO_PAUSE -lt 1 ]; then
		pause 'Press Enter to continue, or ctrl-c to abort..'
	fi
}


#------------------------------------------------------------------------------
# finish()
#------------------------------------------------------------------------------
finish_display(){
	# Start the service..
	#service $INSTNAME start
	error_echo "========================================================================================="
	echo "Done. ${INST_DESC} is ready to run as a service (daemon)."
	echo ' '
	if [ $USE_UPSTART -gt 0 ]; then
		CMD="initctl start ${INST_NAME}"
	elif [ $USE_SYSTEMD -gt 0 ]; then
		CMD="systemctl start ${INST_NAME}.service"
	else
		CMD="service ${INST_NAME} start"
	fi

	if [[ $USE_UPSTART -gt 0 ]] || [[ $USE_SYSTEMD -gt 0 ]]; then
		echo "Run the command \"${CMD}\" to start the service."
		echo ' '
		echo "Run the command \"${LCWA_DEBUG_SCRIPT}\" to start the service"
		echo "in debugging mode.  Check the ${LCWA_LOGDIR}/${INST_NAME}-debug.log"
		echo "file for messages."
		echo ' '
		echo "To update the local git repo with the latest channges from"
		echo "${LCWA_REPO}, run the command:"
		echo ' '
		echo "${LCWA_UPDATE_SCRIPT}"
		echo ' '
	else
		echo "Run the command \"service ${INST_NAME} start\" to start the service."
		echo ' '
		echo "Run the command \"service ${INST_NAME} update\" to update ${LCWA_LOCALREPO} from ${LCWA_REPO}."
		echo ' '
	fi
	echo ' '
	echo 'Enjoy!'
}


######################################################################################################
# rclocal_create() Create the /etc/rc.local file to check the subnet 
######################################################################################################

rclocal_create(){
	local RCLOCAL='/etc/rc.local'
	
	if [ -f "$RCLOCAL" ]; then
		if [ ! -f "${RCLOCAL}.org" ]; then
			cp -p "$RCLOCAL" "${RCLOCAL}.org"
		fi
	cp -p "$RCLOCAL" "${RCLOCAL}.bak"
	fi

	error_echo "Creating ${RCLOCAL}.."


cat >"$RCLOCAL" <<CONF1;
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

########################################################################################
# ALWAYS fix the /tmp directory
########################################################################################
chmod 1777 /tmp

########################################################################################
#
# Check the current network connection. If the subnet has changed, reconfigure the
# firewall.
#
########################################################################################

/usr/local/sbin/chkfw.sh --verbose --minimal

exit 0

exit 0
CONF1

	chmod 755 "$RCLOCAL"
	
	#~ cp -pf "$SCRIPT_DIR}/scripts/chkfw.sh" /usr/local/sbin
	#~ chmod 755 /usr/local/sbin/chkfw.sh
	
}

admin_user_create(){
	
	local LUSER='admin'
	
	# LPASS=$(echo 'password' | mkpasswd --method=SHA-256 --stdin)
	local LPASS='$5$jlzsQDl3$0BluL5unkMKULkYRugwqFpuMQ7g.VUi.EE1rTizFTfA'
	
	is_user "$LUSER"
	
	if [ $? -gt 0 ]; then
		error_echo "Creating user ${LUSER} and adding them to the sudo group.."
		
		if [ $IS_DEBIAN -gt 0 ]; then
			adduser --disabled-password --gecos "" "$LUSER"
			usermod -aG sudo "$LUSER"
			echo "${LUSER}:${LPASS}" | chpasswd --encrypted
		else
			# For Fedora, use a different encryption method for useradd password..
			#~ LPASS=$(openssl passwd -1 'password')
			LPASS='$1$d195eGhJ$Y4se8E/44F0.KBMzkg0pX1'
			useradd --create-home --shell "$(which bash 2>/dev/null)" --user-group --groups sudo --password "$LPASS" "$LUSER"
		fi
	fi
	
}

systemd_set_tz(){
	# Check the timezone we're set to..
	TIMEDATECTL="$(which timedatectl 2>/dev/null)"

	if [ ! -z "$TIMEDATECTL" ]; then
		SYSTZ="$(timedatectl status | grep 'zone:' | sed -n -e 's/^.*: \(.*\) (.*$/\1/p')"
		MYTZ="$(timezone_get)"
		if [ "$MYTZ" != "$SYSTZ" ]; then
			error_echo "Resetting local time zone from UTC to ${MYTZ}.."
			timedatectl set-timezone "$MYTZ"
			timedatectl status
		else
			error_echo "Confirming local timezone as: ${SYSTZ}.."
		fi
	fi
}



########################################################################################
# config_failsafe_firewall() -- make sure every interface at least has port 22 open for ssh
########################################################################################
config_failsafe_firewall(){
	local LIFACE=
	local LIPADDR=
	local LPORT=
	
	local UDP_FAILSAFE_PORTS=(67 68)
	local TCP_FAILSAFE_PORTS=(22)
	
	for LIFACE in $(ifaces_get)
	do
		LIPADDR="$(iface_ipaddress_get "$LIFACE")"
		
		error_echo "Configuring failsafe firewall for ${LIFACE} ${LIPADDR}"
		
		for LPORT in "${UDP_FAILSAFE_PORTS[@]}"
		do
			#~ iface_firewall_open_port "$LIPADDR" "udp" "$LPORT"
			ipaddr_firewall_open_port "$LIPADDR" "udp" "$LPORT"
		done

		for LPORT in "${TCP_FAILSAFE_PORTS[@]}"
		do
			#~ iface_firewall_open_port "$IFACE" "tcp" "$LPORT"
			ipaddr_firewall_open_port "$LIPADDR" "tcp" "$LPORT"
		done
	
	done
	return 0
}

firewall_disable(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	error_echo "Disabling firewall.."
	if [ $USE_FIREWALLD -gt 0 ]; then
		systemctl stop firewalld
	elif [ $USE_UFW -gt 0 ]; then
		ufw disable
	fi
}

firewall_enable(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	error_echo "Enabling firewall.."
	if [ $USE_FIREWALLD -gt 0 ]; then
		systemctl start firewalld
		return 0
	elif [ $USE_UFW -gt 0 ]; then
		echo y | ufw enable
		ufw status verbose
	fi
}

# firewall_set_default() Resets the system firewall to all incoming ports closed
########################################################################################
firewall_set_default(){
	[ $DEBUG -gt 0 ] && error_echo "${FUNCNAME} $@"
	error_echo "Setting firewall to defaults.."
	#~ apt_install ufw
	firewall_disable
	
	# Don't wipe out any previous ufw settings..
	#~ if [ $USE_FIREWALLD -gt 0 ]; then
		#~ # Don't know how to do this with firewalld.
		#~ # Just remove all files from /etc/firewalld/zones & reload & restart firewalld?
		#~ # See: https://bugzilla.redhat.com/show_bug.cgi?id=1531545
		#~ firewall-cmd --reload
	#~ elif [ $USE_UFW -gt 0 ]; then
		#~ ufw --force reset
		#~ ufw default deny incoming
		#~ ufw default allow outgoing
	#~ fi
	
	config_failsafe_firewall
	
	firewall_enable

}

# change the default pi user's password to Andi's preferred password
rpi_user_chpasswd(){
	local LUSER='pi'
	
	# LPASS=$(echo 'password' | mkpasswd --method=SHA-256 --stdin)
	local LPASS='$5$rGd8cYfswkEV$1nWCsvXeJELc0jku641BBmCQOKwZ8U0v59PIC1oEAE2'
	
	is_user "$LUSER"

	# If pi user exists..
	if [ $? -lt 1 ]; then
		echo "${LUSER}:${LPASS}" | chpasswd --encrypted
	fi
	
}

# from raspi-config
rpi_do_change_locale() {
	local LOCALE="$1"
	if ! LOCALE_LINE="$(grep "^$LOCALE " /usr/share/i18n/SUPPORTED)"; then
		return 1
	fi
	local ENCODING="$(echo $LOCALE_LINE | cut -f2 -d " ")"
	echo "$LOCALE $ENCODING" > /etc/locale.gen
	sed -i "s/^\s*LANG=\S*/LANG=$LOCALE/" /etc/default/locale
	dpkg-reconfigure -f noninteractive locales
}

rpi_locale_set(){
	
	#~ en_US.UTF-8 UTF-8
	rpi_do_change_locale 'en_US.UTF-8'
	
}


#~ # KEYBOARD CONFIGURATION FILE

#~ # Consult the keyboard(5) manual page.

#~ XKBMODEL="pc101"
#~ XKBLAYOUT="us"
#~ XKBVARIANT=""
#~ XKBOPTIONS=""

#~ BACKSPACE="guess"

rpi_do_configure_keyboard() {
	local MODEL="$1"
	local KEYMAP="$2"
	#~ dpkg-reconfigure keyboard-configuration
	sed -i /etc/default/keyboard -e "s/^XKBMODEL.*/XKBMODEL=\"$MODEL\"/"
	sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$KEYMAP\"/"
	dpkg-reconfigure -f noninteractive keyboard-configuration
	invoke-rc.d keyboard-setup start
	setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1'
	udevadm trigger --subsystem-match=input --action=change
	return 0
}

rpi_keyboard_set(){
	rpi_do_configure_keyboard "pc101" "us"
}

list_wlan_interfaces() {
	for dir in /sys/class/net/*/wireless; do
		if [ -d "$dir" ]; then
			basename "$(dirname "$dir")"
		fi
	done
}

rpi_do_wifi_country() {
	local COUNTRY=$1
	local IFACE="$(list_wlan_interfaces | head -n 1)"
	
	if [ -z "$IFACE" ]; then
		error_echo "No wireless interface found" 
		return 1
	fi

	if ! wpa_cli -i "$IFACE" status > /dev/null 2>&1; then
		error_echo "Could not communicate with wpa_supplicant"
		return 1
	fi

	wpa_cli -i "$IFACE" set country "$COUNTRY"
	wpa_cli -i "$IFACE" save_config > /dev/null 2>&1

	if ! iw reg set "$COUNTRY" 2> /dev/null; then
		ASK_TO_REBOOT=1
	fi

	if hash rfkill 2> /dev/null; then
		rfkill unblock wifi
	fi
	
	error_echo "Wireless LAN country set to $COUNTRY"
}


rpi_wlan_country_set(){
	rpi_do_wifi_country "US"
}

# Fixups for Raspberry Pi Raspbian GNU/Linux 10 (buster) systems
rpi_fixups(){
	local IS_RPI=0
	
	if [ -z "$(which lsb_release 2>/dev/null)" ]; then
		return 1
	fi

	#Raspbian GNU/Linux 10 (buster)
	IS_RPI=$(lsb_release -sd | grep -c 'Raspbian')
	
	if [ $IS_RPI -lt 1 ]; then
		return 1
	fi
	
	# This system is a Raspberry Pi running Raspbian.  Fix some things..
	error_echo "========================================================================================="
	error_echo "Making Raspberry Pi-specific system settings.."
	
	# Reset the system timezone from GMT to local
	systemd_set_tz
	
	# Set the locale
	rpi_locale_set
	
	# Configure the keyboard
	rpi_keyboard_set
	
	# Set the wifi interface country code
	rpi_wlan_country_set
	
	# Configure ufw to allow DHCP/BOOTP & SSH
	firewall_set_default
	
	# Change the default pi user password
	rpi_user_chpasswd
	
	# Make sure the cron daemon is enabled
	systemctl enable cron
	
	# Make sure the ssh daemon is enabled and started..
	systemctl enable ssh
	systemctl restart ssh

}


######################################################################################################
# main()
######################################################################################################

# args to handle: help debug verbose quiet uninstall/remove disable enable branch user name



#~ LCWA_SERVICE="lcwa-speed"
#~ LCWA_PRODUCT="Andi Klein's Python LCWA PPPoE Speedtest Logger"
#~ LCWA_USER="lcwa-speed"
#~ LCWA_GROUP="nogroup"
#~ LCWA_REPO='https://github.com/pabloemma/LCWA.git'
#~ LCWA_REPO='https://github.com/gharris999/LCWA.git'

#~ LCWA_DESC="LCWA PPPoE Speedtest Logger git code Daemon"
#~ LCWA_LOCALREPO="/usr/local/share/lcwa-speed"
#~ LCWA_DAEMON="/usr/local/share/lcwa-speed/src/test_speed1_3.py"

#~ LCWA_LOGGERID="LC05"											# Prefix that identifies this speedtest logger
#~ LCWA_TESTFREQ=10												# time between succssive speedtests in minutes
#~ LCWA_DB_KEYFILE="/etc/lcwa-speed/LCWA_d.txt"				# Key file for shared dropbox folder for posting results
#~ LCWA_OKLA_SRVRID=18002										# Okla speedtest server ID: 18002 == CyberMesa
#~ LCWA_DATADIR="/var/lib/lcwa-speed/speedfiles"				# Local storage dir for our CSV data

#~ LCWA_DEBUG="/usr/local/sbin/lcwa-speed-debug.sh"
#~ LCWA_UPDATE="/usr/local/sbin/lcwa-speed-update.sh"
#~ LCWA_PIDFILE="/var/run/lcwa-speed/lcwa-speed.pid"
#~ LCWA_LOGDIR="/var/log/lcwa-speed"
#~ LCWA_VCLOG="/var/log/lcwa-speed/git.log"
#~ LCWA_NICE=-19
#~ LCWA_RTPRIO=45
#~ LCWA_MEMLOCK=infinity
#~ LCWA_CLEARLOG=1
#~ PYTHONPATH=/usr/local/lib/python2.7/site-packages
#~ HOME="/var/lib/lcwa-speed"




echo "${INST_DESC} setup:"

SHORTARGS='hdvq'
LONGARGS="help,
debug,
nodebug,
test,
no-test,
verbose,
quiet,
force,
env-lock,
no-host-change,
no-host-check,
python2,
python3,
no-pause,
all,allrevs,all-revs,
lite,newest,newest-only,
recheckout,re-checkout,checkout,co,co-only,
uninstall,remove,remove-all,
keep,keeplocal,keep-local,
nokeep,no-keep,
keeprepo,keep-repo,
keepdata,keep-data,
clean,force,
noclean,keep,keep-repo,
disable,
enable,
update,
update-deps,
high,rtprio
normal,no-rtprio
name:,service:,service-name:,
desc:,description:,service-desc:,
user:,group:,
source:,
options:,
sysv,upstart,systemd"

# Remove line-feeds..
LONGARGS="$(echo "$LONGARGS" | sed ':a;N;$!ba;s/\n//g')"

ARGS=$(getopt -o "$SHORTARGS" -l "$LONGARGS"  -n "$(basename $0)" -- "$@")

eval set -- "$ARGS"

if [ $DEBUG -gt 0 ]; then
	echo "$(basename $0) called with: $*"
	pause 'Press any key to continue..'
	echo "ARGS == ${ARGS}"
fi


while [ $# -gt 0 ]; do

	case "$1" in
		--)
			;;
		-h|--help)
			echo "${SCRIPTNAME} [--service new-service-name] [--desc \"description text\"]"
			echo "                          [--user service-account] [--source repo-url] [--branch branch]"
			echo "                          [--noclean] [--noupdate] [--no-pause]"
			echo "                          [--re-checkout]"
			echo "                          [--uninstall] [--keep-local] [--keep-repo]"
			echo "                          [--sysv | --systemd | --upstart]"
			exit 0
			;;
		-d|--debug)
			DEBUG=1
			;;
		--test)
			TEST_MODE=1
			;;
		--no-test)
			TEST_MODE=0
			;;
		-v|--verbose)
			VERBOSE=1
			;;
		-q|--quiet)
			QUIET=1
			;;
		--force)
			FORCE=1
			;;
		--no-pause)
			NO_PAUSE=1
			;;
		--env-lock)
			INST_ENVFILE_LOCK=1
			;;
		--no-host-change|--no-host-check)
			NO_HOSTNAME_CHANGE=1
			;;
		--all|--allrevs|--all-revs)
			ALLREVS=1
			;;
		--lite|--newest|--newest-only)
			ALLREVS=0
			;;
		--recheckout|--re-checkout|--checkout|--co|--co-only)
			CHECKOUT_ONLY=1
			;;
		--uninstall|--remove)
			UNINSTALL=1
			;;
		--remove-all)
			UNINSTALL=1
			REMOVEALL=1
			;;
		--keep|--keeplocal|--keep-local)
			KEEPLOCALDATA=1
			KEEPLOCALREPO=1
			;;
		--nokeep|--no-keep)
			KEEPLOCALDATA=0
			KEEPLOCALREPO=0
			;;
		--keeprepo|--keep-repo)
			KEEPLOCALREPO=1
			;;
		--keepdata|--keep-data)
			KEEPLOCALDATA=1
			;;
		--disable)
			DISABLE=1
			;;
		--enable)
			ENABLE=1
			;;
		--update)
			UPDATE=1
			;;
		--update-deps)
			UPDATE_DEPS=1
			;;
		--user|--instuser|--inst-user)
			shift
			INST_USER="$1"
			LCWA_USER="$1"
			;;
		--group|--instgroup|--inst-group)
			shift
			INST_GROUP="$1"
			LCWA_GROUP="$1"
			;;
		--high|--rtprio)
			NEEDSPRIORITY=1
			;;
		--normal|--no-rtprio)
			NEEDSPRIORITY=0
			;;
		--name|--service|--service-name)
			shift
			INST_NAME="$1"
			LCWA_SERVICE="$1"
			;;
		--desc|--description|--service-desc)
			shift
			INST_DESC="$1"
			LCWA_DESC="$1"
			;;
		--source)
			shift
			LCWA_REPO="$1"
			;;
		--options)
			shift
			LCWA_OPTIONS="$1"
			;;
		--upstart)
			# Force use of an upstart conf file for the service..
			USE_UPSTART=1
			USE_SYSTEMD=0
			USE_SYSV=0
			;;
		--systemd)
			# Force use of a systemd unit file for the service..
			USE_UPSTART=0
			USE_SYSTEMD=1
			USE_SYSV=0
			;;
		--sysv)
			# Force use if a sysv init.d script for the service..
			USE_UPSTART=0
			USE_SYSTEMD=0
			USE_SYSV=1
			;;
		--python2)
			FORCE_PYTHON3=0
			;;
		--python3)
			FORCE_PYTHON3=1
			;;
		*)
			echo "What do you mean by ${1}?"
			exit 1
			;;
   esac
   shift
done

############################################################################################################
if [ $DEBUG -gt 0 ]; then

	echo "IS_DEBIAN == ${IS_DEBIAN}"
	echo ' '
	echo "IS_UPSTART == ${IS_UPSTART}"
	echo "USE_UPSTART == ${USE_UPSTART}"
	echo ' '
	echo "IS_SYSTEMD == ${IS_SYSTEMD}"
	echo "USE_SYSTEMD == ${USE_SYSTEMD}"
	echo ' '

	env_vars_show
fi


if [ $DISABLE -gt 0 ]; then

	service_disable

elif [ $ENABLE -gt 0 ]; then

	service_enable

########################################################################################
# Checkout
elif [ $CHECKOUT_ONLY -gt 0 ]; then

	service_stop

	# Remove the local repos..
	git_repo_remove "$LCWA_LOCALREPO"
	git_repo_remove "$LCWA_LOCALSUPREPO"
	
	# Check and install or update the main repo..
	git_repo_create "$LCWA_REPO" "$LCWA_REPO_BRANCH" "$LCWA_LOCALREPO"
	
	# Check and install the suppliment repo..
	git_repo_create "$LCWA_SUPREPO" "$LCWA_SUPREPO_BRANCH" "$LCWA_LOCALSUPREPO"

	service_start
	service_status
	

########################################################################################
# Update
elif [ $UPDATE -gt 0 ]; then

	# Get our default env var values
	env_vars_defaults_get

	if [ $FORCE -lt 1 ]; then
		service_is_installed
		if [ $? -lt 1 ]; then
			error_exit "${INST_NAME} is not installed.  Cannot update ${INST_NAME}.."
		fi
	fi
	
	service_stop
	service_disable

	env_file_create $(env_vars_name)
	env_file_read
	
	if [ $UPDATE_DEPS -gt 0 ]; then
		#~ ookla_speedtest_install
		#~ ookla_license_install
		pkg_deps_install
		python_libs_install
	fi
	
	data_dir_update
	log_dir_update
	
	# Create the log rotate scripts
	log_rotate_script_create "$LCWA_LOGFILE"
	log_rotate_script_create "$LCWA_ERRFILE"
	log_rotate_script_create "$LCWA_VCLOG"
	
	# Check and install or update the main repo..
	git_repo_create "$LCWA_REPO" "$LCWA_REPO_BRANCH" "$LCWA_LOCALREPO"
	
	# Check and install the suppliment repo..
	git_repo_create "$LCWA_SUPREPO" "$LCWA_SUPREPO_BRANCH" "$LCWA_LOCALSUPREPO"
	
	# Create the service init script
	service_priority_set
	
	if [ $USE_UPSTART -gt 0 ]; then
		upstart_conf_file_create_nopid "$LCWA_EXEC_ARGS"
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_unit_file_create "$LCWA_EXEC_ARGS"
		systemd_unit_file_pidfile_remove		
		systemd_unit_file_logto_set "$LCWA_LOGFILE" "$LCWA_ERRFILE"
	else
		service_create "$LCWA_EXEC_ARGS"
	fi
	
	# Install the startup debugging & update scripts
	script_debug_install
	script_update_install
	
	HOME="$CUR_HOME"

	# Configure root crontab to update the git repo and restart the service at 12:05 am..
	crontab_entry_add
	
	# Create a /etc/rc.local file to reconfigure the firewall when the subnet changes..
	[ $IS_FEDORA -lt 1 ] && rclocal_create
	
	# Create a LCWA admin user with cannonical password
	admin_user_create

	service_enable
	service_start
	service_status
	[ $NO_HOSTNAME_CHANGE -lt 1 ] && hostname_check

########################################################################################
# UNINSTALL
elif [ $UNINSTALL -gt 0 ]; then

	env_file_read
	if [ $? -gt 0 ]; then
		# Get defaults if the env file has already been removed..
		env_vars_defaults_get
	fi

	if [ $FORCE -lt 1 ]; then
		service_is_installed

		if [ $? -lt 1 ]; then
			error_exit "${INST_NAME} is not installed.  Cannot remove ${INST_NAME}.."
		fi
	else
		banner_display
	fi


	HOME="$CUR_HOME"

	service_stop

	service_disable
	service_remove
	sysv_init_file_remove

	script_debug_remove
	script_update_remove
	
	log_rotate_script_remove "$LCWA_LOGFILE"
	log_rotate_script_remove "$LCWA_ERRFILE"
	log_rotate_script_remove "$LCWA_VCLOG"

	pid_dir_remove
	env_file_remove
	crontab_entry_remove

	# Remove the git repo
	if [ $KEEPLOCALREPO -lt 1 ]; then
		git_repo_remove "$LCWA_LOCALREPO"
		git_repo_remove "$LCWA_LOCALSUPREPO"
		#~ inst_dir_remove "$LCWA_LOCALREPO"
	fi

	# Remove the local data..
	if [ $KEEPLOCALDATA -lt 1 ]; then
		conf_dir_remove
		ookla_speedtest_remove
		ookla_license_remove
		data_dir_remove
		log_dir_remove
		inst_user_remove
		python_libs_remove
		pkg_deps_remove
	fi

	echo "${INST_NAME} is uninstalled."
	exit 1

########################################################################################
# INSTALL
else
	service_is_installed

	# Get our default env var values
	env_vars_defaults_get

	banner_display

	if [ $? -gt 0 ]; then
		service_stop
	fi
	
	# Check the hostname and change it if necessary..
	[ $NO_HOSTNAME_CHANGE -lt 1 ] && hostname_check
	
	# Check the timezone..
	systemd_set_tz
	
	# Fixup RPi specifics..
	rpi_fixups

	# Create the service account
	inst_user_create

	# Create the default file
	env_file_create $(env_vars_name)

	# Install the db_key file
	conf_file_create
	db_keyfile_install

	# Install dependencies
	ookla_speedtest_install
	ookla_license_install
	pkg_deps_install
	python_libs_install

	# Check and install or update the main repo..
	git_repo_create "$LCWA_REPO" "$LCWA_REPO_BRANCH" "$LCWA_LOCALREPO"
	
	# Check and install the suppliment repo..
	git_repo_create "$LCWA_SUPREPO" "$LCWA_SUPREPO_BRANCH" "$LCWA_LOCALSUPREPO"

	HOME="$CUR_HOME"

	# Create the PID directory..
	#~ pid_dir_create 'd' "$INST_NAME" '0750' "$INST_USER" "$INST_GROUP" '10d'

	# Create a data dir
	data_dir_create

	erro_echo "Fixing permissions in /var/lib/${INST_NAME}"
	chown -R "${INST_USER}:${INST_GROUP}" "/var/lib/${INST_NAME}"

	# Create a log dir
	log_dir_create
	
	for LOG in "$LCWA_LOGFILE" "$LCWA_ERRFILE" "$LCWA_VCLOG"
	do
		touch "$LOG"
	done

	error_echo "Fixing permissions in /var/log/${INST_NAME}"
	chown -R "${INST_USER}:${INST_GROUP}" "/var/log/${INST_NAME}"

	# Create the log rotate scripts
	log_rotate_script_create "$LCWA_LOGFILE"
	log_rotate_script_create "$LCWA_ERRFILE"
	log_rotate_script_create "$LCWA_VCLOG"

	# Create the service init script
	if [ $USE_UPSTART -gt 0 ]; then
		upstart_conf_file_create_nopid "$LCWA_EXEC_ARGS"
	elif [ $USE_SYSTEMD -gt 0 ]; then
		systemd_unit_file_create "$LCWA_EXEC_ARGS"
		systemd_unit_file_pidfile_remove		
		systemd_unit_file_logto_set "$LCWA_LOGFILE" "/var/log/${INST_NAME}/${INST_NAME}-error.log"
	else
		service_create "$LCWA_EXEC_ARGS"
	fi

	# Install the startup debugging & update scripts
	script_debug_install
	script_update_install

	# Create the service control links..
	service_enable

	# Configure root crontab to update the git repo and restart the service at 12:05 am..
	crontab_entry_add

	# Create a /etc/rc.local file to reconfigure the firewall when the subnet changes..
	[ $IS_FEDORA -lt 1 ] && rclocal_create
	
	# Create a LCWA admin user with cannonical password
	admin_user_create

	service_start
	service_status

	finish_display
	
	#Final warning if the hostname isn't LCXX
	[ $NO_HOSTNAME_CHANGE -lt 1 ] && hostname_check
fi

exit 0
