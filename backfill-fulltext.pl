#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Encode;
use Data::Dumper;

use LWP;
use HTTP::Cookies;
use Digest::MD5 qw(md5_hex);

use ED::DevTracker::Config;
use ED::DevTracker::DB;
use ED::DevTracker::Scrape;

$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
    die "No config!\n";
}
my $db = new ED::DevTracker::DB('config' => $config);

my $ua = LWP::UserAgent->new('agent' => $config->getconf('user_agent'));
$ua->timeout($config->getconf('ua_timeout'));
$ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));

###########################################################################
# First let's make sure we're logged in.
###########################################################################
my $login_url = 'https://forums.frontier.co.uk/login.php?do=login';
my $login_user = $config->getconf('forum_user');
my $vb_login_password = $config->getconf('forum_password');
my $vb_login_md5password = md5_hex($vb_login_password);
my $req = HTTP::Request->new('POST', $login_url, ['Connection' => 'close']);
$req->header('Origin' => 'http://forums.frontier.co.uk');
$req->header('Referer' => 'http://forums.frontier.co.uk/');
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

#print STDERR Dumper($res->content);
#exit(0);
###########################################################################

###########################################################################
# Start the backfill
###########################################################################
my $scrape = new ED::DevTracker::Scrape;
my $lastid = 2 ** 31 - 1;
my $fillpost = $db->newest_without_fulltext($lastid);
while ($lastid > 0 and defined($fillpost)) {
  $lastid = $fillpost->{'id'};
  printf STDERR "Newest without fulltext: %d %s\n", $fillpost->{'id'}, $fillpost->{'guid_url'};

  my $fulltext = $scrape->get_fulltext($fillpost->{'guid_url'});
  if (!defined($fulltext->{'error'})) {
#    print STDERR Dumper($fulltext), "\n";
    if (! $db->update_old_with_fulltext($fillpost->{'id'}, $fulltext->{'fulltext'}, $fulltext->{'fulltext_stripped'}, $fulltext->{'fulltext_noquotes'}, $fulltext->{'fulltext_noquotes_stripped'}) ) {
      print STDERR "Failed to insert into DB so bailing\n";
      last;
    }
  } else {
  # Error
    if (defined($fulltext->{'error'}{'http_code'})) {
      exit(0);
    } else {
      printf STDERR "Failed to get fulltext for %s\n", $fillpost->{'guid_url'};
      if (defined($fulltext->{'error'}{'thread_invalid'})
          or defined($fulltext->{'error'}{'post_invalid'})) {
        printf STDERR "Setting post as unavailable: %d\n", $fillpost->{'id'};
        $db->set_post_unavailable($fillpost->{'id'});
      } else {
        exit(0);
      }
      #sleep(5);
      #last;
    }
  }

#  print STDERR "Testing, so bailing after first\n"; last;
  sleep(1);
  $fillpost= $db->newest_without_fulltext($lastid);
}
###########################################################################

exit(0);
