#!/bin/bash
# shellcheck disable=SC1091
set -e

printf "\n-------------------------------------------------------------------\n"
printf "IMPORTANT REMINDER!\n"
printf "> Remember to update any installation configuration in ./install.conf\n"
printf "\n-------------------------------------------------------------------\n"
printf "(cancel the install with Ctrl-C if you'd like to make any changes)\n"

sleep 5

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# shellcheck source=./install.rhel.conf
source "${SCRIPTPATH}/install.rhel.conf"

printf "\n-------------------------------------------------------------------\n"
printf "Current install configuration:\n"
printf "> MASSCAN_CRON              : %s" "$MASSCAN_CRON"
printf "> MASSCAN_TARGET_PORT_RANGE : %s" "$MASSCAN_TARGET_PORT_RANGE"
printf "> MASSCAN_TARGET_CIDR_RANGE : %s" "$MASSCAN_TARGET_CIDR_RANGE"
printf "> MASSCAN_RATE              : %s" "$MASSCAN_RATE"
printf "> SCANNER_PYTHONPATH        : %s" "$SCANNER_PYTHONPATH"
printf "> SCANNER_CRON              : %s" "$SCANNER_CRON"

sleep 3

printf "\nStarting install process...\n"

# shellcheck source=/dev/null
source /etc/os-release

if [[ "${ID}" != "rhel" ]]; then
    printf "\nERROR: This package is only supported on RHEL and may break things on other distros. Cancelling install.\n\n"
    exit 1
fi

# if [[ $(id -u) -ne 0 ]]; then
#    printf "\nERROR: This script must be run as root. Retry with sudo or login as root.\n\n"
#    exit 1
# fi

mkdir -p "$SCRIPT_INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"

# masscan
printf "\n\n-------------------------------------------------------------------\n"
printf "Preparing masscan...\n"
cd "${SCRIPTPATH}"
printf "> Checking if masscan is installed...\n"
if [[ -z "$(type -P /local/masscan/bin/masscan)" ]]; then
    printf "> Installing masscan...\n"
    cd /local && git clone https://github.com/robertdavidgraham/masscan
    cd /local/masscan && make -j
fi

printf "> Adding masscan job to crontab...\n"
(crontab -l; echo "${MASSCAN_CRON} /local/masscan/bin/masscan -v -p${MASSCAN_TARGET_PORT_RANGE} ${MASSCAN_TARGET_CIDR_RANGE} -oL ${MASSCAN_OUTPUT_TMP} --max-rate ${MASSCAN_RATE} && mv ${MASSCAN_OUTPUT_TMP} ${MASSCAN_OUTPUT}")|awk '!x[$0]++'|crontab -
printf "> Masscan installed successfully.\n"

# scanner
SCANNER_SRC_PATH="${SCRIPTPATH}/scanner"
printf "\n\n-------------------------------------------------------------------\n"
printf "Preparing log4shell-scanner...\n"
cd "${SCRIPTPATH}"
printf "> Moving script and config files to proper locations...\n"
if [[ -e "$SCANNER_CONFIG_LOC" ]]; then
    printf "> %s config detected, keeping original.\n" "$SCANNER_CONFIG_LOC"
else
    cp "${SCANNER_SRC_PATH}/config.ini" "$SCANNER_CONFIG_LOC"
    sed -i "s:log_dir =:log_dir = ${SCANNER_LOG_LOC}:" "$SCANNER_CONFIG_LOC"
    sed -i "s:primary_input =:primary_input = ${MASSCAN_OUTPUT}:" "$SCANNER_CONFIG_LOC"
    sed -i "s:secondary_input =:secondary_input = ${MASSCAN_OUTPUT_TMP}:" "$SCANNER_CONFIG_LOC"
fi
cp "${SCANNER_SRC_PATH}/scan.py" "${SCANNER_SCRIPT_LOC}"
if [[ "${SCRIPTS_PYTHONPATH}" != "/usr/bin/env python3" ]]; then
    sed -i "s:#!/usr/bin/env python3:#!${SCRIPTS_PYTHONPATH}:" "${SCANNER_SCRIPT_LOC}"
