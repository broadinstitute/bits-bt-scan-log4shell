#!/bin/bash
set -e

printf "\n-------------------------------------------------------------------\n"
printf "Starting uninstall process..."
printf "\n-------------------------------------------------------------------\n"

source /etc/os-release

if [[ "${ID}" != "rhel" ]]; then
    printf "\nERROR: This package is only supported on RHEL and may break things on other distros. Cancelling install.\n\n"
    exit 1
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source ${SCRIPTPATH}/install.rhel.conf

# printf "Removing config files...\n"
# rm $LISTENER_CONFIG_LOC
# rm $SCANNER_CONFIG_LOC

printf "Removing scripts...\n"
rm $LISTENER_SCRIPT_LOC
rm $SCANNER_SCRIPT_LOC

printf "Stopping listener system service..."
sudo systemctl stop $LISTENER_SERVICE_NAME

printf "\n\n-------------------------------------------------------------------\n"
printf "Uninstall complete."
printf "\n-------------------------------------------------------------------\n\n"