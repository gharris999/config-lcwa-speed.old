#!/bin/bash

######################################################################################################
# Bash script for installing Andi Klein's Python LCWA PPPoE Speedtest Logger 
# as a service on systemd, upstart & sysv systems
######################################################################################################
REQINCSCRIPTVER=20200422

INCLUDE_FILE="$(dirname $(readlink -f $0))/instsrv_functions.sh"
[ ! -f "$INCLUDE_FILE" ] && INCLUDE_FILE='/usr/local/sbin/instsrv_functions.sh'

. "$INCLUDE_FILE"

if [[ -z "$INCSCRIPTVER" ]] || [[ $INCSCRIPTVER -lt $REQINCSCRIPTVER ]]; then
	error_exit "Version ${REQINCSCRIPTVER} of ${INCLUDE_FILE} required."
fi

SCRIPTNAME=$(basename $0)
is_root

HAS_PYTHON2=0
[ ! -z "$(which python2)" ] && HAS_PYTHON2=1


NOPROMPT=0
QUIET=0
DEBUG=0
UPDATE=0
NO_PAUSE=0
FORCE=0
NO_SCAN=0
TEST_MODE=0
FORCE_PYTHON3=1

NEEDSUSER=1
NEEDSCONF=1
NEEDSDATA=1
NEEDSLOG=1
NEEDSPRIORITY=1
NEEDSPID=0

CUR_HOME="$HOME"

######################################################################################################
# Vars specific to this service install
######################################################################################################

# Download all revisions, not just most recent..
# All-revs are necessary in order to switch between branches..
ALLREVS=0

# Delete old local repo and re-checkout
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
INST_BIN="$(which python3) /usr/local/share/${INST_NAME}/src/test_speed1_3.py"

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

#~ LCWA_SERVICE="$INST_NAME"
#~ LCWA_PRODUCT="$INST_PROD"
#~ LCWA_PRODUCTID="f1a4af09-977c-458a-b3f7-f530fb9029c1"
#~ LCWA_VERSION="20200504.110908"
#~ LCWA_USER="$INST_USER"
#~ LCWA_GROUP=
#~ LCWA_REPO='https://github.com/pabloemma/LCWA.git'
#~ LCWA_REPO='https://github.com/gharris999/LCWA.git'

#~ LCWA_DESC="$INST_DESC"
#~ LCWA_LOCALREPO="/usr/local/share/${LCWA_SERVICE}"
#~ LCWA_DAEMON="${LOCALREPO}/src/test_speed1.py"

#~ LCWA_LOGGERID="UB01"											# Prefix that identifies this speedtest logger
#~ LCWA_TESTFREQ=10												# time between succssive speedtests in minutes
#~ LCWA_DB_KEYFILE="/etc/${INST_NAME}/LCWA_d.txt"				# Key file for shared dropbox folder for posting results
#~ LCWA_OKLA_SRVRID=18002										# Okla speedtest server ID: 18002 == CyberMesa
#~ LCWA_DATADIR="/var/lib/${INST_NAME}/speedfiles"				# Local storage dir for our CSV data




#~ LCWA_DEBUG="/usr/local/sbin/${INST_NAME}-debug.sh"
#~ LCWA_UPDATE="/usr/local/sbin/${INST_NAME}-update.sh"
#~ LCWA_PIDFILE="/var/run/${INST_NAME}/${INST_NAME}.pid"
#~ LCWA_LOGDIR="/var/log/${INST_NAME}"
#~ LCWA_DATADIR="/var/lib/${INST_NAME}"
#~ LCWA_LOGFILE="/var/log/${INST_NAME}/${INST_NAME}.log"
#~ LCWA_VCLOG="${LCWA_LOGDIR}/git.log"
#~ LCWA_NICE=-19
#~ LCWA_RTPRIO=45
#~ LCWA_MEMLOCK=infinity
#~ LCWA_CLEARLOG=1
#~ PYTHONPATH=/usr/local/lib/python2.7/site-packages
#~ HOME="/var/lib/${INST_NAME}"

LCWA_SERVICE=
LCWA_PRODUCT=
LCWA_PRODUCTID=
LCWA_VERSION=
LCWA_USER=
LCWA_GROUP=
LCWA_REPO=
LCWA_DESC=
LCWA_LOCALREPO=
LCWA_DAEMON=
LCWA_OPTIONS=
LCWA_LOGGERID=
LCWA_TESTFREQ=
LCWA_DB_KEYFILE=
LCWA_OKLA_SRVRID=
LCWA_DEBUG=
LCWA_UPDATE=
LCWA_PIDFILE=
LCWA_DATADIR=
LCWA_LOGDIR=
LCWA_LOGFILE=
LCWA_VCLOG=
LCWA_NICE=
LCWA_RTPRIO=
LCWA_MEMLOCK=
LCWA_CLEARLOG=
#~ PYTHONPATH=



