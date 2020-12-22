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
fi

if [ "$1" = '--test' ]; then
	TEST=1
fi


cd "$SCRIPT_DIR"

if [ "$(pwd)" != "$SCRIPT_DIR" ]; then
	echo "Error: could not change to ${$SCRIPT_DIR}"
	exit 1
fi

pushd ..

TARGET='instsrv_functions.sh'

SOURCE="../${TARGET}"

if [ -f "$SOURCE" ]; then

	bash -n "$SOURCE"
	if [ $? -gt 0 ]; then
		echo '============================================================='
		echo "Error: bash says that ${SOURCE} has errors!!!"
		echo '============================================================='
	else
		echo "Linking ${SOURCE} to ${TARGET}"
		[ $TEST -lt 1 ] && ln -Pf "$SOURCE" "$TARGET"
	fi

fi

popd


SOURCEDIR="../../config-firewall"

for TARGET in chkfw.sh config-firewall.sh config-firewall-prep-apps.sh
do
	SOURCE="${SOURCEDIR}/${TARGET}"

	if [ -f "$SOURCE" ]; then
		
		bash -n "$SOURCE"
		if [ $? -gt 0 ]; then
			echo '============================================================='
			echo "Error: bash says that ${SOURCE} has errors!!!"
			echo '============================================================='
		else
			echo "Linking ${SOURCE} to ${TARGET}"
			[ $TEST -lt 1 ] && ln -Pf "$SOURCE" "$TARGET"
		fi

	fi

done

SOURCEDIR="../../config-network"

for TARGET in chknet.sh config-network.sh
do
	SOURCE="${SOURCEDIR}/${TARGET}"

	if [ -f "$SOURCE" ]; then

		bash -n "$SOURCE"
		if [ $? -gt 0 ]; then
			echo '============================================================='
			echo "Error: bash says that ${SOURCE} has errors!!!"
			echo '============================================================='
		else
			echo "Linking ${SOURCE} to ${TARGET}"
			[ $TEST -lt 1 ] && ln -Pf "$SOURCE" "$TARGET"
		fi

	fi

done


echo '============================================================='
echo '============================================================='
for INUM in $(ls -1i *.sh | awk '{ print $1 }' | xargs)
do
	find /home/daadmin/Services -inum "$INUM" | sort
done
