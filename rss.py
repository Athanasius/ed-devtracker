#!/usr/bin/env python3
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

import sys, os
import yaml
import logging
import argparse
import pprint
pp = pprint.PrettyPrinter(indent=2, depth=10, compact=False)

import eddtrss

import PyRSS2Gen as RSS
import datetime
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

def generate(db, fulltext = True):
  __logger.debug('generate()')

  posts = db.get_latest_posts(7)

  items = []
  for p in posts:
    if (fulltext and p.fulltext):
      description = p.fulltext
      # This is far from simple.  We need to:
      # 0) Change the <blockquote class="postcontent restore"> into a div
      # 1) Change the class="bbcode_quote" <div> elements into <blockquote> elements, all of them.
      # 2) Remove the <img class="inlineimg" ... /> elements
      # 3) Remove the whole <i class="fa fa-quote-left"> element (or just the aria-hidden="true" attribute on it, but the element is moot anyway).
      # 4) Ensure the <a class="quotelink"...> element's href is fully qualified
    else:
      description = p.precis
     ### Convert \n to <br/>
     ### Insert post title URL at start

    ## Actually add post as RSS Item
    items.append(RSS.RSSItem(
      title           = p.who + " - " + p.threadtitle + " (" + p.forum + ")",
      link            = __config.get('forum_base_url') + p.url,
      description     = description,
      author          = p.who,
      comments        = p.forum,
      pubDate         = p.datestamp,
      guid            = __config.get('forum_base_url') + p.guid_url
    ))



  latest_date = posts[0].datestamp.strftime("%a, %e %b %Y %H:%M:%S +0000")
  # Set up RSS channel
  rss = RSS.RSS2(
    title           = 'Elite: Dangerous - Dev Posts (Unofficial Tracker)',
    link            = 'https://ed.miggy.org/devposts.html',
    description     = 'Elite: Dangerous Dev Posts (Unofficial Tracker)',
    language        = 'en',
    lastBuildDate   = latest_date,
    generator       = 'PyRSS2Gen from custom scraped data',
    managingEditor  = 'edrss@miggy.org (Athanasius)',
    webMaster       = 'edrss@miggy.org (Athanasius)',
    image           = RSS.Image(
      url             = 'https://ed.miggy.org/pics/elite-dangerous-favicon.png',
      title           = 'Elite: Dangerous - Dev Posts (Unofficial Tracker)',
      link            = 'https://ed.miggy.org/devposts.html',
      description     = 'Assets borrowed from Elite: Dangerous, with permission of Frontier Developments plc'
    ),
    items           = items
  )

  return rss

def main():
  __logger.debug('Start-Up')

  __db = eddtrss.database("postgresql://" + __config.get('db_user') + ":" + __config.get('db_password') + "@" + __config.get('db_host') + "/" + __config.get('db_name'), __logger)

  rss = generate(__db, fulltext=False)
  print(rss.to_xml())

if __name__ == '__main__':
  main()