env_vars_name(){
	echo "LCWA_SERVICE" \
"LCWA_PRODUCT" \
"LCWA_PRODUCTID" \
"LCWA_VERSION" \
"LCWA_USER" \
"LCWA_GROUP" \
"LCWA_REPO" \
"LCWA_DESC" \
"LCWA_LOCALREPO" \
"LCWA_DAEMON" \
"LCWA_OPTIONS" \
"LCWA_LOGGERID" \
"LCWA_TESTFREQ" \
"LCWA_DB_KEYFILE" \
"LCWA_OKLA_SRVRID" \
"LCWA_DEBUG" \
"LCWA_UPDATE" \
"LCWA_PIDFILE" \
"LCWA_DATADIR" \
"LCWA_LOGDIR" \
"LCWA_LOGFILE" \
"LCWA_VCLOG" \
"LCWA_NICE" \
"LCWA_RTPRIO" \
"LCWA_MEMLOCK" \
"LCWA_CLEARLOG" \
"LCWA_EXEC_ARGS" \
"LCWA_EXEC_ARGS_DEBUG" \
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
	[ -z "$LCWA_USER" ] 			&& LCWA_USER="$INST_USER"
	[ -z "$LCWA_GROUP" ] 			&& LCWA_GROUP="$INST_GROUP"

	[ -z "$LCWA_REPO" ] 			&& LCWA_REPO='https://github.com/pabloemma/LCWA.git'
	#~ [ -z "$LCWA_REPO" ] 			&& LCWA_REPO='https://github.com/gharris999/LCWA.git'

	[ -z "$LCWA_DESC" ] 			&& LCWA_DESC="${LCWA_PRODUCT}-TEST Logger"
	[ -z "$LCWA_LOCALREPO" ] 		&& LCWA_LOCALREPO="$INST_PATH"
	[ -z "$LCWA_DAEMON" ] 			&& LCWA_DAEMON="$INST_BIN"
	
	[ -z "$LCWA_LOGGERID" ] 		&& LCWA_LOGGERID="$(hostname | cut -c1-4)"
	[ -z "$LCWA_TESTFREQ" ]			&& LCWA_TESTFREQ='10'
	[ -z "$LCWA_DB_KEYFILE" ]		&& LCWA_DB_KEYFILE="/etc/${INST_NAME}/LCWA_d.txt"
	[ -z "$LCWA_OKLA_SRVRID" ]		&& LCWA_OKLA_SRVRID='18002'

	[ -z "$LCWA_DEBUG" ]			&& LCWA_DEBUG="/usr/local/sbin/${INST_NAME}-debug.sh"
	[ -z "$LCWA_UPDATE" ]			&& LCWA_UPDATE="/usr/local/sbin/${INST_NAME}-update.sh"
	
	[ -z "$LCWA_DATADIR" ] 			&& LCWA_DATADIR="/var/lib/${INST_NAME}/speedfiles"
	[ -z "$LCWA_LOGDIR" ] 			&& LCWA_LOGDIR="/var/log/${INST_NAME}"
	[ -z "$LCWA_LOGFILE" ] 			&& LCWA_LOGFILE="/var/log/${INST_NAME}/${INST_NAME}.log"
	[ -z "$LCWA_VCLOG" ] 			&& LCWA_VCLOG="${LCWA_LOGDIR}/git.log"
	[ -z "$LCWA_NICE" ] 			&& LCWA_NICE="$INST_NICE"
	[ -z "$LCWA_RTPRIO" ]			&& LCWA_RTPRIO="$INST_RTPRIO"
	[ -z "$LCWA_MEMLOCK" ]			&& LCWA_MEMLOCK="$INST_MEMLOCK"
	[ -z "$LCWA_CLEARLOG" ] 		&& LCWA_CLEARLOG=1
	[ -z "$LCWA_EXEC_ARGS" ] 		&& LCWA_EXEC_ARGS="--time \${LCWA_TESTFREQ} --dpfile \${LCWA_DB_KEYFILE} --serverid \${LCWA_OKLA_SRVRID}"
	[ -z "$LCWA_EXEC_ARGS_DEBUG" ] 	&& LCWA_EXEC_ARGS_DEBUG="--adebug --time \${LCWA_TESTFREQ} --dpfile \${LCWA_DB_KEYFILE} --serverid \${LCWA_OKLA_SRVRID}"

	[ -z "$PYTHONPATH" ] 			&& PYTHONPATH="$(find /usr -type d -name 'site-packages' -exec readlink -f {} \; | head -n 1)"
	
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
	
	if [ -f "$LCWA_DB_KEYFILE" ]; then
		rm -f "$LCWA_DB_KEYFILE"
	fi
	
	error_echo "Creating dropbox key file ${LCWA_DB_KEYFILE} from encrypted source."
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
	
	error_echo "Installing Package Dependencies.." 
	[ $TEST_MODE -lt 1 ] && apt_install gnupg1 \
										espeak \
										dnsutils \
										pulseaudio \
										build-essential \
										git \
										scons \
										swig \
										libffi-dev \
										libffi6 \
										at-spi2-core
	
	return 0
}

pkg_deps_remove(){
	
	error_echo "Uninstalling Package Dependencies.." 
	[ $TEST_MODE -lt 1 ] && apt_uninstall gnupg1 \
										  espeak \
										  pulseaudio \
										  scons \
										  swig \
										  libffi-dev \
										  libffi6 \
										  at-spi2-core
	
	
	return 0
}

############################################################################
# ookla_license_install() -- Runs speedtest under root to generate a
#                            license file, copies it to our data directory.
############################################################################
ookla_license_install(){
	local OOKLA="$(which speedtest)"
	
	local LICENSE_SRC='/root/.config/ookla/speedtest-cli.json'
	local LICENSE_DIR="/var/lib/${INST_NAME}/.config/ookla"
	local LICENSE_FILE="${LICENSE_DIR}/speedtest-cli.json"
	
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
	
	local DEB_DISTRO="$(lsb_release -sc)"
	local APTLIST_FILE='/etc/apt/sources.list.d/speedtest.list'
	
	export INSTALL_KEY=379CE192D401AB61
	export DEB_DISTRO=$(lsb_release -sc)
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
	
	apt_install speedtest
	
}

