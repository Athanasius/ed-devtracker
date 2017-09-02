#!/usr/bin/perl -w -I.
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use CGI;
use JSON;

use ED::DevTracker::Config;
use ED::DevTracker::DB;

$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
  failure("Couldn't find server-side config");
}
my $db = new ED::DevTracker::DB('config' => $config);
my $cgi = CGI->new;
print $cgi->header(-type => "application/json", -charset => "utf-8");
if (!defined($cgi->multi_param('search_text'))) {
  failure("No search text supplied");
}

my $results = $db->ts_search($cgi->multi_param('search_text'), $cgi->multi_param('search_in_title'), $cgi->multi_param('search_in_precis'));
if (!defined($results)) {
  failure("No results!");
}

my %status = ( 'status' => 'ok' );

$status{'results'} = $results;
my $json = to_json(\%status);
print $json;
exit(0);

###########################################################################
# Return Failure
###########################################################################
sub failure {
  my $reason = shift;

  my %status = ( 'status' => 'fail', 'reason' => $reason );
  my $json = to_json(\%status);

  print $json;
  exit(0);
}
###########################################################################
