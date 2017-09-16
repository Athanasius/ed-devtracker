#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Encode;
use Data::Dumper;

use ED::DevTracker::Config;
use ED::DevTracker::DB;

$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
    die "No config!\n";
}
my $db = new ED::DevTracker::DB('config' => $config);

my $sth = $db->dbh->prepare('SELECT id,url FROM posts WHERE guid_url IS NULL');
my $rv = $sth->execute();
if (!defined($rv)) {
  die('Error selecting all posts');
}

my $usth = $db->dbh->prepare('UPDATE posts SET guid_url = ? WHERE id = ?');
my $row;
while ($row = $sth->fetchrow_hashref()) {
  my $guid_url = ${$row}{'url'};
  # Strip the embedded topic title
  $guid_url =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)$/$+{'start'}/;
  $guid_url =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;
  printf STDERR "UPDATE posts SET guid_url = '%s' WHERE id = %d'\n", $guid_url, ${$row}{'id'};
  $rv = $usth->execute($guid_url, ${$row}{'id'});
  if (! $rv) {
    die("Error updating post: " . ${$row}{'id'});
  }
}

exit(0);
