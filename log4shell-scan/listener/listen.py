#!/usr/bin/env python3
import socketserver
import os
import configparser
from bibtutils.slack import message
import traceback
import sys

from datetime import date
import logging

LDAP_HEADER = b"\x30\x0c\x02\x01\x01\x61\x07\x0a\x01\x00\x04\x00\x04\x00\x0a"
L4SL_CONFIG_FILE = ""


class TCPRequestHandler(socketserver.BaseRequestHandler):
    def handle(self) -> None:
        addr = self.client_address[0]
        logging.info(f"New connection from {addr}")

        sock = self.request
        sock.recv(1024)
        sock.sendall(LDAP_HEADER)

        data = sock.recv(1024)
        data = data[9:]

        data = data.decode(errors="ignore").split("\n")[0]
        logging.info(f"Extracted value: {data}")
        try:
            message.send_message(
                os.environ["L4SL_WEBHOOK"],
                title=":exclamation: *Exploitable Log4Shell Detected on Host* :exclamation: @here",
                text=f"- *host*: `{addr}`\n- *exploit info*: `{data}`",
                color="#ff0000",
            )
        except Exception as e:
            logging.critical(
                f"Exception caught while sending message to Slack: {type(e).__name__}: {e}"
            )
            stacktrace = "".join(traceback.format_exception(e))
            logging.critical(stacktrace)
            exit(1)


try:
    config_file = L4SL_CONFIG_FILE
    config = configparser.ConfigParser()
    config.read(config_file)
    for key in config["default"]:
        os.environ[f"L4SL_{key.upper()}"] = config["default"][key]

    LOG_DIR = os.environ.get("L4SL_LOG_DIR")
    if not os.path.exists(LOG_DIR):
        os.mkdir(LOG_DIR)
    logfile = f"{LOG_DIR}/{date.today().isoformat()}.log"
    logging.basicConfig(level=logging.DEBUG, filename=logfile)
    logging.info(f"Writing logs to: {logfile}")

    ip = os.environ["L4SL_LISTEN_IP"]
    port = int(os.environ["L4SL_LISTEN_PORT"])
    logging.info(f"Starting server on {ip}:{port}")
    with socketserver.TCPServer((ip, port), TCPRequestHandler) as server:
        logging.info("Serving...")
        server.serve_forever(poll_interval=5)

    logging.info("Exiting...")
except Exception as e:
    logging.critical(f"Error on listener: {type(e).__name__}: {e}")
    exc_type, exc_value, exc_traceback = sys.exc_info()
    stacktrace = "".join(
        traceback.format_exception(etype=exc_type, value=exc_value, tb=exc_traceback)
    )
    logging.critical(stacktrace)
    try:
        if len(stacktrace) > 300:
            stacktrace = "...\n" + stacktrace[:-300]
        message.send_message(
            os.environ["L4SL_WEBHOOK"],
            title=":exclamation: *Critical Error on log4shell-listen Script* :exclamation: @mobrien",
            text=(
                f"```{type(e).__name__}: {e}```\n"
                f"```{stacktrace}```\n"
                "_Note: this only means the script failed for some reason, not that a vulnerability was detected._"
            ),
            color="#ffa500",
        )
    except Exception as f:
        logging.critical(
            f"Exception caught while handling exception: {type(f).__name__}: {f}"
        )
        exc_type, exc_value, exc_traceback = sys.exc_info()
        stacktrace = "".join(
            traceback.format_exception(exc_type, exc_value, exc_traceback)
        )
        logging.critical(stacktrace)
    print(f"Exception caught, check logs for information: {logfile}")
    exit(1)
