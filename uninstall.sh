#!/bin/bash

printf "\n-------------------------------------------------------------------\n"
printf "Starting uninstall process..."
printf "\n-------------------------------------------------------------------\n"

if [[ $(id -u) -ne 0 ]]; then
   printf "\nERROR: This script must be run as root. Retry with sudo or login as root.\n\n"
   exit 1
fi

printf "Removing config files...\n"
rm /etc/log4shell-scan.ini
rm /etc/log4shell-listener.yaml

printf "Removing scripts and executables...\n"
rm /usr/share/java/log4shell-jar-with-dependencies.jar
rm /usr/local/sbin/log4shell-scan

printf "Removing cronjobs...\n"
rm /etc/cron.d/log4shell-scan
rm /etc/cron.d/log4shell-masscan

printf "Removing listener system service and restarting daemon..."
systemctl stop log4shell-listener.service
rm /etc/systemd/system/log4shell-listener.service
systemctl daemon-reload

printf "\n\n-------------------------------------------------------------------\n"
printf "Uninstall complete."
printf "\n-------------------------------------------------------------------\n\n"