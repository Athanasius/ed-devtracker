#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Date::Manip;
use POSIX qw/strftime/;

my @dates = (
	"Today, 12:12 AM",
  "Yesterday, 8:29 AM",
  "10/10/2014, 5:24 PM",
  "30/09/2014, 10:54 PM",
  "09/30/2014, 10:54 PM"
);

for my $d (@dates) {
  my $date = new Date::Manip::Date;
  $date->config('DateFormat' => 'GB');
  my $err = $date->parse($d);
  if (!$err) {
    print "'", $d, "' -> '", $date->printf('%Y-%m-%d %H:%M:%S %Z'), "\n";
  } else {
    print "Couldn't parse '", $d, "'\n";
  }
}
