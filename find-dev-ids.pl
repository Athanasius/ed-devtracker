#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use LWP;
use HTML::TreeBuilder;

my $ua = LWP::UserAgent->new;

my $url = 'http://forums.frontier.co.uk/member.php?u=';
my %titles;
my %uninteresting = (
  'Harmless' => 1,
  'Mostly Harmless' => 1,
  'Average' => 1,
  'Above Average' => 1,
  'Competent' => 1,
  'Dangerous' => 1,
  'Deadly' => 1,
  'Elite' => 1,
  'Banned' => 1,
  'Moderator' => 1,
  'International Moderator' => 1,
  'Former Frontier Employee' => 1
);

select STDOUT;
$| = 1;
my $id = 50077;
while ($id <= 51000) {
  print STDERR "$id, ";
	my $req = HTTP::Request->new('GET', $url . $id);
	my $res = $ua->request($req);
	if (! $res->is_success) {
    print STDERR "\nFailed to retrieve ID: ", $id, "\n";
    $id++;
    next;
  }
  my $tree = HTML::TreeBuilder->new;
  $tree->parse($res->decoded_content);
  $tree->eof();
  my $username_box = $tree->look_down(_tag => 'td', 'id' => 'username_box');
  if (!$username_box) {
    print STDERR "\nFailed to find 'username_box' for: ", $id, "\n";
    $id++;
    next;
  }
  my $title = $username_box->look_down(_tag => 'h2');
  if (!$title) {
    print STDERR "\nFailed to find 'title' H2 for: ", $id, "\n";
    $id++;
    next;
  }
  if (!defined($uninteresting{$title->as_text})) {
    if (!defined($titles{$title->as_text})) {
      $titles{$title->as_text} = $id;
    }
    print "\n", $id, ": ", $title->as_text, "\n";
  }
  $id++;
}
print "\nNew titles found:\n";
foreach my $t (sort(keys(%titles))) {
  print $titles{$t}, ": ", $t, "\n";
}
