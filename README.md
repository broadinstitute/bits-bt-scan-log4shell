# Broad log4shell Web Server Scan Tool

## Architecture

![Lucidchart](./lucidchart.png)
[link to latest version](https://lucid.app/lucidchart/434ccfcc-eb3b-4b82-b40c-f9f1a943cfc0/edit?viewport_loc=15%2C41%2C1790%2C1170%2C0_0&invitationId=inv_4c1416c8-da36-4a95-8337-c59e8cb457da)

## Usage

### Requirements

#### Pre-requirements
- **Debian OR RHEL7**
  - Tested on Debian 10 (buster), Debian 11 (bullseye), and RHEL 7.
  - May work on other Linux distros but may also break things. So for now the install script will refuse to install on a non-Debian/RHEL system.
- **Sudo privileges**
- [Python3](https://www.python.org/downloads/)
  - Tested on 3.8, 3.9, and 3.10. Will **not** be automatically installed and will terminate the install process if it is not present.

#### Other Requirements

- [masscan](https://github.com/robertdavidgraham/masscan)
  - Will install it if it is not present.\

### Get

```
$ wget --header "Authorization: token ${GITHUB_ACCESS_TOKEN}" 'https://github.com/broadinstitute/bits-bt-scan-log4shell/archive/refs/tags/{RELEASE_TAG}.tar.gz'
$ sudo tar -xvf {RELEASE_TAG}.tar.gz -C /usr/local/lib
```

### Setup

- Installation sets up three main tasks:
  - [masscan](https://github.com/robertdavidgraham/masscan):
    - Installs if it is not present.
    - Stores the cronjob as `/etc/cron.d/log4shell-masscan`.
  - Scanner:
    - Installs Python requirements.
    - Stores the script as `/usr/local/sbin/log4shell-scan`.
    - Stores the config file as `/etc/log4shell-scan.ini`.
    - Stores the cronjob as `/etc/cron.d/log4shell-scan`.
  - Listener:
    - Stores the script as `/usr/local/sbin/log4shell-listen`.
    - Stores the config file as `/etc/log4shell-listen.ini`.
    - Stores the service unit as `/etc/systemd/system/log4shell-listen.service`.
    - Refreshes the daemon and enables & starts the service.
- **All of the above will and must be run as root.**

```bash
$ cd /usr/local/lib/bits-bt-scan-log4shell-{RELEASE_TAG}/log4shell-scan
# Make any necessary changes to install.conf and the two additional config files listed below.
$ sudo vim install.conf
$ sudo vim log4shell-scan/scanner/config.ini
$ sudo vim log4shell-scan/listener/log4shell.yaml
$ sudo chmod +x install.sh
$ sudo ./install.sh
```

### Configure

- Configure the install in [install.conf](./log4shell-scan/install.conf).
  - Must be done before running `./install.sh`.
- Configure the scan script in [config.ini](./log4shell-scan/scanner/config.ini).
  - May be done after install, the scanner will grab the latest config the next time it runs.
- Configure the listener in [log4shell.yaml](./log4shell-scan/listener/config.ini).
  - May be done after install, however *requires a restart to the listener system service* (`sudo systemctl restart log4shell-listen.service`).

### Uninstall

```bash
$ cd /usr/local/lib/bits-bt-scan-log4shell-{RELEASE_TAG}/log4shell-scan
$ sudo chmod +x uninstall.sh
$ sudo ./uninstall.sh
```

### Testing

- Replace ${GCP_PROJECT_NAME} and  ${GCP_PROJECT_ID} as appropriate.

```bash
gcloud compute instances create rhel-testing \
  --project=${GCP_PROJECT_NAME} \
  --zone=northamerica-northeast2-a \
  --machine-type=e2-micro \
  --network-interface=network-tier=PREMIUM,subnet=default \
  --maintenance-policy=MIGRATE \
  --service-account=${GCP_PROJECT_ID}-compute@developer.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --tags=rhel-testing \
  --create-disk=auto-delete=yes,boot=yes,device-name=rhel-testing,image=projects/rhel-cloud/global/images/rhel-7-v20220126,mode=rw,size=20,type=projects/bits-bt-sandbox/zones/northamerica-northeast2-a/diskTypes/pd-balanced \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --reservation-affinity=any

```
