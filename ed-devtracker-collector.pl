#!/usr/bin/perl -w -I.
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Encode;
use Data::Dumper;

use JSON::PP;
use LWP;
use HTTP::Cookies;
use Digest::MD5 qw(md5_hex);
use File::Flock;

use ED::DevTracker::Config;
use ED::DevTracker::DB;
use ED::DevTracker::Scrape;
use ED::DevTracker::RSS;

$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
    die "No config!\n";
}
my $lock = new File::Flock("ed-devtracker-collector.lock", undef, "nonblocking");
if (! $lock) {
  die "Couldn't obtain lock\n";
}
my $db = new ED::DevTracker::DB('config' => $config);

my $ua = LWP::UserAgent->new('agent' => $config->getconf('user_agent'));
$ua->timeout($config->getconf('ua_timeout'));
$ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));

my $rss_filename = $config->getconf('self_url');
$rss_filename =~ s/^(.+)\/([^\/]+)/$2/;
if (! -f $rss_filename) {
  my $cwd = `pwd`;
  chomp($cwd);
  printf STDERR "RSS file %s doesn't exist at %s, did you forget to cd before running this script?\n", $rss_filename, $cwd;
  exit(4);
}

my $developers;
{
  local $/ = undef;
  if (!open(MEMBERIDS, $config->getconf('memberid_file'))) {
    printf STDERR "Failed to open memberid file '%s'\n", $config->getconf('memberid_file');
    exit(-1);
  }
  binmode MEMBERIDS;
  my $member_ids = <MEMBERIDS>;
  close(MEMBERIDS);
  #print STDERR $member_ids, "\n";
  $developers = decode_json($member_ids);
  #print STDERR Dumper($developers);
#  print STDERR Dumper( map { if ($_->{'active'}) { $_->{'memberid'}; } } @{$developers->{'members'}});
  #exit(0);
}

my @forums_ignored;
{
  local $/ = undef;
  if (!open(FORUMIGNORES, $config->getconf('forum_ignore_file'))) {
    printf STDERR "Failed to open forum ignore file '%s'\n", $config->getconf('forum_ignore_file');
    exit(-1);
  }
  binmode FORUMIGNORES;
  my $forums_ignored_input = <FORUMIGNORES>;
  close(FORUMIGNORES);
#  print STDERR $forums_ignored_urls, "\n";
  my $forums_ignored_json = decode_json($forums_ignored_input);
#  print STDERR Dumper($forums_ignored_json);
  foreach my $f (keys(%{$forums_ignored_json})) {
    #printf STDERR "Forum ignore: %s\n", $f;
    push(@forums_ignored, $forums_ignored_json->{$f}->{'id'});
  }
  #print Dumper(sort(@forums_ignored));
  #exit(0);
}

###########################################################################
# First let's make sure we're logged in.
###########################################################################
# Load the login page to get cookies set up
my $login_form_url = $config->getconf('forum_base_url') . "/login";
my $lf_req = HTTP::Request->new('GET', $login_form_url, ['Connection' => 'close']);
my $lf_res = $ua->request($lf_req);
#print $lf_res->as_string;
#print Dumper($lf_res->content);
my $tree = HTML::TreeBuilder->new(no_space_compacting => 1);
$tree->parse($lf_res->decoded_content());
$tree->eof();
my $xft = $tree->look_down('name', '_xfToken');
if (! $xft) {
  print STDERR $lf_res->decoded_content(), "\n";
  die("Failed login: can't find _xfToken");
} #else {
#  printf STDERR "Got _xfToken\n";
#  exit(0);
#}
my $xfToken =  $xft->attr_get_i('value');
undef $tree;

