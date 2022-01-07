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

printf "\nStarting install process...\n"

if [[ "$(lsb_release -i | cut -f 2-)" != "Debian" ]]; then
    printf "\nERROR: This package is only supported on Debian and may break things on other distros. Cancelling install.\n\n"
    exit 1
fi

if [[ $(id -u) -ne 0 ]]; then
   printf "\nERROR: This script must be run as root. Retry with sudo or login as root.\n\n"
   exit 1
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
source ${SCRIPTPATH}/install.conf

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
echo "${MASSCAN_CRON} root /usr/bin/masscan -v -p${MASSCAN_TARGET_PORT_RANGE} ${MASSCAN_TARGET_CIDR_RANGE} -oL /tmp/masscan.tmp.txt --max-rate ${MASSCAN_RATE} && mv /tmp/masscan.tmp.txt /tmp/masscan.txt" > /etc/cron.d/log4shell-masscan
chmod 600 /etc/cron.d/log4shell-masscan
printf "> Masscan installed successfully.\n"

# scanner
printf "\n\n-------------------------------------------------------------------\n"
printf "Preparing log4shell-scanner...\n"
cd ${SCRIPTPATH}
printf "> Moving script and config files to proper locations...\n"
cp ${SCRIPTPATH}/log4shell-scan/scanner/config.ini /etc/log4shell-scan.ini
cp ${SCRIPTPATH}/log4shell-scan/scanner/scan.py /usr/local/sbin/log4shell-scan
printf "> Adjusting permissions...\n"
chmod +x /usr/local/sbin/log4shell-scan
printf "> Installing Python script requirements...\n"
${SCANNER_PYTHONPATH} -m pip install -r ${SCRIPTPATH}/log4shell-scan/scanner/requirements.txt
printf "> Adding scanner to root's crontab...\n"
echo "${SCANNER_CRON} root /usr/local/sbin/log4shell-scan" > /etc/cron.d/log4shell-scan
chmod 600 /etc/cron.d/masscan
printf "> Scanner installed successfully.\n"

# listener
printf "\n\n-------------------------------------------------------------------\n"
printf "Preparing log4shell-listener...\n"
cd ${SCRIPTPATH}
printf "> Moving config file to proper location...\n"
cp ${SCRIPTPATH}/log4shell-scan/listener/log4shell.yaml /etc/log4shell-listener.yaml
if [[ -z "$(type -P mvn)" ]]; then
    printf "> Installing mvn...\n"
    apt update && apt install -y maven default-jdk
fi
printf "> Building jar...\n"
cd ${SCRIPTPATH}/log4shell-scan/listener && mvn clean package
mv ${SCRIPTPATH}/log4shell-scan/listener/target/log4shell-jar-with-dependencies.jar /usr/share/java
printf "> Adding unit file to services...\n"
cp ${SCRIPTPATH}/log4shell-scan/listener/log4shell-listener.service /etc/systemd/system/
printf "> Reloading services and starting listener...\n"
systemctl daemon-reload
systemctl enable log4shell-listener.service
systemctl start log4shell-listener.service
systemctl status log4shell-listener.service

printf "\n\n-------------------------------------------------------------------\n"
printf "Install successful.\n"
printf "> Runtime configuration for the scanner may be done in \n"
printf "    /etc/log4shell-scan.ini\n"
printf "> Note that any changes to the listener's config in \n"
printf "    /etc/log4shell-listener.yaml will require the service \n"
printf "    to be restarted with: \n"
printf "    $ sudo systemctl restart log4shell-listener.service\n" 
printf "> Changes to the cronjobs may be done in the two files:\n"
printf "    /etc/cron.d/log4shell-scan\n"
printf "    /etc/cron.d/masscan\n"
printf "    OR by editing install.conf and re-running this script."
printf "\n-------------------------------------------------------------------\n\n"
