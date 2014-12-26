#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use LWP;
use HTTP::Cookies;
use Digest::MD5 qw(md5_hex);
use HTML::TreeBuilder;
use Date::Manip;
use File::Flock;

use ED::DevTracker::Config;
use ED::DevTracker::DB;
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

# Pretend to be Google Chrome on Linux, Version 38.0.2125.104 (64-bit)
my $ua = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36');
$ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));

my $rss_filename = 'ed-dev-posts.rss';
if (! -f $rss_filename) {
  my $cwd = `pwd`;
  chomp($cwd);
  printf STDERR "RSS file %s doesn't exist at %s, did you forget to cd before running this script?\n", $rss_filename, $cwd;
  exit(4);
}
my %developers = (
#  1 => 'fdadmin',
  2 => 'Michael Brookes',
  6 => 'David Walsh',
  7 => 'David Braben',
	8 => 'Colin Davis',
# 13 => 'Natalie Amos',
# 119 => 'Sam Denney',
	1110 => 'Stefan Mars',
# 1388 => 'Kyle Rowley',
# 1890 => 'Callum Rowley',
# 2017 => 'Alistair Lindsay',
	2323 => 'Carlos Massiah',
# 2724 => 'Carl Russell',
# 10691 => 'Gary Richards',
	14349 => 'Adam Woods',
	14849 => 'Simon Brewer',
	15645 => 'Ashley Barley',
	15655 => 'Sandro Sammarco',
	15737 => 'Andrew Barlow',
	17666 => 'Sarah Jane Avory',
  19388 => 'Andrew Gillett',
	22712 => 'Mike Evans',
  22717 => 'John Kelly',
#  22790 => 'Igor Terentjev',
  23261 => 'Raphael Gervaise',
  24195 => 'James Avery',
	24222 => 'Greg Ryder',
# 24659 => 'Josh Atack', # Former Frontier Employee
  24701 => 'Xavier Henry',
	25094 => 'Dan Davies',
	25095 => 'Tom Kewell',
	25591 => 'Anthony Ross',
	26549 => 'Mark Allen',
	26755 => 'Barry Clark',
	26966 => 'chris gregory',
	27713 => 'Selena Frost-King',
	27895 => 'Ben Parry',
  29088 => 'John Li',
	31252 => 'hchalkley',
	31307 => 'Jonathan Bottone',
	31348 => 'Kenny Wildman',
  31354 => 'Joe Hogan',
	31484 => 'Richard Benton',
  31810 => 'Ruben Penalva',
  31870 => 'Sergei Lewis',
  32114 => 'Daniel Varela',
#	32310 => 'Mark Boss', # Now only 'Competent'
	32348 => 'Jon Pace',
  32350 => 'Adam Waite',
	32352 => 'Aaron Gordon',
  32382 => 'Thomas Wiggins',
  32385 => 'oscar_sebio_cajaraville',
	32574 => 'Matt Dickinson',
  32802 => 'Laurie Cooper',
  32835 => 'Viktor Svensson',
  33100 => 'Bob Richardson',
  33396 => 'Eddie Symons', # 'Mostly Harmless' but active on Twitter as @bovaflux
	33683 => 'Mark Brett',
  34587 => 'arfshesaid',
	34604 => 'Matthew Florianz',
  35599 => 'Tom Clapham',
	47159 => 'Edward Lewis'
# Michael Gapper ?
);

###########################################################################
# First let's make sure we're logged in.
###########################################################################
my $login_url = 'https://forums.frontier.co.uk/login.php?do=login';
my $login_user = 'AthanRSS';
my $vb_login_password = 'SDq0lnWbcaDnoNKk';
my $vb_login_md5password = md5_hex($vb_login_password);
my $req = HTTP::Request->new('POST', $login_url);
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

