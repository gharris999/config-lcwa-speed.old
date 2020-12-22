#!/bin/bash

FORCE=0
TEST=0

LCODE_FILE="chkfw.sh"
touch "$LCODE_FILE"

LCODE_DATE="$(stat -c %Y "$LCODE_FILE")"
LCODE_DATESTR="$(date -d "@${LCODE_DATE}" +%Y%m%d.%H%M%S)"
LCODE_VERSTR="$(grep -E -m1 'VERSION=[0-9]*\.[0-9]*' "$LCODE_FILE" | sed -n -e 's/^.*VERSION=\([0-9]*\.[0-9]*\).*$/\1/p')"


if [[ "$LCODE_DATESTR" > "$LCODE_VERSTR" || $FORCE -gt 0 ]]; then

	echo "Updating ${LCODE_FILE} with new version string ${LCODE_DATESTR}"
	
	#~ [ $TEST -lt 1 ] && sed -i -e "s/VERSION=\"*[0-9]\{8\}\.[0-9]\{6\}\"*/VERSION=${LCODE_DATESTR}/g" "$LCODE_FILE"
				
	printf "%s\n" "1,\$s/VERSION=.*/VERSION=${LCODE_DATESTR}/g" wq | ed -s "$LCODE_FILE"

fi
