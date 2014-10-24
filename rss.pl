#!/usr/bin/perl -C -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use ED::DevTracker::RSS;

my $rss = new ED::DevTracker::RSS;
my $r = $rss->generate;
if (!$r) {
  exit(1);
}
$rss->print;

