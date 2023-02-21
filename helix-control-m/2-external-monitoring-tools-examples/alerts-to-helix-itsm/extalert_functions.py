"""
(c) 2020 - 2022 Daniel Companeetz, BMC Software, Inc.
All rights reserved.

BSD 3-Clause License

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# SPDX-License-Identifier: BSD-3-Clause
For information on SDPX, https://spdx.org/licenses/BSD-3-Clause.html


Change Log
Date (YMD)    Name                  What
--------      ------------------    ------------------------
20230201      Daniel Companeetz     Initial work
20230215      Daniel Companeetz     Misc. fixes

"""

global debug
global alert_id

#########################################
# Make Python dict from CTM Alerts
#########################################
import re
def args2dict(tosplit, keys):
    def getkey(ls):
        for i in ls:
            if i is not None:
                return i.strip().rstrip(':')

    pattern = '|'.join(['(' + i + ')' for i in keys])
    lst = re.split(pattern, tosplit)

    lk = len(keys)
    elts = [((lst[i: i+lk]), lst[i+lk]) for i in range(1, len(lst), lk+1)]
    result = {getkey(i): j.strip() for i,j in elts}
    return result


#########################################
# Initialize logging for debug purposes
#########################################
# General logging settings
# next line is in case urllib3 (used with url calls) issues retry or other warnings.
def init_dbg_log(config={}):
    import logging
    from logging import handlers
    from os import path, getcwd
    from sys import stdout
    logging.captureWarnings(True)

    # Define dbg_logger
    global dbg_logger
    dbg_logger = logging.getLogger('__SendTickets__', )
    # Logging format string
    # dbg_format_str = '[%(asctime)s] - %(levelname)s - [%(filename)s:%(lineno)s - %(funcName)s()] %(message)s'
    dbg_format_str = '[%(asctime)s] - %(levelname)s - %(message)s'
    dbg_format = logging.Formatter(dbg_format_str)
    # logging to file settings
    base_dir = getcwd() + path.sep
    dbg_filename = base_dir + 'autoalert.log'
    dbg_file = logging.handlers.RotatingFileHandler(filename=dbg_filename, mode='a', maxBytes=1000000, backupCount=10,
                                                    encoding=None, delay=False)
    # dbg_file.setLevel(logging.INFO)
    dbg_file.setFormatter(dbg_format)

    # Logging to console settings
    dbg_console = logging.StreamHandler(stdout)
    # Debug to console is always INFO
    dbg_console.setLevel(logging.INFO)
    dbg_console.setFormatter(dbg_format)

    # General logging settings
    # dbg_logger.setLevel(logging.DEBUG)
    dbg_logger.addHandler(dbg_file)
    dbg_logger.addHandler(dbg_console)

    # Heading of new logging session
    # Default logging level
    dbg_logger.setLevel(logging.INFO)
    dbg_logger.info('*' * 50)
    dbg_logger.info('*' * 50)
    dbg_logger.info('Startup Log setting established. Initial level is INFO')

    try:
        env_file = getcwd() + path.sep + '.env.debug'
        config = dotenv_values(env_file)  # could render config = {"DEBUG": "true"}
        dbg_logger.info(f'File {env_file} was loaded. Setting debug to {config["DEBUG"]}.')
        debug = True if config['DEBUG'].lower() == 'true' else False
    except:
        dbg_logger.info(f'file {env_file} is not available. Setting debug to False.')
        config['DEBUG'] = 'false'
        debug = False

    # Setting logging level according to .env
    if debug:
        dbg_logger.setLevel(logging.DEBUG)
        dbg_logger.info('Startup logging to file level adjusted to debug (verbose)')
    else:
        dbg_logger.setLevel(logging.INFO)
        dbg_logger.info('Startup logging to file level is INFO')



    return dbg_logger, config

#########################################
# Write DBG info on assigning variable
#########################################
def dbg_assign_var(to_assign, what_is_this, logger, debug, alert_id=None):
    if debug:
        id = f'{alert_id} - ' if alert_id is not None else ''
        logger.debug (f'{id}{what_is_this}: {to_assign}')
    return to_assign


#########################################
# Helix Control-M and AAPI  functions
#########################################
# Connect to the (Helix) Control-M AAPI
from ctm_python_client.core.workflow import *
from ctm_python_client.core.comm import *
from ctm_python_client.core.monitoring import Monitor
from aapi import *
def ctmConnAAPI(host_name, token, logger):
    logger.debug('Connecting to AAPI')
    w = Workflow(Environment.create_saas(endpoint=f"https://{host_name}",api_key=token))
    monitor = Monitor(aapiclient=w.aapiclient)
    return monitor

