#!/bin/sh

exec pg_dump -h db.fysh.org --schema-only -U ed_devtracker_crawl_dev ed_devtracker_dev
