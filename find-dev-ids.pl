#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use LWP;
use HTTP::Cookies;
use Digest::MD5 qw(md5_hex);
use HTML::TreeBuilder;

use ED::DevTracker::Config;
$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
    die "No config!";
}
my $ua = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36');
$ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));
###########################################################################
# First let's make sure we're logged in.
###########################################################################
my $login_url = 'https://forums.frontier.co.uk/login.php?do=login';
my $login_user = 'AthanRSS';
my $vb_login_password = 'SDq0lnWbcaDnoNKk';
my $vb_login_md5password = md5_hex($vb_login_password);
my $req = HTTP::Request->new('POST', $login_url);
$req->header('Origin' => 'https://forums.frontier.co.uk');
$req->header('Referer' => 'https://forums.frontier.co.uk/');
$req->header('Content-Type' => 'application/x-www-form-urlencoded');
$req->content(
  "vb_login_username=" . $login_user
  . "&vb_login_password=&vb_login_password_hint=Password&s=&securitytoken=guest&do=login"
  . "&vb_login_md5password=" . $vb_login_md5password
  . "&vb_login_md5password_utf=" . $vb_login_md5password
);
#print STDERR $req->content, "\n";
# [truncated] vb_login_username=AthanRSS&vb_login_password=&vb_login_password_hint=Password&s=&securitytoken=1414178470-60c7e8aa19051820a82e27d23d96f584eacc17e3&do=login&vb_login_md5password=d79cdd2e982bcac4944f3d97031c1fa5&vb_login_md5passw
#exit(0);
my $res = $ua->request($req);
if (! $res->is_success) {
  print STDERR "Failed to login: ", $res->status_line, "\n";
  exit(1);
}

#print $res->content, "\n";
#exit(0);
###########################################################################

my $url = 'https://forums.frontier.co.uk/member.php?u=';
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
  'Suspended / Banned' => 1,
  'Banned: Annoying Spam Bot' => 1,
  'Moderator' => 1,
  'International Moderator' => 1,
  'Former Frontier Employee' => 1
);

$req = HTTP::Request->new('GET', 'http://forums.frontier.co.uk/index.php');
$res = $ua->request($req);
if (! $res->is_success) {
  print STDERR "\nFailed to retrieve forum front page\n";
  exit(1);
}
my $tree = HTML::TreeBuilder->new;
$tree->parse($res->decoded_content);
$tree->eof();
$tree->elementify();
my $wgo = $tree->look_down(_tag => 'div', id => 'wgo');
if (!$wgo) {
  print STDERR "\nCouldn't find the div 'wgo' on front page\n";
  exit(2);
}
my $wgo_stats = $wgo->look_down(_tag => 'div', id => 'wgo_stats');
if (!defined($wgo_stats)) {
  print STDERR "\nCouldn't find the div 'wgo_stats'\n";
  exit(3);
}
my @p = $wgo_stats->look_down(_tag => 'p');
if (!defined($p[0])) {
  print STDERR "\nCouldn't find the the first 'p' under 'wgo_stats'\n";
  exit(4);
}
my $a = $p[0]->look_down(_tag => 'a');
my $latest_url = $a->attr('href');
$latest_url =~ s/\&s=[0-9a-f]+//;
if ($latest_url !~ /^member\.php\?u=(?<uid>[0-9]+)$/) {
  printf STDERR "\nCouldn't find ID in latest member URL: '%s'\n";
  exit(5);
}
my $latest_id = $+{'uid'};
undef $tree;

#print "Latest member: ", $latest_id, "\n";
#exit(0);

select STDOUT;
$| = 1;
my $id = 98853; # STARTID LASTID FIRSTID (No, I can never remember what to search on to get to this line).
printf "Scanning from %d to %d\n...", $id, $latest_id;
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
  my $userinfo = $tree->look_down(_tag => 'span', id => 'userinfo');
  if (!$userinfo) {
    print STDERR "\nCouldn't find the span 'userinfo' on member page\n";
    #print "\n", $tree->dump, "\n";
    #$id++; next;
    #exit(4);
    $id++;
    next;
  }
  my $usertitle = $userinfo->look_down(_tag => 'span', class => 'usertitle');
  if (!$usertitle) {
    print STDERR "\nCouldn't find the span 'usertitle'\n";
    print "\n", $tree->dump, "\n";
    #exit(4);
    $id++;
    next;
  }
  if (!defined($uninteresting{$usertitle->as_text})) {
    if (!defined($titles{$usertitle->as_text})) {
      $titles{$usertitle->as_text} = $id;
    }
    print "\n", $id, ": ", $usertitle->as_text, "\n";
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
