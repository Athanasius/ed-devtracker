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
my $login_user = $config->getconf('forum_user');
my $vb_login_password = $config->getconf('forum_password');
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
  'Former Frontier Employee' => 1,
  'Banned.User broke the forum rules in a bad way...' => 1,
  'Banned.' => 1,
  'Customer Support' => 1
);

### XXX $req = HTTP::Request->new('GET', 'http://forums.frontier.co.uk/index.php');
### XXX $res = $ua->request($req);
### XXX if (! $res->is_success) {
### XXX   print STDERR "\nFailed to retrieve forum front page\n";
### XXX   exit(1);
### XXX }
### XXX my $tree = HTML::TreeBuilder->new;
### XXX $tree->parse($res->decoded_content);
### XXX $tree->eof();
### XXX $tree->elementify();
### XXX my $wgo = $tree->look_down(_tag => 'div', id => 'wgo');
### XXX if (!$wgo) {
### XXX   print STDERR "\nCouldn't find the div 'wgo' on front page\n";
### XXX   exit(2);
### XXX }
### XXX my $wgo_stats = $wgo->look_down(_tag => 'div', id => 'wgo_stats');
### XXX if (!defined($wgo_stats)) {
### XXX   print STDERR "\nCouldn't find the div 'wgo_stats'\n";
### XXX   exit(3);
### XXX }
### XXX my @p = $wgo_stats->look_down(_tag => 'p');
### XXX if (!defined($p[0])) {
### XXX   print STDERR "\nCouldn't find the the first 'p' under 'wgo_stats'\n";
### XXX   exit(4);
### XXX }
### XXX my $a = $p[0]->look_down(_tag => 'a');
### XXX my $latest_url = $a->attr('href');
### XXX $latest_url =~ s/\&s=[0-9a-f]+//;
### XXX if ($latest_url !~ /^member\.php\?u=(?<uid>[0-9]+)$/) {
### XXX   printf STDERR "\nCouldn't find ID in latest member URL: '%s'\n";
### XXX   exit(5);
### XXX }
### XXX my $latest_id = $+{'uid'};
### XXX undef $tree;
## https://forums.frontier.co.uk/memberlist.php?order=desc&sort=joindate&pp=1
## <table id="memberlist_table" width="100%">
##        <tbody><tr class="columnsort">
##            <th><a class="blocksubhead" href="memberlist.php?order=asc&amp;sort=username&amp;pp=1">User Name </a></th>
##            <th><a class="blocksubhead" href="memberlist.php?order=asc&amp;sort=joindate&amp;pp=1">Join Date <img class="sortarrow" src="https://forums-cdn.frontier.co.uk/images/frontier/buttons/sortarrow-asc.png" alt="Reverse Sort Order" border="0" title="Reverse Sort Order"></a></th>
##            <th><a class="blocksubhead" href="memberlist.php?order=asc&amp;sort=posts&amp;pp=1">Posts </a></th>
##        </tr>
##      <tr>
##        <td class="alt1 username"><a href="member.php/141829-Arkanon" class="username">Arkanon</a> <span class="usertitle">Mostly Harmless</span></td>
##                                                                             ^^^^^^^^
##        <td class="joindate">Today</td>
##        <td class="postcount">2</td>
##      </tr>
##        </tbody></table>
my $latest_id = 141829;
my $tree;

#print "Latest member: ", $latest_id, "\n";
#exit(0);

select STDOUT;
$| = 1;
my $id = 137770; # STARTID LASTID FIRSTID (No, I can never remember what to search on to get to this line).
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

print "Now go post on the following to let people know you're not dead - https://forums.frontier.co.uk/showthread.php?t=52253\n";
