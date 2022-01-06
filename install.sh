#!/bin/bash
set -e
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
printf "\n\nPreparing masscan...\n"
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
echo "${MASSCAN_CRON} root /usr/bin/masscan -v -p${MASSCAN_TARGET_PORT_RANGE} ${MASSCAN_TARGET_CIDR_RANGE} -oL /tmp/masscan.tmp.txt --max-rate 10000 && mv /tmp/masscan.tmp.txt /tmp/masscan.txt" > /etc/cron.d/masscan
chmod 600 /etc/cron.d/masscan
printf "> Masscan installed successfully.\n"

# scanner
printf "\n\nPreparing log4shell-scanner...\n"
cd ${SCRIPTPATH}
printf "> Moving script and config files to proper locations...\n"
cp ${SCRIPTPATH}/log4shell-scan/scanner/config.ini /etc/log4shell-scan.ini
cp ${SCRIPTPATH}/log4shell-scan/scanner/scan.py /usr/local/sbin/log4shell-scan
printf "> Adjusting permissions...\n"
chmod +x /usr/local/sbin/log4shell-scan
printf "> Installing Python script requirements...\n"
/usr/bin/env python3 -m pip install -r ${SCRIPTPATH}/scanner/requirements.txt
printf "> Adding scanner to root's crontab...\n"
echo "${SCANNER_CRON} root /usr/local/sbin/log4shell-scan" > /etc/cron.d/log4shell-scan
chmod 600 /etc/cron.d/masscan
printf "> Scanner installed successfully.\n"

# listener
printf "\n\nPreparing log4shell-listener...\n"
cd ${SCRIPTPATH}
printf "> Moving config file to proper location...\n"
cp ${SCRIPTPATH}/log4shell-scan/listener/log4shell.yaml /etc/log4shell-listener.yaml
if [[ -z "$(type -P mvn)" ]]; then
    printf "> Installing mvn...\n"
    apt update && apt install -y maven default-jdk
fi
printf "> Building jar..."
cd ${SCRIPTPATH}/log4shell-scan/listener && mvn clean package -DoutputDirectory="/usr/share/java"
printf "> Adding unit file to services..."
cp ${SCRIPTPATH}/log4shell-scan/listener/log4shell-listener.service /etc/systemd/system/
printf "> Reloading services and starting listener..."
systemctl daemon-reload
systemctl enable log4shell-listener.service
systemctl start log4shell-listener.service
systemctl status log4shell-listener.service

printf "\n\nInstall successful.\n\n"