fi
printf "> Adjusting permissions...\n"
chmod +x "${SCANNER_SCRIPT_LOC}"
printf "> Installing Python script requirements...\n"
${SCRIPTS_PYTHONPATH} -m pip install --user -r "${SCANNER_SRC_PATH}/requirements.txt"
printf "> Adding scanner to crontab...\n"
(crontab -l; echo "${SCANNER_CRON} env L4S_CONFIG_FILE=\"${SCANNER_CONFIG_LOC}\" ${SCANNER_SCRIPT_LOC}")|awk '!x[$0]++'|crontab -
printf "> Scanner installed successfully.\n"

# listener
LISTENER_SRC_PATH="${SCRIPTPATH}/listener"
printf "\n\n-------------------------------------------------------------------\n"
printf "Preparing log4shell-listener...\n"
cd "${SCRIPTPATH}"
printf "> Moving files to proper locations...\n"
if [[ -e "$LISTENER_CONFIG_LOC" ]]; then
    printf "> %s config detected, keeping original.\n" "$LISTENER_CONFIG_LOC"
else
    sed -i "s:log_dir =:log_dir = ${LISTENER_LOG_LOC}:" "${LISTENER_SRC_PATH}/config.ini"
    cp "${LISTENER_SRC_PATH}/config.ini" "$LISTENER_CONFIG_LOC"
fi
cp "${LISTENER_SRC_PATH}/listen.py" "$LISTENER_SCRIPT_LOC"
sed -i "s:#!/usr/bin/env python3:#!${SCRIPTS_PYTHONPATH}:" "$LISTENER_SCRIPT_LOC"
sed -i "s:L4SL_CONFIG_FILE = \"\":L4SL_CONFIG_FILE = \"${LISTENER_CONFIG_LOC}\":" "$LISTENER_SCRIPT_LOC"
chmod +x "$LISTENER_SCRIPT_LOC"
printf "> Installing Python script requirements...\n"
${SCRIPTS_PYTHONPATH} -m pip install --user -r "${LISTENER_SRC_PATH}/requirements.txt"
# printf "> Adding unit file to services...\n"
# cp "${LISTENER_SRC_PATH}/log4shell-listen.service" "$LISTENER_SERVICE_UNIT_LOC"
printf "> Starting listener...\n"
systemctl daemon-reload
systemctl enable "$LISTENER_SERVICE_NAME"
systemctl restart "$LISTENER_SERVICE_NAME"
sleep 2
systemctl status "$LISTENER_SERVICE_NAME"
sleep 2

printf "\n\n----------------------------------------------------------------------\n"
printf "Install successful.\n"
printf "> Runtime configuration for the scanner may be done in \n"
printf "    %s\n" "$SCANNER_CONFIG_LOC"
printf "> Note that any changes to the listener's config in \n"
printf "    %s will require the service \n" "$LISTENER_CONFIG_LOC"
printf "    to be restarted with: \n"
printf "    $ sudo systemctl restart %s\n" "$LISTENER_SERVICE_NAME"
printf "> Changes to the cronjobs may be done in the two files:\n"
printf "    %s\n" "$SCANNER_CRON_LOC"
printf "    %s\n" "$MASSCAN_CRON_LOC"
printf "    OR by editing install.conf and re-running this script."
printf "\n----------------------------------------------------------------------\n"
printf "IMPORTANT REMINDER!\n"
printf "    Set the following variables (blank by default):\n"
printf "    - %s\n" "$SCANNER_CONFIG_LOC"
printf "        - listener_ip\n"
printf "        - webhook\n"
printf "    - %s\n" "$LISTENER_CONFIG_LOC"
printf "        - webhook\n"
printf "Failure to do so will mean you are not alerted on exploits and crashes!"
printf "\n----------------------------------------------------------------------\n\n"
