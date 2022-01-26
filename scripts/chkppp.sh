#!/bin/bash

SCRIPT_VERSION=20201206.165240

# Bash script to check to see if a pppoe connection is still up, and if not, re-establish it.

# Get our PPPoE account name from /etc/network/interfaces
PPPOE_ACCOUNT="$(grep -E '^auto.*lcwa.*$|^auto.*provider.*$' /etc/network/interfaces | awk '{ print $2 }')"

if [ -z "$PPPOE_ACCOUNT" ]; then
	echo 'Error: No ppp interface defined in /etc/network/interfaces'
	exit 1
fi

# Are we showing an active ppp interface?
if [ $(ip -br a | grep -c -E '^ppp.*peer') -lt 1 ]; then

	echo "PPPoE connection ${PPPOE_ACCOUNT} is DOWN."
	
	if [ ! -z "$PPPOE_ACCOUNT" ]; then
		echo "Reestablishing ${PPPOE_ACCOUNT} PPPoE connection."
		pon "$PPPOE_ACCOUNT"
	else
		echo "Error: could not determine a PPPoE account to reestablish PPPoE connection."
	fi
	
else
	echo "PPPoE connection ${PPPOE_ACCOUNT} is UP."
fi

