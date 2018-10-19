#!/usr/bin/perl -w -I.
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use JSON;

use ED::DevTracker::Config;
use ED::DevTracker::DB;

$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
  die("Couldn't find server-side config");
}
my $db = new ED::DevTracker::DB('config' => $config);

my %keys;
my $rows = $db->dbh->selectall_hashref('SELECT * FROM (SELECT DISTINCT ON (pl.who) pl.who, pl.datestamp, pl.id FROM posts pl JOIN (SELECT DISTINCT who,id,datestamp FROM posts ORDER BY who,datestamp DESC) pd ON pd.id = pl.id) AS o ORDER BY o.datestamp DESC', 'datestamp');
if (!defined($rows)) {
  die("No results!");
}

print<<EOH;
<html>
 <head>
  <title>
   Last Forum posting times for each tracked Frontier 'developer'.
  </title>
 </head>
 <body>
  <table>
   <tr><th>Who</th><th>Date and time of last detected post</th></tr>
EOH
foreach my $r (sort({$b cmp $a} keys(%$rows))) {
  #print Dumper(%$rows{$r}), "\n";
  printf("   <tr><td>%s</td><td>%s UTC</td></tr>\n", $rows->{$r}->{'who'}, $rows->{$r}->{'datestamp'});
}

print<<EOH;
  </table>
 </body>
</html>
EOH
exit(0);