############################################################################
# ookla_speedtest_remove() -- uninstalls speedtest & removes the apt source
############################################################################
ookla_speedtest_remove(){
	
	local APTLIST_FILE='/etc/apt/sources.list.d/speedtest.list'
	local SPEEDTEST_BIN="$(which speedtest)"
	
	if [ ! -z "$SPEEDTEST_BIN" ]; then
		error_echo "Uninstalling ${SPEEDTEST_BIN}"
		apt remove -y speedtest
		apt autoremove
	fi
	
	if [ -f "$APTLIST_FILE" ]; then
		error_echo "Removing ${APTLIST_FILE} from apt sources.."
		rm -f "$APTLIST_FILE"
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
														python-gi-cairo
		
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
	
		error_echo "Reinstalling python3.." 

		[ $TEST_MODE -lt 1 ] && apt_install --reinstall python3 \
														python3-dev \
														python3-tk \
														python3-gi-cairo
		
		error_echo "Purging python3-pip.." 
		[ $TEST_MODE -lt 1 ] && apt purge -y python3-pip
		
		apt -y autoremove
		
		error_echo "Reinstalling python3-pip direct from Python Packaging Authority.." 
		[ $TEST_MODE -lt 1 ] && wget https://bootstrap.pypa.io/get-pip.py
		[ $TEST_MODE -lt 1 ] && python3 get-pip.py
		[ $TEST_MODE -lt 1 ] && pip3 install --upgrade pip

		error_echo "Installing python dependencies.." 

		[ $TEST_MODE -lt 1 ] && pip3 install --force-reinstall  testresources \
																backports.functools_lru_cache \
																pydig \
																dropbox \
																cairocffi \
																matplotlib
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
		
		error_echo "Installing python dependencies.." 

		#~ [ $TEST_MODE -lt 1 ] && pip3 install --force-reinstall backports.functools_lru_cache \
										#~ dropbox \
										#~ cairocffi \
										#~ matplotlib

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
	INST_PATH="$LCWA_LOCALREPO"
	if [ -d "$INST_PATH" ]; then
		echo "Removing ${INST_PATH}.."
		rm -Rf "$INST_PATH"
	fi

}


#------------------------------------------------------------------------------
# in_repo() -- Check to see we are where we are supposed to be..
#------------------------------------------------------------------------------
in_repo(){
	if [ $(pwd) != "$LCWA_LOCALREPO" ]; then
		echo "Error: Could not find ${LCWA_LOCALREPO}"
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
	if [ ! -d "${LCWA_LOCALREPO}/.git" ]; then
		error_echo "${LCWA_LOCALREPO} does not exist or is not a git repository."
		# local repo does not exist..set return value to create it
		return 10
	fi

	cd "$LCWA_LOCALREPO" && in_repo
	# Get the URL of the fetch origin of the clone..
	THISREPO=$(git remote -v show | grep 'fetch' | sed -n -e 's/^origin *\([^ ]*\).*$/\1/p')
	THISREPO=$(echo "$THISREPO" | sed -e 's/^[[:space:]]*//')
	THISREPO=$(echo "$THISREPO" | sed -e 's/[[:space:]]*$//')

	# We don't care if the source is http:// or git://
	if [ "${THISREPO##*//}" != "${LCWA_REPO##*//}" ]; then
		echo "Error: ${LCWA_LOCALREPO} is not a git repository for ${LCWA_REPO}."
		echo "  git reports ${THISREPO} as the source."
		return 5
	fi

	# Local repo exists & has the right url -- update it..
	return 0
}

#------------------------------------------------------------------------------
# git_repo_show() -- show the status of the local repo
#------------------------------------------------------------------------------
git_repo_show() {
	echo "Getting ${LCWA_LOCALREPO} status.."
	cd "$LCWA_LOCALREPO" && in_repo
	git remote show origin
	echo "Available brances in ${LCWA_LOCALREPO}:"
	git branch -r
	echo "Status of ${LCWA_LOCALREPO}:"
	git status
}


#------------------------------------------------------------------------------
# git_repo_clone() -- Clone the remote repo locally..
#------------------------------------------------------------------------------
git_repo_clone(){
	echo "Cloning ${LCWA_REPO} to ${LCWA_LOCALREPO}.."
	# Cloning to --depth 1 (i.e. only most recent revs) results in a dirsize of
	# about 250M for /usr/share/lms/server
	if [ $ALLREVS -gt 0 ]; then
		git clone "$LCWA_REPO" "$LCWA_LOCALREPO"
	else
		git clone --depth 1 "$LCWA_REPO" "$LCWA_LOCALREPO"
	fi

	if [ $? -gt 0 ]; then
		echo "Error cloning ${LCWA_REPO}...script must halt."
		exit 1
	fi

	cd "$LCWA_LOCALREPO" && in_repo
	git status
}

#------------------------------------------------------------------------------
# git_repo_checkout() -- Check out the desired branch..
#------------------------------------------------------------------------------
git_repo_checkout(){
	echo "Checking out branch ${LCWA_BRANCH} to ${LCWA_LOCALREPO}.."

	cd "$LCWA_LOCALREPO" && in_repo

	#check out the new branch..
	git checkout "$LCWA_BRANCH"

	if [ $? -gt 0 ]; then
		echo "Error checking out branch ${LCWA_BRANCH}."
		git_repo_show
		return 1
	fi
}

#------------------------------------------------------------------------------
# git_repo_clean() -- Discard any local changes from the repo..
#------------------------------------------------------------------------------
git_repo_clean(){
	cd "$LCWA_LOCALREPO" && in_repo
	echo "Cleaning ${LCWA_LOCALREPO}.."
	git reset --hard
	git clean -fd
	if [ $? -gt 0 ]; then
		echo "Error cleaning ${LCWA_LOCALREPO}...script must halt."
		exit 1
	fi
}

