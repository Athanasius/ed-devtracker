#!/usr/bin/perl -w -I.
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

my $sth = $db->dbh->prepare('SELECT id,url FROM posts WHERE id > 28779 ORDER BY id ASC');
my $rv = $sth->execute();
if (!defined($rv)) {
  die('Error selecting all posts');
}

my $usth = $db->dbh->prepare('UPDATE posts SET guid_url = ? WHERE id = ?');
my $row;
while ($row = $sth->fetchrow_hashref()) {
  my $guid_url = ${$row}{'url'};
  # Strip the embedded topic title
  #$guid_url =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)$/$+{'start'}/;
  #$guid_url =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;

  # showthread.php?t=209770
  $guid_url =~ s/showthread\.php\?t=(?<postid>[0-9]+)$/\/posts\/$+{'postid'}\//;
  # showthread.php?p=857694#post857694
  $guid_url =~ s/^showthread\.php\?p=(?<postid>[0-9]+)\#post[0-9]+$/\/posts\/$+{'postid'}\//;
  # showthread.php?t=51464&p=902587#post902587
  $guid_url =~ s/^showthread\.php\?t=[0-9]+\&p=(?<postid>[0-9]+)\#post([0-9]+)?$/\/posts\/$+{'postid'}\//;
  # showthread.php/65600?p=6310080#post6310080
  $guid_url =~ s/^showthread\.php\/[0-9]+\?p=(?<postid>[0-9]+)\#post[0-9]+$/\/posts\/$+{'postid'}\//;
  # showthread.php/261992-CQC-against-the-devs-The-Danger-Zone-Tonight-at-7PM-BST
  $guid_url =~ s/^showthread\.php\/(?<postid>[0-9]+)-[^\#]+$/\/posts\/$+{'postid'}\//;
  # showthread.php/481354-New-Forums-Release-Date-and-Downtime?p=7484944#post7484944
  $guid_url =~ s/^showthread\.php\/[0-9]+-[^?]+\?p=(?<postid>[0-9]+)\#post[0-9]+$/\/posts\/$+{'postid'}\//;

#  printf STDERR "UPDATE posts SET guid_url = '%s' WHERE id = %d'\n", $guid_url, ${$row}{'id'};
  $rv = $usth->execute($guid_url, ${$row}{'id'});
  if (! $rv) {
    printf STDERR "Error updating post: %d\n", ${$row}{'id'};
    printf STDERR "URL is: '%s'\n", ${$row}{'url'};

    if (${$row}{'url'} =~ /showthread\.php\?t=[0-9]+$/) {
      printf STDERR "Old-style topic-id ONLY post, fix later\n\n";
      next;
    }

    if (${$row}{'url'} =~ /showthread\.php\/[0-9]+-[^\?]+$/) {
      printf STDERR "vBulletin topic-only, fix later\n\n";
      next;
    }

    my $trimmed_url;
    my $old_trimmed_url;
    my $dsth;
    # showthread.php/263368-For-the-love-of-engineers?p=4065550#post4065550
    if (${$row}{'url'} =~ /^showthread\.php\/(?<threadid>[0-9]+)(-[^\?]+)\?(?<post>p=[0-9]+\#post[0-9]+)$/) {
      print STDERR "This url includes a post title\n";
      $trimmed_url = ${$row}{'url'};
      $trimmed_url =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;
      $old_trimmed_url = $trimmed_url;
      $old_trimmed_url =~ s/\.php\/(?<threadid>[0-9]+)\?(?<postid>p=[0-9]+)/\.php\?t=$+{'threadid'}\&$+{'postid'}/;
      $dsth = $db->dbh->prepare('SELECT * FROM posts WHERE url = ? OR url = ?');
      $rv = $dsth->execute($trimmed_url, $old_trimmed_url);
    } elsif (${$row}{'url'} =~ /^showthread\.php\?t=(?<threadid>[0-9]+)\&p=(?<postid>[0-9]+)#post[0-9]+$/) {
      print STDERR "This url is an old t= style one\n";
      $trimmed_url = ${$row}{'url'};
      $old_trimmed_url = sprintf("showthread.php/%s-%%?p=%s\#post%s", $+{'threadid'}, $+{'postid'}, $+{'postid'});
      $dsth = $db->dbh->prepare('SELECT * FROM posts WHERE url = ? OR url LIKE ?');
      $rv = $dsth->execute($trimmed_url, $old_trimmed_url);
    }
    if (defined($trimmed_url)) {
      printf STDERR "Trimmed URL: %s\n", $trimmed_url;
    }
    if (defined($old_trimmed_url)) {
      printf STDERR "OLD Trimmed URL: %s\n", $old_trimmed_url;
    }

    if (! $rv) {
        die("Error checking for duplicate, trimmed version of url");
    }
    my $dupe;
    my $dupe_deleted;
    while ($dupe = $dsth->fetchrow_hashref()) {
      printf STDERR "Dupe's URL: '%s'\n", ${$dupe}{'url'};
      # So delete this one
      $rv = $db->dbh->do("DELETE FROM posts WHERE id = " . ${$row}{'id'});
      if (! $rv) {
        die("Error deleting dupe");
      }
      printf STDERR "Deleted %d\n\n", ${$row}{'id'};
      $dupe_deleted = 1;
      last;
    }
    if (!defined($dupe_deleted)) {
      die("Didn't find a dupe to delete");
    }
  }
  print "\n";
}

exit(0);
