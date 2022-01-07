# Broad log4shell Web Server Scan Tool

## Architecture

![Lucidchart](./lucidchart.png)
[link to latest version](https://lucid.app/lucidchart/434ccfcc-eb3b-4b82-b40c-f9f1a943cfc0/edit?viewport_loc=15%2C41%2C1790%2C1170%2C0_0&invitationId=inv_4c1416c8-da36-4a95-8337-c59e8cb457da)

## Usage

### Requirements

#### Pre-requirements
- **Debian**
  - Tested on Debian 10 (buster) and 11 (bullseye).
  - May work on other Linux distros but may also break things. So for now the install script will refuse to install on a non-Debian system.
- **Sudo privileges**
- [Python3](https://www.python.org/downloads/)
  - Tested on 3.8, 3.9, and 3.10. Will **not** be automatically installed and will terminate the install process.

#### Other Requirements

- [masscan](https://github.com/robertdavidgraham/masscan)
  - Will install it if it is not present.
- [maven](https://packages.debian.org/bullseye/maven)
  - Will install it if it is not present.
- [default-jdk](https://packages.debian.org/bullseye/default-jdk)
  - Will install it if it is not present.

### Get

```
$ wget --header "Authorization: token ${GITHUB_ACCESS_TOKEN}" 'https://github.com/broadinstitute/bits-bt-scan-log4shell/archive/refs/tags/{RELEASE_TAG}.tar.gz'
$ sudo tar -xvf {RELEASE_TAG}.tar.gz -C /usr/local/lib
```

### Setup

- Installation sets up three main tasks:
  - [masscan](https://github.com/robertdavidgraham/masscan):
    - Installs if it is not present.
    - Stores the cronjob as `/etc/cron.d/log4shell-masscan`
  - Scanner:
    - Installs Python requirements.
    - Stores the script as `/usr/local/sbin/log4shell-scan`
    - Stores the config file as `/etc/log4shell-scan.ini`
    - Stores the cronjob as `/etc/cron.d/log4shell-scan`
  - Listener:
    - Installs [maven](https://packages.debian.org/bullseye/maven) and [default-jdk](https://packages.debian.org/bullseye/default-jdk) if they are not present.
    - Builds and stores the `jar` as `/usr/share/java/log4shell-jar-with-dependencies.jar`
    - Adds it to the system services under `/etc/systemd/system/log4shell-listener.service`
    - Refreshes the daemon and enables & starts the service.
- **All of the above will and must be run as root.**

```bash
$ cd /usr/local/lib/bits-bt-scan-log4shell-{RELEASE_TAG}
# Make any necessary changes to install.conf and the two additional config files listed below.
$ sudo vim install.conf
$ sudo vim log4shell-scan/scanner/config.ini
$ sudo vim log4shell-scan/listener/log4shell.yaml
$ sudo chmod +x install.sh
$ sudo ./install.sh
```

### Configure

- Configure the install in [install.conf](/install.conf)
  - Must be done before running `./install.sh`
- Configure the scan script in [config.py](./log4shell-scan/scanner/config.py).
  - May be done after install, the scanner will grab the latest config the next time it runs.
- Configure the listener in [log4shell.yaml](./log4shell-scan/listener/log4shell.yaml).
  - May be done after install, however *requires a restart to the listener system service* (`sudo systemctl restart log4shell-listener.service`)

### Uninstall

```bash
$ cd /usr/local/lib/bits-bt-scan-log4shell-{RELEASE_TAG}
$ sudo chmod +x uninstall.sh
$ sudo ./uninstall.sh
```