#------------------------------------------------------------------------------
# git_repo_update() -- update the git repo
#------------------------------------------------------------------------------
git_repo_update(){
	cd "$LCWA_LOCALREPO" && in_repo
	echo "Updating ${LCWA_LOCALREPO}.."
	git pull
	if [ $? -gt 0 ]; then
		echo "Error updating ${LCWA_LOCALREPO}...script must halt."
		exit 1
	fi
}

#------------------------------------------------------------------------------
# git_repo_update() -- update the git repo
#------------------------------------------------------------------------------
git_repo_remove(){
	if [ -d "$LCWA_LOCALREPO" ]; then
		echo "Removing ${LCWA_LOCALREPO} git local repo.."
		rm -Rf "$LCWA_LOCALREPO"
	fi
}


######################################################################################################
# lcwa_debug_script_create() Create the startup debugging script..
######################################################################################################
script_debug_create(){

	[ -z "$LCWA_DEBUG" ]			&& LCWA_DEBUG="/usr/local/sbin/${INST_NAME}-debug.sh"

    echo "Creating ${LCWA_DEBUG}.."

cat >"$LCWA_DEBUG" <<DEBUG_SCR1;
#!/bin/bash
# lcwa-speed-debug.sh -- script to debug lcwa-speed startup..

DEBUG=1
FORCE=0

USE_UPSTART=0
USE_SYSTEMD=0
USE_SYSV=1

IS_DEBIAN="\$(which apt-get 2>/dev/null | wc -l)"
IS_UPSTART=\$(initctl version 2>/dev/null | egrep -c 'upstart')
IS_SYSTEMD=\$(systemctl --version 2>/dev/null | egrep -c 'systemd')

INST_NAME=

date_msg(){
	DATE=\$(date '+%F %H:%M:%S.%N')
	DATE=\${DATE#??}
	DATE=\${DATE%?????}
	echo "[\${DATE}] \$(basename \$0) (\$\$)" \$@
}

env_file_read(){

	if [ \$IS_DEBIAN -gt 0 ]; then
		INST_ENVFILE="/etc/default/\${INST_NAME}"
	else
		INST_ENVFILE="/etc/sysconfig/\${INST_NAME}"
	fi

	if [ -f "\$INST_ENVFILE" ]; then
		. "\$INST_ENVFILE"
	else
		date_msg "Error: Could not read \${INST_ENVFILE}."
		return 128
	fi
	
	if [ \$DEBUG -gt 0 ]; then
	
		set -o posix ; set | grep 'LCWA_' | sort
	fi
}


########################################################################
########################################################################
########################################################################
# main()
########################################################################
########################################################################
########################################################################

INST_NAME='lcwa-speed'

env_file_read

# Prep the debug log
DEBUG_LOGFILE="\${LCWA_LOGDIR}/\${INST_NAME}-debug.log"
touch "\$DEBUG_LOGFILE"
#~ truncate --size=0 "\$DEBUG_LOGFILE"
date_msg "\$@" >"\$DEBUG_LOGFILE"

# Execute the service..
\$LCWA_DAEMON \$LCWA_EXEC_ARGS_DEBUG 2>&1 | tee -a "\$DEBUG_LOGFILE"


DEBUG_SCR1
chmod 755 "$LCWA_DEBUG"

}

######################################################################################################
# lcwa_debug_script_remove() Remove the startup debugging script..
######################################################################################################
script_debug_remove(){

	[ -z "$LCWA_DEBUG" ]			&& LCWA_DEBUG="/usr/local/sbin/${INST_NAME}-debug.sh"

	if [ -f "$LCWA_DEBUG" ]; then
		echo "Removing ${LCWA_DEBUG}.."
		rm "$LCWA_DEBUG"
	fi

}

######################################################################################################
# lcwa_update_script_create() Create the git/svn update script..
######################################################################################################
script_update_create(){

	[ -z "$LCWA_UPDATE" ]		&& LCWA_UPDATE="/usr/local/sbin/${INST_NAME}-update.sh"

    echo "Creating ${LCWA_UPDATE}.."

cat >"$LCWA_UPDATE" <<UPDATE_SCR1;
#!/bin/bash
# lcwa-speed-update.sh -- script to update lcwa-speed git repo and restart service..
# Version Control for this script
VERSION=20200430.01

SCRIPT="\$(readlink -f "\$0")"
SCRIPT_NAME="\$(basename "\$0")"
DEBUG=0
VERBOSE=0
FORCE=0

SCRIPT_UPDATE=1
SBIN_UPDATE=0
OS_UPDATE=0
REBOOT=0

USE_UPSTART=0
USE_SYSTEMD=0
USE_SYSV=1

IS_DEBIAN="\$(which apt-get 2>/dev/null | wc -l)"
IS_UPSTART=\$(initctl version 2>/dev/null | egrep -c 'upstart')
IS_SYSTEMD=\$(systemctl --version 2>/dev/null | egrep -c 'systemd')

####################################################################################
# Requirements: do we have the utilities needed to get the job done?
TIMEOUT_BIN=\$(which timeout)

if [ -z "\$TIMEOUT_BIN" ]; then
	TIMEOUT_BIN=\$(which gtimeout)
fi

PROC_TIMEOUT=60

# Prefer upstart to systemd if both are installed..
if [ \$IS_UPSTART -gt 0 ]; then
	USE_SYSTEMD=0
	USE_SYSV=0
	USE_UPSTART=1
elif [ \$IS_SYSTEMD -gt 0 ]; then
	USE_SYSTEMD=1
	USE_SYSV=0
	USE_UPSTART=0
fi

psgrep(){
    ps aux | grep -v grep | grep -E \$*
}

error_exit(){
    echo "Error: \$@" 1>&2;
    exit 1
}

error_echo(){
	echo "\$@" 1>&2;
}


date_msg(){
	DATE=\$(date '+%F %H:%M:%S.%N')
	DATE=\${DATE#??}
	DATE=\${DATE%?????}
	echo "[\${DATE}] \${SCRIPT_NAME} (\$\$)" \$@
}

log_msg(){
	error_echo "\$@"
	date_msg "\$@" >> "\$LCWA_VCLOG"
}


########################################################################
# disp_help() -- display the getopts allowable args
########################################################################
disp_help(){
	local EXTRA_ARGS="\$*"
	error_echo "Syntax: \$(basename "\$SCRIPT") \${EXTRA_ARGS} \$(echo "\$SHORTARGS" | sed -e 's/, //g' -e 's/\\(.\\)/[-\\1] /g') \$(echo "[--\${LONGARGS}]" | sed -e 's/,/] [--/g' | sed -e 's/:/=entry/g')" 
}


env_file_read(){

	if [ \$IS_DEBIAN -gt 0 ]; then
		INST_ENVFILE="/etc/default/\${INST_NAME}"
	else
		INST_ENVFILE="/etc/sysconfig/\${INST_NAME}"
	fi

	if [ -f "\$INST_ENVFILE" ]; then
		. "\$INST_ENVFILE"
	else
		log_msg "Error: Could not read \${INST_ENVFILE}."
		return 128
	fi
}

######################################################################################################
# date_epoch_to_iso8601() -- Convert an epoch time to ISO-8601 format in local TZ..
######################################################################################################
date_epoch_to_iso8601(){
	local LEPOCH="\$1"
	echo "\$(date -d "@\${LEPOCH}" --iso-8601=s)"
}

######################################################################################################
# date_epoch_to_iso8601u() -- Convert an epoch time to ISO-8601 format in UTC..
######################################################################################################
date_epoch_to_iso8601u(){
	local LEPOCH="\$1"
	echo "\$(date -u -d "@\${LEPOCH}" --iso-8601=s)"
}

function displaytime {
  local T=\$1
  local D=\$((T/60/60/24))
  local H=\$((T/60/60%24))
  local M=\$((T/60%60))
  local S=\$((T%60))
  (( \$D > 0 )) && printf '%d days ' \$D
  (( \$H > 0 )) && printf '%d hours ' \$H
  (( \$M > 0 )) && printf '%d minutes ' \$M
  (( \$D > 0 || \$H > 0 || \$M > 0 )) && printf 'and '
  printf '%d seconds\\n' \$S
}

script_update(){
	# Get date of ourselves..
	# Get date of file..
	local LURL='http://www.hegardtfoundation.org/slimstuff/Services.zip'
	#~ SCRIPT='/usr/local/sbin/lcwa-speed-update.sh'
	local REMOT_FILEDATE=
	local LOCAL_FILEDATE=
	local REMOT_EPOCH=
	local LOCAL_EPOCH=
	local TEMPFILE=

	log_msg "Checking \${SCRIPT} to see if update of the update is needed.."
	
	# Remote file time here: 5/1/2020 14:01
	REMOT_FILEDATE="\$(curl -s -v -I -X HEAD http://www.hegardtfoundation.org/slimstuff/Services.zip 2>&1 | grep -m1 -E "^Last-Modified:")"
	# Sanitize the filedate, removing tabs, CR, LF
	REMOT_FILEDATE="\$(echo "\${REMOT_FILEDATE//[\$'\\t\\r\\n']}")"
	REMOT_FILEDATE="\$(echo "\$REMOT_FILEDATE" | sed -n -e 's/^Last-Modified: \\(.*\$\\)/\\1/p')"
	REMOT_EPOCH="\$(date "-d\${REMOT_FILEDATE}" +%s)"
	
	LOCAL_FILEDATE="\$(stat -c %y \${SCRIPT})"
	LOCAL_EPOCH="\$(date "-d\${LOCAL_FILEDATE}" +%s)"
	
	[ \$DEBUG -gt 0 ] && log_msg "Comparing dates"
	[ \$DEBUG -gt 0 ] && log_msg " Local: [\${LOCAL_EPOCH}] \$(date_epoch_to_iso8601  \${LOCAL_EPOCH})"
	[ \$DEBUG -gt 0 ] && log_msg "Remote: [\${REMOT_EPOCH}] \$(date_epoch_to_iso8601  \${REMOT_EPOCH})"

	[ \$DEBUG -gt 0 ] && [ \$LOCAL_EPOCH -lt \$REMOT_EPOCH ] && log_msg "Local \${SCRIPT} is older than Remote \${LURL} by \$(displaytime \$(echo "\${REMOT_EPOCH} - \${LOCAL_EPOCH}" | bc))." || log_msg "Local \${SCRIPT} is newer than Remote \${LURL} by \$(displaytime \$(echo "\${LOCAL_EPOCH} - \${REMOT_EPOCH}" | bc))." 

	# Update ourselves if we're older than Services.zip
	if [ \$LOCAL_EPOCH -lt \$REMOT_EPOCH ]; then
		date_msg "Updating \${SCRIPT} with new verson.."
		TEMPFILE="\$(mktemp -u)"
		# Download the Services.zip file, keeping the file modification date & time
		wget --quiet -O "\$TEMPFILE" -S "\$LURL" >/dev/null 2>&1
		if [ -f "\$TEMPFILE" ]; then
			cd /tmp
			unzip -u -o -qq "\$TEMPFILE"
			cd Services
			./install.sh
			cd "config-\${INST_NAME}"
			"./config-\${INST_NAME}.sh" --update
			cd /tmp
			rm -Rf ./Services
			rm "\$TEMPFILE"
			REBOOT=1
		fi
	else
		log_msg "\${SCRIPT} is up to date."
	fi
		
}

sbin_update(){
	local LURL='http://www.hegardtfoundation.org/slimstuff/sbin.zip'
	local TEMPFILE="\$(mktemp)"

	log_msg "Downloading updated utility scripts.."

	# Download the sbin.zip file, keeping the file modification date & time
	wget --quiet -O "\$TEMPFILE" -S "\$LURL" >/dev/null 2>&1
	
	if [ -f "\$TEMPFILE" ]; then
		log_msg "Updating \${SCRIPT} with new verson.."
		cd /tmp
		#~ unzip -u -o -qq "\$TEMPFILE" -d /usr/local
		unzip -u -o "\$TEMPFILE" -d /usr/local
		rm "\$TEMPFILE"
	fi
	
}

service_stop() {
	echo "Stopping \${INST_NAME} service.."
	if [ \$USE_UPSTART -gt 0 ]; then
		initctl stop "\$INST_NAME" >/dev/null 2>&1
	elif [ \$USE_SYSTEMD -gt 0 ]; then
		systemctl stop "\${INST_NAME}.service" >/dev/null 2>&1
	else
		if [ \$IS_DEBIAN -gt 0 ]; then
			service "\$INST_NAME" stop >/dev/null 2>&1
		else
			"/etc/rc.d/init.d/\${INST_NAME}" stop >/dev/null 2>&1
		fi
	fi

	sleep 2

	# Failsafe stop
	local LLCWA_PID=\$(pgrep -fn "\$LCWA_DAEMON")

	if [ ! -z "\$LLCWA_PID" ]; then
		kill -9 "\$LLCWA_PID"
	fi

	return \$?
}

service_start() {
	echo "Starting \${INST_NAME} service.."
	if [ \$USE_UPSTART -gt 0 ]; then
		initctl start "\$INST_NAME" >/dev/null 2>&1
	elif [ \$USE_SYSTEMD -gt 0 ]; then
		systemctl start "\${INST_NAME}.service" >/dev/null 2>&1
	else
		if [ \$IS_DEBIAN -gt 0 ]; then
			service "\$INST_NAME" start >/dev/null 2>&1
		else
			"/etc/rc.d/init.d/\${INST_NAME}" start >/dev/null 2>&1
		fi
	fi
	return \$?
}

######################################################################################################
# service_status() Get the status of the service..
######################################################################################################
service_status() {
	[ \$DEBUG -gt 0 ] && error_echo "\${FUNCNAME} \$@"
	local LSERVICE="\$1"
	
	if [ -z "\$LSERVICE" ]; then
		LSERVICE="\$INST_NAME"
	fi

	if [ \$USE_UPSTART -gt 0 ]; then
		# returns 0 if running, 1 if unknown job
		initctl status "\$LSERVICE"
	elif [ \$USE_SYSTEMD -gt 0 ]; then
		if [ \$(echo "\$LSERVICE" | grep -c -e '.*\\..*') -lt 1 ]; then
			LSERVICE="\${LSERVICE}.service"
		fi
		# returns 0 if service running; returns 3 if service is stopped, dead or not installed..
		systemctl --no-pager status "\$LSERVICE"
	else
		# returns 0 if service is running, returns 1 if unrecognized service
		if [ \$IS_DEBIAN -gt 0 ]; then
			service "\$LSERVICE" status
		else
			"/etc/rc.d/init.d/\${LSERVICE}" status
		fi
	fi
	return \$?
}



#---------------------------------------------------------------------------
# Check to see we are where we are supposed to be..
git_in_repo(){
	if [ \$(pwd) != "\$LCWA_LOCALREPO" ]; then
		log_msg "Error: \${LCWA_LOCALREPO} not found."
		return 128
	fi
}

#---------------------------------------------------------------------------
# Discard any local changes from the repo..
git_clean(){
	cd "\$LCWA_LOCALREPO" && git_in_repo
	log_msg "Cleaning \${LCWA_LOCALREPO}"
	if [ -d './.git' ]; then
		git reset --hard
		git clean -fd
	elif [ -d './.svn' ]; then
		svn revert -R .
	fi
}

#---------------------------------------------------------------------------
# Update the repo..
git_update(){
	cd "\$LCWA_LOCALREPO" && git_in_repo
	log_msg "Updating \${LCWA_LOCALREPO}"
	if [ -d './.git' ]; then
		git pull | tee -a "\$LCWA_VCLOG"
	elif [ -d './.svn' ]; then
		svn up | tee -a "\$LCWA_VCLOG"
	fi
	return \$?
}

git_check_up_to_date(){
	cd "\$LCWA_LOCALREPO" && git_in_repo
	if [ -d './.git' ]; then
		# http://stackoverflow.com/questions/3258243/git-check-if-pull-needed
		log_msg "Checking \${LCWA_DESC} to see if update is needed.."
		if [ \$(\$TIMEOUT_BIN \$PROC_TIMEOUT git remote -v update 2>&1 | egrep -c "\\[up to date\\]") -gt 0 ]; then
			log_msg "Local repository \${LCWA_LOCALREPO} is up to date."
			return 0
		else
			log_msg "Local repository \${LCWA_LOCALREPO} requires update."
			return 1
		fi
	fi
}

git_update_do() {
	git_clean
	git_update && status=0 || status=\$?
	if [ \$status -eq 0 ]; then
		log_msg "\${LCWA_DESC} has been updated."
	else
		log_msg "Error updating \${LCWA_DESC}."
	fi
}

sleep_random(){
	local FLOOR="\$1"
	local CEILING="\$2"
	local RANGE=\$((\$CEILING-\$FLOOR+1));
	local RESULT=\$RANDOM;
	let "RESULT %= \$RANGE";
	RESULT=\$((\$RESULT+\$FLOOR));
	log_msg "Waiting \${RESULT} seconds before restarting service.."
	sleep \$RESULT
}

################################################################################
################################################################################
# main()
################################################################################
################################################################################

# Process cmd line args..
SHORTARGS='hdvf'
LONGARGS='help,debug,verbose,force,script-update,no-script-update,sbin-update,os-update'
ARGS=\$(getopt -o "\$SHORTARGS" -l "\$LONGARGS"  -n "\$(basename \$0)" -- "\$@")

eval set -- "\$ARGS"

while [ \$# -gt 0 ]; do
	case "\$1" in
		--)
			;;
		-h|--help)
			disp_help
			exit 0
			;;
		-d|--debug)
			DEBUG=1
			;;
		-v|--verbose)
			VERBOSE=1
			;;
		-f|--force)
			FORCE=1
			;;
		--script-update)
			SCRIPT_UPDATE=1
			;;
		--no-script-update)
			SCRIPT_UPDATE=0
			;;
		--sbin-update)
			SBIN_UPDATE=1
			;;
		--os-update)
			OS_UPDATE=1
			;;
		*)
			log_msg "Error: unrecognized option \${1}."
			;;
	esac
	shift
