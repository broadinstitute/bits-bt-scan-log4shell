# Broad log4shell Web Server Scan Tool

## Usage

### Get

```
$ wget --header "Authorization: token ${GITHUB_ACCESS_TOKEN}" 'https://api.github.com/repos/broadinstitute/bits-bt-scan-log4shell/releases/assets/...'
$ tar -xvf ...
$ cd ...
```

# Setup

```bash
# Make any necessary changes to install.conf and the two additional config files listed below.
$ chmod +x install.sh
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
