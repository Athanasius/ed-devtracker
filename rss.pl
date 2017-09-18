#!/usr/bin/perl -C -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use ED::DevTracker::RSS;

my $rss = new ED::DevTracker::RSS('true', 'https://miggy.org/games/elite-dangerous/devtracker-dev/ed-dev-posts.rss');
my $r = $rss->generate;
if (!$r) {
  exit(1);
}
$rss->print;