done

INST_NAME=lcwa-speed

# Get our environmental variables..
env_file_read

# See if we need to update this update script..
if [ \$SCRIPT_UPDATE -gt 0 ]; then
	script_update
fi

if [ \$SBIN_UPDATE -gt 0 ]; then
	sbin_update
fi

if [ \$OS_UPDATE -gt 0 ]; then
	log_msg "Updating operating system.."
	service_stop
	apt-upgrade
fi

# Check Andi's repo to see if there are updates..
git_check_up_to_date

if [[ \$? -gt 0 ]] || [[ \$FORCE -gt 0 ]]; then
	service_stop
	git_update_do
fi

if [ \$REBOOT -gt 0 ]; then
	log_msg "\${SCRIPT} requries a reboot of this system!"
	shutdown -r 1 "\${SCRIPT} requries a reboot of this system!"
else
	# Sleep for a random number of seconds between 1 a 240 (i.e. 4 minutes)..
	sleep_random 1 240
	service_start
	service_status
fi

UPDATE_SCR1
chmod 755 "$LCWA_UPDATE"

}

######################################################################################################
# lcwa_update_script_remove() Remove the git/svn update script..
######################################################################################################
script_update_remove(){

	[ -z "$LCWA_UPDATE" ]		&& LCWA_UPDATE="/usr/local/sbin/${INST_NAME}-update.sh"

	if [ -f "$LCWA_UPDATE" ]; then
		echo "Removing ${LCWA_UPDATE}.."
		rm "$LCWA_UPDATE"
	fi

}