#########################################
# Retrieve output
def ctmOutputFile(monitor, job_name, server, run_id, run_no, logger, debug):
    logger.debug("Retrieving output using AAPI")
    # Adding header for output file
    job_output = \
        f"*" * 70 + '\n' + \
        f"" + '\n'+ \
        f"Job output for {job_name} OrderID: {run_id}:{run_no}" + '\n'+ \
        f"" + '\n'+ \
        f"*" * 70 + '\n'

    # Retrieve output from the (Helix) Control-M environment
    output = dbg_assign_var(debug, monitor.get_output(f"{server}:{run_id}",
            run_no=run_no), "Output of job", logger)

    # If there is no output, say it
    if output is None :
        job_output = (job_output + '\n' +
                    f"*" * 70 + '\n' +
                    "NO OUTPUT AVAILABLE FOR THIS JOB" + '\n' +
                    f"*" * 70 )
    else:
        # Add retrieved output to header
        job_output = (job_output + '\n' +  output)

    return job_output

#########################################
# Retrieve log
def ctmlogFile(monitor, job_name, server, run_id, run_no, logger, debug):
    logger.debug("Retrieving log using AAPI")
    # Adding header for log file
    job_log = \
        f"*" * 70 + '\n' + \
        f"Job log for {job_name} OrderID: {run_id}" + '\n'+ \
        f"LOG includes all executions to this point (runcount: {run_no}" + '\n'+ \
        f"*" * 70 + '\n'
    # Retrieve log from the (Helix) Control-M environment
    log = dbg_assign_var(debug, monitor.get_log(f"{server}:{run_id}"), "Log of Job", dbg_logger)

    # If there is no output, say it
    if log is None :
        job_log = (job_log + '\n' +
                    f"*" * 70 + '\n' +
                    "NO LOG AVAILABLE FOR THIS JOB" + '\n' +
                    "INVESTIGATE. THIS IS NOT NORMAL." + '\n' +
                    f"*" * 70 )
    else:
        # Add retrieved output to header
        job_log = (job_log + '\n' +  log)

    return job_log

#########################################
# Write file to disk for attachment to case
import os
import tempfile
def writeFile4Attach(file_name, content, directory: str, logger, debug):
    if not os.path.exists(directory):
            directory=tempfile.gettempdir()
    file_2write =directory+os.sep+file_name
    fh = open(file_2write,'w')
    try:
        # Print message before writing
        logger.debug(f'Writing data to file {file_2write}')
        # Write data to the temporary file
        fh.write(content)
        # Close the file after writing
        fh.close()
    finally:
        # Print a message after writing
        logger.debug(f"File {file_2write} written")

    return file_2write


# Importing the email package
#From: https://stackoverflow.com/questions/3362600/how-to-send-email-attachments
import smtplib
from pathlib import Path
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.utils import COMMASPACE, formatdate
from email import encoders


def send_mail(send_from, send_to, subject, message,
              send_cc=None, send_bcc=None, files=[],
              server="localhost", port=587, username='', password='',
              use_tls=True):
    """Compose and send email with provided info and attachments.

    Args:
        send_from (str): from name
        send_to (list[str]): to name(s)
        send_cc (list[str]): to name(s)
        send_bcc (list[str]): to name(s)
        subject (str): message title
        message (str): message body
        files (list[str]): list of file paths to be attached to email
        server (str): mail server host name
        port (int): port number
        username (str): server auth username
        password (str): server auth password
        use_tls (bool): use TLS mode
    """

    assert isinstance(send_to, list)

    if send_cc is not None:
        assert isinstance(send_cc, list)
    if send_bcc is not None:
        assert isinstance(send_bcc, list)


    msg = MIMEMultipart()
    msg['From'] = send_from
    msg['To']  = COMMASPACE.join(send_to)
    msg['Cc']  = COMMASPACE.join(send_cc) if send_cc is not None else ""
    msg['Bcc'] = COMMASPACE.join(send_bcc) if send_bcc is not None else ""
    msg['Date'] = formatdate(localtime=True)
    msg['Subject'] = subject

    msg.attach(MIMEText(message))

    for path in files:
        part = MIMEBase('application', "octet-stream")
        with open(path, 'rb') as file:
            part.set_payload(file.read())
        encoders.encode_base64(part)
        part.add_header('Content-Disposition',
                        'attachment; filename={}'.format(Path(path).name))
        msg.attach(part)

    with smtplib.SMTP(server, port) as smtp:
        if use_tls:
            smtp.starttls()
        smtp.login(username, password)
        smtp.send_message(msg)
        smtp.quit()

#########################################
# MAIN STARTS HERE
#########################################
assert __name__ != '__main__', 'Do not call me directly... This is existentially impossible!'
