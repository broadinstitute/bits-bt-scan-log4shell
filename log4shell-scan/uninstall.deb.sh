#!/bin/bash
set -e

printf "\n-------------------------------------------------------------------\n"
printf "Starting uninstall process..."
printf "\n-------------------------------------------------------------------\n"

if [[ "$(lsb_release -i | cut -f 2-)" != "Debian" ]]; then
    printf "\nERROR: This package is only supported on Debian and may break things on other distros. Cancelling install.\n\n"
    exit 1
fi

if [[ $(id -u) -ne 0 ]]; then
   printf "\nERROR: This script must be run as root. Retry with sudo or login as root.\n\n"
   exit 1
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source ${SCRIPTPATH}/install.deb.conf

# printf "Removing config files...\n"
# rm $LISTENER_CONFIG_LOC
# rm $SCANNER_CONFIG_LOC

printf "Removing scripts and executables...\n"
rm $LISTENER_SCRIPT_LOC
rm $SCANNER_SCRIPT_LOC

printf "Removing cronjobs...\n"
rm $SCANNER_CRON_LOC
rm $MASSCAN_CRON_LOC

printf "Removing listener system service and restarting daemon..."
systemctl stop $LISTENER_SERVICE_NAME
rm $LISTENER_SERVICE_UNIT_LOC
systemctl daemon-reload

printf "\n\n-------------------------------------------------------------------\n"
printf "Uninstall complete."
printf "\n-------------------------------------------------------------------\n\n"