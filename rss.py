#!/usr/bin/env python3
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

import sys, os
import yaml
import logging
import argparse
import pprint
pp = pprint.PrettyPrinter(indent=2, depth=10, compact=False)

import eddtrss
###########################################################################
"""
 "  Configuration
  """
###########################################################################
__configfile_fd = os.open("config.txt", os.O_RDONLY)
__configfile = os.fdopen(__configfile_fd)
__config = yaml.load(__configfile, Loader=yaml.CLoader)
###########################################################################

###########################################################################
# Logging
###########################################################################
os.environ['TZ'] = 'UTC'
__default_loglevel = logging.INFO
__logger = logging.getLogger('RSSpy')
__logger.setLevel(__default_loglevel)
__logger_ch = logging.StreamHandler()
__logger_ch.setLevel(__default_loglevel)
__logger_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(module)s.%(funcName)s: %(message)s')
__logger_formatter.default_time_format = '%Y-%m-%d %H:%M:%S';
__logger_formatter.default_msec_format = '%s.%03d'
__logger_ch.setFormatter(__logger_formatter)
__logger.addHandler(__logger_ch)
###########################################################################

###########################################################################
# Command-Line Arguments
###########################################################################
__parser = argparse.ArgumentParser()
__parser.add_argument("--loglevel", help="set the log level to one of: DEBUG, INFO (default), WARNING, ERROR, CRITICAL")
__args = __parser.parse_args()
if __args.loglevel:
  __level = getattr(logging, __args.loglevel.upper())
  __logger.setLevel(__level)
  __logger_ch.setLevel(__level)
###########################################################################

# database

def generate():
  __logger.debug('generate()')
  # posts = db->get_latest_posts(7)
  # Timezone is UTC
  # Set up RSS channel
  # Loop over posts

  ## Parse date
  ## Post date

  ## Description:
  ## If we have full text
  ### Perform necessary transforms
  ## Else just precis
  ### Convert \n to <br/>
  ### Insert post title URL at start
  ## fI

  ## Actually add post as RSS Item


def main():
  __logger.debug('Start-Up')

  print('db_name: {}'.format(__config.get('db_name')))

  __db = eddtrss.database("postgresql://" + __config.get('db_user') + ":" + __config.get('db_password') + "@" + __config.get('db_host') + "/" + __config.get('db_name'), __logger)
  posts = __db.get_latest_posts(7)
  for p in posts:
    print(p.id)

if __name__ == '__main__':
  main()
