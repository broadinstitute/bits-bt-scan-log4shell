# Log4Shell Scanner

![Lucidchart](../lucidchart.png)

## Usage

- Takes an input file from masscan or nmap's output `-oL` formatted as:

```
#masscan
open tcp 80 62.234.93.43 1639514780
open tcp 22 12.3.123.1 1639515000
# end

```

- Run with `python3 ./scan.py`

## Description

- Crafts log4shell exploit messages and sends them to the ports and IPs specified in the input file. The exploits it crafts are meant to be caught (if executed by the target) by [log4shell-tester](../log4shell-tester). One should not be running without the other.
- Configuration changes may be made in `config.py`.
- As of 1/5/22, it is running in the `bits-bt-aim-vmp-prod` project on the GCE VM `log4shell-listener`.
