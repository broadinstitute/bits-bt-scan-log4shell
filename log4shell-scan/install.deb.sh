#!/bin/bash
set -e

printf "\n-------------------------------------------------------------------\n"
printf "> Remember to update any installation configuration in ./install.conf\n"
printf "> Additionally, ensure log4shell-scan/listener/log4shell.yaml \n"
printf "    is accurate and up-to-date for your needs. These settings may be \n"
printf "    changed later but will require a listener service restart."
printf "\n-------------------------------------------------------------------\n"
printf "(cancel the install with Ctrl-C if you'd like to make any changes)\n"

sleep 5

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source ${SCRIPTPATH}/install.conf

printf "\n-------------------------------------------------------------------\n"
printf "Current install configuration:\n"
printf "> MASSCAN_CRON              : ${MASSCAN_CRON}\n"
printf "> MASSCAN_TARGET_PORT_RANGE : ${MASSCAN_TARGET_PORT_RANGE}\n"
printf "> MASSCAN_TARGET_CIDR_RANGE : ${MASSCAN_TARGET_CIDR_RANGE}\n"
printf "> MASSCAN_RATE              : ${MASSCAN_RATE}\n"
printf "> SCANNER_PYTHONPATH        : ${SCANNER_PYTHONPATH}\n"
printf "> SCANNER_CRON              : ${SCANNER_CRON}\n"

sleep 3

printf "\nStarting install process...\n"

if [[ "$(lsb_release -i | cut -f 2-)" != "Debian" ]]; then
    printf "\nERROR: This package is only supported on Debian and may break things on other distros. Cancelling install.\n\n"
    exit 1
fi

if [[ $(id -u) -ne 0 ]]; then
   printf "\nERROR: This script must be run as root. Retry with sudo or login as root.\n\n"
   exit 1
fi

# masscan
printf "\n\n-------------------------------------------------------------------\n"
printf "Preparing masscan...\n"
cd ${SCRIPTPATH}
printf "> Checking if masscan is installed...\n"
if [[ -z "$(type -P masscan)" ]]; then
    printf "> Installing masscan dependencies...\n"
    apt update && apt-get --assume-yes install git make gcc
    printf "> Installing masscan...\n"
    cd /lib && git clone https://github.com/robertdavidgraham/masscan
    cd /lib/masscan && make install
fi

printf "> Adding masscan job to root's crontab...\n"
echo "${MASSCAN_CRON} root /usr/bin/masscan -v -p${MASSCAN_TARGET_PORT_RANGE} ${MASSCAN_TARGET_CIDR_RANGE} -oL /tmp/masscan.tmp.txt --max-rate ${MASSCAN_RATE} && mv /tmp/masscan.tmp.txt /tmp/masscan.txt\n" > ${MASSCAN_CRON_LOC}
chmod 600 ${MASSCAN_CRON_LOC}
printf "> Masscan installed successfully.\n"

# scanner
SCANNER_SRC_PATH=${SCRIPTPATH}/scanner
printf "\n\n-------------------------------------------------------------------\n"
printf "Preparing log4shell-scanner...\n"
cd ${SCRIPTPATH}
printf "> Moving script and config files to proper locations...\n"
if [[ -e $SCANNER_CONFIG_LOC ]]; then
    printf "> $SCANNER_CONFIG_LOC config detected, keeping original.\n"
else
    cp ${SCANNER_SRC_PATH}/config.ini $SCANNER_CONFIG_LOC
fi
cp ${SCANNER_SRC_PATH}/scan.py ${SCANNER_SCRIPT_LOC}
printf "> Adjusting permissions...\n"
chmod +x ${SCANNER_SCRIPT_LOC}
printf "> Installing Python script requirements...\n"
${SCANNER_PYTHONPATH} -m pip install -r ${SCANNER_SRC_PATH}/requirements.txt
printf "> Adding scanner to root's crontab...\n"
echo "${SCANNER_CRON} root ${SCANNER_SCRIPT_LOC}\n" > ${SCANNER_CRON_LOC}
chmod 600 ${SCANNER_CRON_LOC}
printf "> Scanner installed successfully.\n"

# listener
LISTENER_SRC_PATH=${SCRIPTPATH}/listener
printf "\n\n-------------------------------------------------------------------\n"
printf "Preparing log4shell-listener...\n"
cd ${SCRIPTPATH}
printf "> Moving files to proper locations...\n"
if [[ -e $LISTENER_CONFIG_LOC ]]; then
    printf "> $LISTENER_CONFIG_LOC config detected, keeping original.\n"
else
    cp ${LISTENER_SRC_PATH}/config.ini $LISTENER_CONFIG_LOC
fi
cp ${LISTENER_SRC_PATH}/listen.py $LISTENER_SCRIPT_LOC
chmod +x $LISTENER_SCRIPT_LOC
printf "> Installing Python script requirements...\n"
${SCANNER_PYTHONPATH} -m pip install -r ${LISTENER_SRC_PATH}/requirements.txt
printf "> Adding unit file to services...\n"
cp ${LISTENER_SRC_PATH}/log4shell-listen.service $LISTENER_SERVICE_UNIT_LOC
printf "> Reloading services and starting listener...\n"
systemctl daemon-reload
systemctl enable $LISTENER_SERVICE_NAME
systemctl restart $LISTENER_SERVICE_NAME
sleep 2
systemctl status $LISTENER_SERVICE_NAME
sleep 2

printf "\n\n----------------------------------------------------------------------\n"
printf "Install successful.\n"
printf "> Runtime configuration for the scanner may be done in \n"
printf "    ${SCANNER_CONFIG_LOC}\n"
printf "> Note that any changes to the listener's config in \n"
printf "    ${LISTENER_CONFIG_LOC} will require the service \n"
printf "    to be restarted with: \n"
printf "    $ sudo systemctl restart ${LISTENER_SERVICE_NAME}\n" 
printf "> Changes to the cronjobs may be done in the two files:\n"
printf "    ${SCANNER_CRON_LOC}\n"
printf "    ${MASSCAN_CRON_LOC}\n"
printf "    OR by editing install.conf and re-running this script."
printf "\n----------------------------------------------------------------------\n"
printf "IMPORTANT REMINDER!\n"
printf "    Set the following variables (blank by default):\n"
printf "    - ${SCANNER_CONFIG_LOC}\n"
printf "        - listener_ip\n"
printf "        - webhook\n"
printf "    - ${LISTENER_CONFIG_LOC}\n"
printf "        - webhook\n"
printf "Failure to do so will mean you are not alerted on exploits and crashes!"
printf "\n----------------------------------------------------------------------\n\n"
