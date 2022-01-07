# Broad log4shell Web Server Scan Tool

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
- [Maven](https://packages.debian.org/bullseye/maven)
  - Will install it if it is not present.
- [default-jdk](https://packages.debian.org/bullseye/default-jdk)
  - Will install it if it is not present.

### Get

```
$ wget --header "Authorization: token ${GITHUB_ACCESS_TOKEN}" 'https://github.com/broadinstitute/bits-bt-scan-log4shell/archive/refs/tags/{RELEASE_TAG}.tar.gz'
$ sudo tar -xvf {RELEASE_TAG}.tar.gz /usr/local/lib
```

### Setup

```bash
$ cd /usr/local/lib/bits-bt-scan-log4shell-{RELEASE_TAG}
# Make any necessary changes to install.conf and the two additional config files listed below.
$ sudo vim install.conf
$ sudo vim log4shell-scan/scanner/config.py
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
$ chmod +x uninstall.sh
$ ./uninstall.sh
```
