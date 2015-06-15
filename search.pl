#!/usr/bin/perl -w -I.
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use CGI;

use ED::DevTracker::Config;
use ED::DevTracker::DB;

$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
  die "No config!\n";
}
my $db = new ED::DevTracker::DB('config' => $config);

my $cgi = CGI->new;
print $cgi->header(-type => "text/html", -charset => "utf-8");
if (!defined($cgi->param('search_text'))) {
  print<<EOHTML;
<html>
 <body>
  <p>
   No search text supplied
  </p>
 </body>
</html>
EOHTML
  exit(0);
}

my $results = $db->precis_ts_search($cgi->param('search_text'));
if (!defined($results)) {
  print<<EOHTML
<html>
 <body>
  <p>No results!
  </p>
 </body>
</html>
EOHTML
}
