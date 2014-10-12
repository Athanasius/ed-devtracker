#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use XML::RSS;
use Date::Manip;

use ED::DevTracker::DB;

my $db = new ED::DevTracker::DB;
my $posts = $db->get_latest_posts(10);
my $base_url = "http://forums.frontier.co.uk/";

$ENV{'TZ'} = 'UTC';
my $date = new Date::Manip::Date;
$date->config(
 'DateFormat' => 'GB',
 'tz' => 'UTC'
);
my $err = $date->parse(${${$posts}[0]}{'datestamp'});
if ($err) {
  printf STDERR "rss.pl - Couldn't parse first posts date from DB\n";
  exit(1);
}

my $rss = XML::RSS->new(version => '2.0');
$rss->channel(
  title           => 'Elite: Dangerous Dev Posts',
  link            => 'http://www.miggy.org/games/elite-dangerous/devposts.html',
  language        => 'en',
  description     => 'Elite: Dangerous Dev Posts',
  pubDate         => $date->printf("%a, %e %b %Y %H:%M:%S %z"),
  managingEditor  => 'Athanasius <edrss@miggy.org>',
  webMaster       => 'Athanasius <edrss@miggy.org>'
);

foreach my $p (@{$posts}) {
  my $precis = ${$p}{'precis'};
  $precis =~ s/\n/<br\/>/g;
  $rss->add_item(
    title => ${$p}{'who'} . " - " . ${$p}{'threadtitle'},
    link  => $base_url . ${$p}{'url'},
    permaLink  => $base_url . ${$p}{'url'},
    description => "<a href=\"" . $base_url . ${$p}{'url'} . "\">" . ${$p}{'urltext'} . "</a>\n<p>" . $precis . "\n</p>",
    mode => 'append'
  );
}

print "Content-Type: application/rss+xml; charset=UTF-8\n\n";
print $rss->as_string;