my $member_url = 'http://forums.frontier.co.uk/member.php?tab=activitystream&type=user&u=';
my $new_posts_total = 0;
foreach my $whoid (sort({$a <=> $b} keys(%developers))) {
  print STDERR "Scraping id ", $whoid, "\n";
#  my $bail = 15645;
#  if ($whoid > $bail) {
#    print STDERR "Bailing after id ", $bail, "\n";
#    last;
#  }
  my $latest_post = $db->user_latest_known($whoid);
	if (!defined($latest_post)) {
	  $latest_post = { 'url' => 'nothing_yet' };
	}
	$req = HTTP::Request->new('GET', $member_url . $whoid);
	$res = $ua->request($req);
	if (! $res->is_success) {
	  print STDERR "Failed to retrieve profile page: ", $whoid, " (", $developers{$whoid}, ")\n";
	  next;
	}
	
	#print Dumper($res->content);
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($res->decoded_content);
	$tree->eof();
	my $activitylist = $tree->look_down('id', 'activitylist');
	if (! $activitylist) {
	  print STDERR "Failed to find the activitylist for ", $developers{$whoid}, " (" . $whoid, ")\n";
	  next;
	}
	
	my @posts = $activitylist->look_down(
	  _tag => 'li',
    sub { $_[0]->attr('class') =~ /forum_(post|thread)/; }
	);
  if (! @posts) {
    #print STDERR "Failed to find any posts for ", $developers{$whoid}, " (" . $whoid, ")\n";
    next;
  }
  #print STDERR "Posts: ", Dumper(\@posts), "\nEND Posts\n";
  #exit(0);
  my @new_posts;
	foreach my $p (@posts) {
	  my %post;
	
    my $content = $p->look_down(
      _tag => 'div',
      class => 'content hasavatar'
    );
	  if ($content) {
    # datetime
      my $span_date = $content->look_down(
        _tag => 'span',
        class => 'date'
      );
      my $span_time = $content->look_down(
        _tag => 'span',
        class => 'time'
      );
      $post{'datestampstr'} = $span_date->as_text;
      $post{'datestampstr'} =~ s/\xA0/ /g;
      #print STDERR "Date = '", $post{'datestampstr'}, "'\n";
      my $timestr = $span_time->as_text;
      #print STDERR "Time = '", $timestr, "'\n";
	    my $date = new Date::Manip::Date;
	    $date->config(
	      'DateFormat' => 'GB',
	      'tz' => 'UTC'
	    );
	    my $err = $date->parse($post{'datestampstr'});
	    if (!$err) {
	      $post{'datestamp'} = $date->secs_since_1970_GMT();
	      #print STDERR "Date: ", $date->printf('%Y-%m-%d %H:%M:%S %Z'), "\n";
	    }
	  }
	  # thread title and URL
	  my $div_title = $content->look_down(
      _tag => 'div',
      class => 'title'
    );
	  if ($div_title) {
      my @a = $div_title->look_down(
        _tag => 'a'
      );
      if (@a) {
        $post{'who'} = $a[0]->as_text;
        $post{'whourl'} = $a[0]->attr('href');
	      $post{'threadtitle'} = $a[1]->as_text;
	      $post{'threadurl'} = $a[1]->attr('href');
        $post{'forum'} = $a[2]->as_text;
	    }
	  }

    my $div_excerpt = $content->look_down(
      _tag => 'div',
      class => 'excerpt'
    );
    if ($div_excerpt) {
      $post{'precis'} = $div_excerpt->as_text;
    }

    my $div_fulllink = $content->look_down(
      _tag => 'div',
      class => 'fulllink'
    );
    if ($div_fulllink) {
      my $a = $div_fulllink->look_down(_tag => 'a');
      if ($a) {
        $post{'url'} = $a->attr('href');
        $post{'urltext'} = $a->as_text;
        #printf STDERR "Thread '%s' at '%s' new '%s'\n", $post{'threadtitle'}, $post{'threadurl'}, $post{'url'};
        # New: showthread.php?t=51464&p=902587#post902587
        # Old: showthread.php?p=902218#post902218
        my $p = $post{'url'};
        $p =~ s/t=[0-9]+\&//;
        my $l = ${$latest_post}{'url'};
        $l =~ s/t=[0-9]+\&//;
        #printf STDERR "Compare Thread '%s' at '%s'(%s) new '%s'(%s)\n", $post{'threadtitle'}, ${$latest_post}{'threadurl'}, ${$latest_post}{'url'}, $post{'threadurl'}, $post{'url'};
        if ($l eq $p) {
          #print STDERR "We already knew this post, bailing on: ", $post{'url'}, "\n";
          last;
        }
      }
    }
	
	  $post{'whoid'} = $whoid;
	  #print STDERR Dumper(\%post), "\n";
    push(@new_posts, \%post);
    $new_posts_total++;
	}
  # We're popping off an array so as to reverse the order we found them
  # else they'll go in the DB in the wrong order, particularly important
  # if more than one post by the same user has the same minute-resolution
  # datestamp.  Wrong order could lead to missing posts (we'll bail too soon).
  #print STDERR "Adding posts for ", $whoid, " START\n";
  my $p = pop(@new_posts);
  while (defined($p)) { 
	  #print STDERR Dumper($p), "\n";
	  $db->insert_post($p);
    $p = pop(@new_posts);
  } 
  #print STDERR "Adding posts for ", $whoid, " DONE\n";
}
if ($new_posts_total > 0) {
  #printf "Found %d new posts.\n", $new_posts_total;
  my $rss = new ED::DevTracker::RSS;
  if (! $rss->generate()) {
    printf STDERR "Something failed in RSS generation.\n";
    exit(1);
  } else {
    #print STDERR "Generation good\n";
  }
  my $tmp_name = $rss_filename . ".tmp";
  if (!open(TMP, ">$tmp_name")) {
    print STDERR "Couldn't open temporary file '", $tmp_name, "': ", $!, "\n";
    exit(2);
  }
  if (!print TMP $rss->output) {
    print STDERR "Error writing to tmp RSS file '", $tmp_name, "': ", $!, "\n";#
    exit(3);
  }
  close(TMP);
  # mv tmp to live
  rename($tmp_name, $rss_filename);
  chmod(0644, $rss_filename);
}
exit(0);