crontab_entry_add(){
	local COMMENT='#Everyday, at 5 minutes past midnight:'
	local EVENT='5 0 * * * /usr/local/sbin/lcwa-speed-update.sh --debug'
	#~ local EVENT='5 0 * * * /usr/local/sbin/lcwa-speed-update.sh --debug --force --sbin-update'
	local ROOTCRONTAB='/var/spool/cron/crontabs/root'
	
	# Remove any old reference to lcwa-speed-update.sh
	sed -i "/^.*${COMMENT}.*$/d" "$ROOTCRONTAB"
	sed -i "/^.*lcwa-speed-update.*$/d" "$ROOTCRONTAB"

	error_echo "Adding ${EVENT} to ${ROOTCRONTAB}"
	echo "$COMMENT" >>"$ROOTCRONTAB"
	echo "$EVENT" >>"$ROOTCRONTAB"
	
	# Make sure the permissions are correct for root crontab! (i.e. must not be 644!)
	chmod 600 "$ROOTCRONTAB"
	
	# signal crond to reload the file
	sudo touch /var/spool/cron/crontabs	
	
	# Make the entry stick
	error_echo "Restarting root crontab.."
	systemctl restart cron

	error_echo 'New crontab:'
	error_echo '======================================================================'
	crontab -l
	error_echo '======================================================================'
}