my $login_url = $config->getconf('forum_base_url') . "/login/login";
my $login_user = $config->getconf('forum_user');
my $login_password = $config->getconf('forum_password');
my $req = HTTP::Request->new('POST', $login_url, ['Connection' => 'close']);
$req->header('Origin' => $config->getconf('forum_base_url') . "/login");
$req->header('Referer' => $config->getconf('forum_base_url') . "/login");
$req->header('Content-Type' => 'application/x-www-form-urlencoded');
$req->content(
  "login=" . $login_user
  . "&password=" . $login_password
  . "&remember=1"
  . "&_xfRedirect=/"
  . "&_xfToken=" . $xfToken
);
#print STDERR Dumper($req), "\n";
#print STDERR $req->as_string, "\n";
#exit(0);
my $res = $ua->request($req);
#print STDERR $res->as_string;
#print STDERR Dumper($res->content);
# In XenForo 2 HTTP 303 (See Other) indicates login success
# HTTP 200 (success) means "already logged in"
if ($res->code != 303 and ! $res->is_success) {
  print STDERR "Failed to login: ", $res->status_line, "\n";
  exit(1);
}
#exit(0);

#printf STDERR "Login done\n";
#exit(0);
###########################################################################

my $new_posts_total = 0;
# $new_posts_total = 1; goto RSS_OUTPUT;
my $scrape = new ED::DevTracker::Scrape($ua, \@forums_ignored);
foreach my $whoid ( sort({$a <=> $b} map { $_->{'memberid'} } grep { $_->{'active'} } @{$developers->{'members'}})) {
  my $err;

#  if ($whoid < 106358) { next; }
#  print STDERR "Scraping id ", $whoid, "\n";
  my $bail = 99999999;
  if ($whoid > $bail) {
    print STDERR "Bailing after id ", $bail, "\n";
    last;
  }

  my $membername = sprintf("%s", map {$_->{'membername'}} grep { $_->{'memberid'} eq $whoid } @{$developers->{'members'}});
  my $new_posts = $scrape->get_member_new_posts($whoid, $membername);
	
# if ($err) {
#   die("Failed post: $post{'url'}\n");
# }

  # We're popping off an array so as to reverse the order we found them
  # else they'll go in the DB in the wrong order.
  #print STDERR "Adding posts for ", $whoid, " START\n";
  my $p = pop(@{$new_posts});
  while (defined($p)) { 
	  #print STDERR Dumper($p), "\n";
    if (${$p}{'datestamp'}) {
	    $db->insert_post($p);
    }
    $new_posts_total++;
    $p = pop(@{$new_posts});
  } 
#  printf STDERR "new_posts_total now: %d\n", $new_posts_total;
}
RSS_OUTPUT:
if ($new_posts_total > 0) {
  #printf "Found %d new posts.\n", $new_posts_total;

  generate_rss_file('false', $config->getconf('self_url'));
  generate_rss_file('true', $config->getconf('self_fulltext_url'));
}
# Sleep to be sure we don't run back to back if the forums are straining
if (defined($config->getconf('sleep_after')) and $config->getconf('sleep_after') > 0 ) {
#  printf STDERR "Sleeping for %d seconds\n", $config->getconf('sleep_after');
  sleep($config->getconf('sleep_after'));
}
exit(0);

###########################################################################
# Generate an RSS file, either with or without fulltext
###########################################################################
sub generate_rss_file {
  my ($fulltext, $self_url) = @_;

  my $rss = new ED::DevTracker::RSS($fulltext, $self_url);
  if (! $rss->generate()) {
    printf STDERR "Something failed in RSS generation.\n";
    exit(1);
  } else {
#    print STDERR "Generation good\n";
  }
  $rss_filename = $self_url;
  $rss_filename =~ s/^(.+)\/([^\/]+)/$2/;
  my $tmp_name = $rss_filename . ".tmp";
  if (!open(TMP, ">:encoding(utf-8)", "$tmp_name")) {
    print STDERR "Couldn't open temporary file '", $tmp_name, "': ", $!, "\n";
    exit(2);
  }
  # Turn on auto-flush, to be SURE those changes are on disk by the time
  # anything else reads them.
  my $old_fh = select(TMP);
  $| = 1;
  select($old_fh);
  if (!print TMP $rss->output) {
    print STDERR "Error writing to tmp RSS file '", $tmp_name, "': ", $!, "\n";#
    exit(3);
  }
  close(TMP);
  # mv tmp to live
  rename($tmp_name, $rss_filename);
  chmod(0644, $rss_filename);
}
###########################################################################
