#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Encode;
use Data::Dumper;

use LWP;
use HTTP::Cookies;
use Digest::MD5 qw(md5_hex);
use HTML::TreeBuilder;
use Date::Manip;

use ED::DevTracker::Config;
use ED::DevTracker::DB;
use ED::DevTracker::RSS;

$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
    die "No config!\n";
}
#my $db = new ED::DevTracker::DB('config' => $config);

# Pretend to be Google Chrome on Linux, Version 60.0.3112.113 (Official Build) (64-bit)
my $ua = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36');
$ua->timeout(10);
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

# Two quotes: https://forums.frontier.co.uk/showthread.php/374251-2-4-The-Return-Open-Beta-Update-3?p=5872557#post5872557
my $page_url = 'https://forums.frontier.co.uk/showthread.php/374251-2-4-The-Return-Open-Beta-Update-3?p=5872557#post5872557';
{
  if ($page_url !~ /\#post(?<postid>[0-9]+)$/) {
    printf STDERR "Couldn't find #postNNNNN in page URL: %s\n", $page_url;
    exit(-1);
  } # XXX - Also handle if it's the first post in thread
  my $postid = $+{'postid'};

  $req = HTTP::Request->new('GET', $page_url);
  $res = $ua->request($req);
  if (! $res->is_success) {
    printf STDERR "Failed to retrieve post page for '%s': (%d) %s\n", $page_url, $res->code, $res->message;
    exit(-2);
  }

  #print STDERR $res->header('Content-Type'), "\n";
  my $hct = $res->header('Content-Type');
  if ($hct =~ /charset=(?<ct>[^[:space:]]+)/) {
    $hct = $+{'ct'};
  } else {
    undef $hct;
  }
  #print STDERR "HCT: ", $hct, "\n";
	#print STDERR Dumper($res->content);
	#print STDERR Dumper($res->decoded_content('charset' => 'windows-1252'));
	my $tree = HTML::TreeBuilder->new(no_space_compacting => 1);
  if (!defined($hct) or ($hct ne 'WINDOWS-1252' and $res->content =~ /[\x{7f}-\x{9f}]/)) {
    #printf STDERR "Detected non ISO-8859-1 characters!\n";
    #exit (1);
	  $tree->parse(decode("utf8", encode("utf8", $res->decoded_content('charset' => 'windows-1252'))));
  } else {
	  $tree->parse(decode("utf8", encode("utf8", $res->decoded_content())));
  }
	$tree->eof();
  #print STDERR Dumper($tree);

	my $post_div = $tree->look_down('id', "post_message_" . $postid);
	if (! $post_div) {
	  printf STDERR "Failed to find the post div element for post %d\n", $postid;
	  exit(-3);
	}
	#print STDERR Dumper($post_div);
  printf STDERR "Full post text:\n'%s'\n", $post_div->as_HTML;

  my $post_div_stripped = $post_div;
  my @bbcode_quote = $post_div_stripped->look_down(_tag => 'div', class => 'bbcode_quote');
  foreach my $bbq (@bbcode_quote) {
    $bbq->delete_content;
  }
  my $text = $post_div_stripped->as_text;
  $text =~ s/[[:space:]]{2,}//g;
  printf STDERR "Stripped content (text):\n'%s'\n", $text;
  printf STDERR "Stripped content (HTML):\n'%s'\n", $post_div_stripped->as_HTML;

  my $new_content = $post_div->look_down(_tag => 'blockquote');
  if (! $new_content) {
    printf STDERR "Couldn't find main blockquote of post\n";
    exit(-4);
  }
  my @content = $new_content->content;
  #print STDERR Dumper(\@content);
  #printf STDERR "Blockquote as_text:\n'%s'\n", $new_content->content;
}
exit(0);
