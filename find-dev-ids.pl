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

my $req = HTTP::Request->new('GET', 'http://forums.frontier.co.uk/index.php');
my $res = $ua->request($req);
if (! $res->is_success) {
  print STDERR "\nFailed to retrieve forum front page\n";
  exit(1);
}
my $tree = HTML::TreeBuilder->new;
$tree->parse($res->decoded_content);
$tree->eof();
$tree->elementify();
my $stats = $tree->look_down(_tag => 'tbody', id => 'collapseobj_forumhome_stats');
if (!$stats) {
  print STDERR "\nCouldn't find the tbody 'collapseobj_forumhome_stats' on front page\n";
  exit(2);
}
my @divs = $stats->look_down(_tag => 'div');
if (!defined($divs[2])) {
  print STDERR "\nCouldn't find the 3rd div uner the stats tbody\n";
  exit(3);
}
my $a = $divs[2]->look_down(_tag => 'a');
if (!$a) {
  print STDERR "\nCouldn't find the href under the 3rd div\n";
  exit(4);
}
my $latest_url = $a->attr('href');
$latest_url =~ s/\?s=[^\&]+\&/\?/;
if ($latest_url !~ /^member\.php\?u=(?<uid>[0-9]+)$/) {
  print STDERR "\nCouldn't find ID in latest member URL\n";
  exit(5);
}
my $latest_id = $+{'uid'};
undef $tree;

select STDOUT;
$| = 1;
my $id = 50050;
while ($id <= $latest_id) {
  print STDERR "$id, ";
	$req = HTTP::Request->new('GET', $url . $id);
	$res = $ua->request($req);
	if (! $res->is_success) {
    print STDERR "\nFailed to retrieve ID: ", $id, "\n";
    $id++;
    next;
  }
  $tree = HTML::TreeBuilder->new;
  $tree->parse($res->decoded_content);
  $tree->eof();
  $tree->elementify();
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

print "\n";
if (keys(%titles) > 0) {
  print "\nNew titles found:\n";
  foreach my $t (sort(keys(%titles))) {
    print $titles{$t}, ": ", $t, "\n";
  }
}
