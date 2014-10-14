#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use XML::RSS;
use Date::Manip;

use ED::DevTracker::RSS;

my $rss = new ED::DevTracker::RSS;
my $r = $rss->generate;
if (!$r) {
  exit(1);
}
$rss->output;

