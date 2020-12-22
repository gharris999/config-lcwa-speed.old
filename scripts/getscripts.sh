#!/bin/bash

SCRIPT="$(basename "$0")"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

TEST=0
VERBOSE=0
FORCE=0

# -u, --update  copy only when the SOURCE file is newer
#               than the destination file or when the
#               destination file is missing.
# -v, --verbose explain what is being done/

CP_OPTS='-u -v'

FORCE=0

if [ "$1" = '--force' ]; then
	FORCE=1
	CP_OPTS='-v'
fi


cd "$SCRIPT_DIR"

if [ "$(pwd)" != "$SCRIPT_DIR" ]; then
	echo "Error: could not change to ${$SCRIPT_DIR}"
	exit 1
fi

TARGET='../instsrv_functions.sh'

SOURCE="../${TARGET}"

if [ -f "$SOURCE" ]; then

	if [ $FORCE -gt 0 ] || [ ! -f "$TARGET" ] || [ "$SOURCE" -nt "$TARGET" ]; then
	
		bash -n "$SOURCE"
		if [ $? -gt 0 ]; then
			echo '============================================================='
			echo "Error: bash says that ${SOURCE} has errors!!!"
			echo '============================================================='
		else
			echo "Copying ${SOURCE} to ${TARGET}"
			[ $TEST -lt 1 ] && cp -p $CP_OPTS "$SOURCE" "$TARGET"
		fi
	
	fi

fi


SOURCEDIR="../../config-firewall"

for TARGET in chkfw.sh config-firewall.sh config-firewall-prep-apps.sh
do
	SOURCE="${SOURCEDIR}/${TARGET}"

	if [ -f "$SOURCE" ]; then

		if [ $FORCE -gt 0 ] || [ ! -f "$TARGET" ] || [ "$SOURCE" -nt "$TARGET" ]; then
		
			bash -n "$SOURCE"
			if [ $? -gt 0 ]; then
				echo '============================================================='
				echo "Error: bash says that ${SOURCE} has errors!!!"
				echo '============================================================='
			else
				echo "Copying ${SOURCE} to ${TARGET}"
				[ $TEST -lt 1 ] && cp -p $CP_OPTS "$SOURCE" "$TARGET"
			fi
		
		fi

	fi

done

SOURCEDIR="../../config-network"

for TARGET in chknet.sh config-network.sh
do
	SOURCE="${SOURCEDIR}/${TARGET}"

	if [ -f "$SOURCE" ]; then

		if [ $FORCE -gt 0 ] || [ ! -f "$TARGET" ] || [ "$SOURCE" -nt "$TARGET" ]; then
		
			bash -n "$SOURCE"
			if [ $? -gt 0 ]; then
				echo '============================================================='
				echo "Error: bash says that ${SOURCE} has errors!!!"
				echo '============================================================='
			else
				echo "Copying ${SOURCE} to ${TARGET}"
				[ $TEST -lt 1 ] && cp -p $CP_OPTS "$SOURCE" "$TARGET"
			fi
		
		fi

	fi

done
