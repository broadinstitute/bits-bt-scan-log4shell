# Broad log4shell Web Server Scan Tool

## Usage

### Get

```
$ wget --header "Authorization: token ${GITHUB_ACCESS_TOKEN}" 'https://api.github.com/repos/broadinstitute/bits-bt-scan-log4shell/releases/assets/...'
$ tar -xvf ...
$ cd ...
```

# Setup

- Add the scanner to your crontab (`crontab -e`):
```
0 20 * * 1 sudo /usr/bin/masscan -v -p${TARGET_PORT_RANGE} ${TARGET_CIDR_RANGE} -oL /tmp/masscan.txt --max-rate 10000
0 10 * * * sudo /home/mobrien/log4shell-scanner/scan.py
```

<!-- Not yet supported
```
# cp ./log4shell-scan/listener/log4shell-listener.service /etc/systemd/system/
# systemctl daemon-reload
# systemctl enable log4shell-listener.service
# systemctl start log4shell-listener.service
# systemctl status log4shell-listener.service
``` -->

### Configure

- Configure the scan script in [config.py](./log4shell-scan/scanner/config.py).
- Configure the listener in [log4shell.yaml](./log4shell-scan/listener/log4shell.yaml).