crontab_entry_remove(){
	local COMMENT='#Everyday, at 5 minutes past midnight:'
	local EVENT='5 0 * * * /usr/local/sbin/lcwa-speed-update.sh'
	local ROOTCRONTAB='/var/spool/cron/crontabs/root'
	
	# Remove any old reference to lcwa-speed-update.sh
	sed -i "/^.*lcwa-speed-update.*$/d" "$ROOTCRONTAB"

	error_echo "Removing ${EVENT} from ${ROOTCRONTAB}"
	# Remove any old reference to lcwa-speed-update.sh
	sed -i "/^.*${COMMENT}.*$/d" "$ROOTCRONTAB"
	sed -i "/^.*lcwa-speed-update.*$/d" "$ROOTCRONTAB"

	error_echo 'New crontab:'
	error_echo '======================================================================'
	crontab -l
	error_echo '======================================================================'
}

hostname_check(){
	local LHOSTNAME=
	local LOLDNAME="$(hostname)"

	# If hostname begins with 'lc', make LC
	if [ "$(hostname | grep -c -E '^lc.*$')" -gt 0 ]; then
		LHOSTNAME="$(hostname | sed -e 's/^lc/LC/')"
		config-hostname.sh "$LHOSTNAME"
		error_echo "Hostname changed from ${LOLDNAME} to ${LHOSTNAME}.."
	fi

	if [ "$(hostname | grep -c -E '^LC.*$')" -lt 1 ]; then
		error_echo "WARNING: The hostname of this system does not begin with 'LC'."
		error_echo ' '
		error_echo "Recomendation: Run config-hostname.sh 'LCXXspeedbox' to change the hostname."
	fi
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



	echo '================================================================================='
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
		echo "The destination for the ${LCWA_BRANCH} code will be \"${LCWA_LOCALREPO}\"."
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
	echo '================================================================================='
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
		echo "Run the command \"${LCWA_DEBUG}\" to start the service"
		echo "in startup debugging mode.  Check the ${LCWA_LOGDIR}/debug.log"
		echo "file for messages."
		echo ' '
		echo "To update the local git repo with the latest channges from"
		echo "${LCWA_REPO}, run the command:"
		echo ' '
		echo "${LCWA_UPDATE}"
		echo ' '
		echo "Run the command \"${LCWA_SWITCH}\" to see a list"
		echo "of the available branches in the ${LCWA_LOCALREPO} local repo.  Then run the command"
		echo "\"${LCWA_SWITCH}\" \"branchname\" using one of the"
		echo "branches listed to switch to that branch."
	else
		echo "Run the command \"service ${INST_NAME} start\" to start the service."
		echo ' '
		echo "Run the command \"service ${INST_NAME} update\" to update ${LCWA_LOCALREPO} from ${LCWA_REPO}."
		echo ' '
		echo "Run the command \"service ${INST_NAME} list-branches\" to to show the available branches at ${LCWA_LOCALREPO}."
		echo ' '
		echo "Run the command \"service ${INST_NAME} switch-branch 'branch-name'\" to check out a new branch from ${LCWA_REPO}."
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
			useradd --create-home --shell "$(which bash)" --user-group --groups sudo --password "$LPASS" "$LUSER"
		fi
	fi
	
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
no-scan,
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
service_priority_set

env_vars_defaults_get

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

	service_is_installed

	if [ $? -lt 1 ]; then
		error_exit "${INST_NAME} is not installed.  Cannot remove ${INST_NAME}.."
	fi

	service_stop

	# Remove the local repo..
	git_repo_remove

	git_repo_check

	REPOSTAT=$?
	if [ $REPOSTAT -eq 10 ]; then
		# local repo does not exist...create it..
		git_repo_clone
	elif [ $REPOSTAT -eq 5 ]; then
		# wrong repo!  Exit!
		git_repo_show
		exit 1
	else
		# local repo exists...update it..
		git_repo_clean
		git_repo_update
	fi


	#Update the repo
	git_repo_update


	service_start
	service_status
	

########################################################################################
# Update
elif [ $UPDATE -gt 0 ]; then

	if [ $FORCE -lt 1 ]; then
		service_is_installed
		if [ $? -lt 1 ]; then
			error_exit "${INST_NAME} is not installed.  Cannot update ${INST_NAME}.."
		fi
	fi

	service_stop
	service_disable

	#~ env_vars_defaults_get

	env_file_create $(env_vars_name)
	
	HOME="$CUR_HOME"


	env_file_read
	data_dir_update
	log_dir_update
	
	# Check and update the repo..
	git_repo_check && git_repo_update

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
	
	script_debug_create
	script_update_create

	# Configure root crontab to update the git repo and restart the service at 12:05 am..
	crontab_entry_add
	
	# Create a /etc/rc.local file to reconfigure the firewall when the subnet changes..
	rclocal_create
	
	# Create a LCWA admin user with cannonical password
	admin_user_create

	service_enable
	service_start
	service_status
	hostname_check

########################################################################################
# UNINSTALL
elif [ $UNINSTALL -gt 0 ]; then

	if [ $FORCE -lt 1 ]; then
		service_is_installed

		if [ $? -lt 1 ]; then
			error_exit "${INST_NAME} is not installed.  Cannot remove ${INST_NAME}.."
		fi
	else
		banner_display
	fi

	env_file_read
	if [ $? -gt 0 ]; then
		# Get defaults if the env file has already been removed..
		env_vars_defaults_get
	fi

	HOME="$CUR_HOME"

	service_stop

	service_disable
	service_remove
	sysv_init_file_remove

	script_debug_remove
	script_update_remove
	log_rotate_script_remove
	pid_dir_remove
	env_file_remove
	crontab_entry_remove

	# Remove the git repo
	if [ $KEEPLOCALREPO -lt 1 ]; then
		git_repo_remove
		inst_dir_remove
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

	banner_display

	if [ $? -gt 0 ]; then
		service_stop
	fi
	
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
	
	# Check and install or update the repo..
	git_repo_check

	REPOSTAT=$?
	if [ $REPOSTAT -eq 10 ]; then
		# local repo does not exist...create it..
		git_repo_clone
	elif [ $REPOSTAT -eq 5 ]; then
		# wrong repo!  Exit!
		git_repo_show
		exit 1
	else
		# local repo exists...update it..
		git_repo_clean
		git_repo_update
	fi

	HOME="$CUR_HOME"

	# Create the PID directory..
	#~ pid_dir_create 'd' "$INST_NAME" '0750' "$INST_USER" "$INST_GROUP" '10d'

	# Create a data dir
	data_dir_create

	echo "Fixing permissions in /var/lib/${INST_NAME}"
	chown -R "${INST_USER}:${INST_GROUP}" "/var/lib/${INST_NAME}"

	# Create a log dir
	log_dir_create
	log_rotate_script_create

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



	# Create the startup debugging script
	script_debug_create

	# Create the git/svn updating script
	script_update_create

	# Create the service control links..
	service_enable

	# Configure root crontab to update the git repo and restart the service at 12:05 am..
	crontab_entry_add

	# Create a /etc/rc.local file to reconfigure the firewall when the subnet changes..
	rclocal_create
	
	# Create a LCWA admin user with cannonical password
	admin_user_create

	service_start
	service_status

	finish_display
	hostname_check
fi




exit 0
