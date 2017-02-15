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
  52 => 'BrettC', # Community Assistant
# 119 => 'Sam Denney',
	1110 => 'Stefan Mars',
# 1388 => 'Kyle Rowley',
# 1890 => 'Callum Rowley',
  2000 => 'Drew Wagar', # Book author, and driver of the 'Formidine Rift' mystery
# 2017 => 'Alistair Lindsay',
	2323 => 'Carlos Massiah',
# 2724 => 'Carl Russell',
  10691 => 'Gary Richards',
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
#	24222 => 'Greg Ryder', # Former employee
# 24659 => 'Josh Atack', # Former Frontier Employee
  24701 => 'Xavier Henry',
	25094 => 'Dan Davies',
	25095 => 'Tom Kewell',
	25591 => 'Anthony Ross',
	26549 => 'Mark Allen',
	26755 => 'Barry Clark',
	26966 => 'chris gregory',
	27713 => 'Selena Frost-King',
#	27895 => 'Ben Parry', # No longer at Frontier as of ~2015-05
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
  33396 => 'Eddie Symons',
#	33683 => 'QA-', # Mark Brett
  34587 => 'arfshesaid',
	34604 => 'Matthew Florianz',
  35599 => 'Tom Clapham',
	47159 => 'Edward Lewis',
# Michael Gapper ?
  65404 => 'Yokai', # Tutorial & Guide Writer
# 71537 => 'eft_recoil_org', # Friendly Spider/Scraper Bot
#  74198 => 'GalNet News', # GalNet News Transmissions are sponsored in part by the Bank of Zaonce.  Trust the Bank of Zaonce with your hard-earned credits. 
  74985 => 'GuyV', #FDEV
  78894 => 'Laura Massey', # 'Mostly Harmless' QA Tester <https://forums.frontier.co.uk/showthread.php?t=176323>
  81888 => 'Daniel G', # Frontier QA Team
  82776 => 'Frontier QA',
  84886 => 'Frontier Moderation Team', # Global Moderator
  93489 => 'SkyCline', # Test Account: Brett C So Dangerous, it's Fluffy.
#  94839 => 'QA-Donny', # Frontier QA Team
#  94841 => 'QA-Jonny', # Frontier QA Team
#  94842 => 'QA-Kae', # Frontier QA Team
  95307 => 'juanpablosans', # Localisation
  95888 => 'CMDR Vanguard', # Customer Support
  96285 => 'NotMatt', # Figment of your imagination
  97768 => 'Zac Antonaci', # Head of Community Management
#  97918 => 'Support-Black Arrow', # Customer Support Manager
#  97972 => 'Support-Sticks', # Customer Support
#  97973 => 'Support-Falcon', # Customer Support
#  97974 => 'Support-Taurus', # Customer Support
#  97975 => 'Support-Proton', # Customer Support
#  97976 => 'Support-Kosmos', # Customer Support
#  97977 => 'Support-Vanguard', # Customer Support
#  97978 => 'Support-Saturn', # Customer Support
#  97979 => 'Support-Delta', # Customer Support
#  97980 => 'Support-Atom', # Customer Support
#  97981 => 'Support-Titan', # Customer Support
#  97982 => 'Support-Ares', # Customer Support
#  97983 => 'Support-Vega', # Customer Support
#  97984 => 'Support-Miu', # Customer Support
#  98489 => 'FDTest1', # Administrator
  100780 => 'Ian Dingwall', # Senior Designer
  101652 => 'James Stimpson', # Senior Designer Elite: Dangerous
  102125 => 'Dav Stott', # Senior Server Developer
  106358 => 'Dale Emasiri', # Social Media Manager
  108846 => 'Steve Kirby', # Lead Games Designer
# 120185 => 'QA-Kit',
  148080 => 'Dominic Corner' # Programmer (Missions Team)
);

###########################################################################
# First let's make sure we're logged in.
###########################################################################
my $login_url = 'https://forums.frontier.co.uk/login.php?do=login';
my $login_user = $config->getconf('forum_user');
my $vb_login_password = $config->getconf('forum_password');
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
#exit(0);
my $res = $ua->request($req);
if (! $res->is_success) {
  print STDERR "Failed to login: ", $res->status_line, "\n";
  exit(1);
}

#print STDERR Dumper($res->content);
#exit(0);
###########################################################################

my $member_url = 'https://forums.frontier.co.uk/member.php?tab=activitystream&type=user&u=';
my $new_posts_total = 0;
foreach my $whoid (sort({$a <=> $b} keys(%developers))) {
  my $err;
  #print STDERR "Scraping id ", $whoid, "\n";
#  my $bail = 2;
#  if ($whoid > $bail) {
#    print STDERR "Bailing after id ", $bail, "\n";
#    last;
#  }
  my $latest_posts = $db->user_latest_known($whoid);
	if (!defined($latest_posts)) {
	  $latest_posts = { 'url' => 'nothing_yet' };
	}
  #print Dumper($latest_posts);
	$req = HTTP::Request->new('GET', $member_url . $whoid);
	$res = $ua->request($req);
	if (! $res->is_success) {
	  print STDERR "Failed to retrieve profile page: ", $whoid, " (", $developers{$whoid}, ")", $res->code, "(", $res->message, ")\n";
	  next;
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
      # <span class="date">Today,&nbsp;<span class="time">2:00 PM</span> · 4 replies and 284 views.</span>
      $post{'datestampstr'} = $span_date->as_text;
      $post{'datestampstr'} =~ s/\xA0/ /g;
      $post{'datestampstr'} =~ s/ . [0-9]+ replies and [0-9]+ views\.//;
      #print STDERR "Date = '", $post{'datestampstr'}, "'\n";
      my $timestr = $span_time->as_text;
      #print STDERR "Time = '", $timestr, "'\n";
	    my $date = new Date::Manip::Date;
	    $date->config(
	      'DateFormat' => 'GB',
	      'tz' => 'UTC'
	    );
	    $err = $date->parse($post{'datestampstr'});
	    if (!$err) {
	      $post{'datestamp'} = $date->secs_since_1970_GMT();
	      #print STDERR "Date: ", $date->printf('%Y-%m-%d %H:%M:%S %Z'), "\n";
	    } else {
        printf(STDERR "Problem parsing $post{'datestampstr'}, from $whoid\n");
      }
	  } else {
      print STDERR "No content (didn't find div->content/hasavatar)\n";
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
	    } else {
        print STDERR "No 'a' under div->title\n";
      }
	  } else {
      print STDERR "No div->title\n";
    }

    my $div_excerpt = $content->look_down(
      _tag => 'div',
      class => 'excerpt'
    );
    if ($div_excerpt) {
      $post{'precis'} = $div_excerpt->as_text;
    } else {
      print STDERR "No precis\n";
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
        # Newer: showthread.php/283153-The-Galaxy-Is-its-size-now-considered-to-be-a-barrier-to-gameplay-by-the-Developers?p=4414769#post4414769
        # New: showthread.php?t=51464&p=902587#post902587
        # Old: showthread.php?p=902218#post902218
        my $p = $post{'url'};
        $p =~ s/t=[0-9]+\&//;
        # Strip the embedded topic title
        $p =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)$/$+{'start'}/;
        $p =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;
        #printf STDERR "Compare Thread '%s', new '%s'(%s)\n", $post{'threadtitle'}, $post{'threadurl'}, $p;
        # Forum Activity List is unreliable, 'Frontier QA' showing just a single post from March, and none since, so our 'last 20 posts' check fails to find the dupe
        if ($p eq 'showthread.php?t=179414'
          or $p eq 'showthread.php?t=179414&p=2765130#post2765130'
          or $p eq 'showthread.php/290119'
          or $p eq 'showthread.php/290119?p=4525010#post4525010'
          ) {
          next;
        }
        if (defined(${$latest_posts}{$post{'url'}})) {
          my $l = ${${$latest_posts}{$post{'url'}}}{'url'};
          $l =~ s/t=[0-9]+\&//;
          $l =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)$/$+{'start'}/;
          $l =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;
          #printf STDERR "Compare Thread '%s' at '%s'(%s) new '%s'(%s)\n", $post{'threadtitle'}, ${${$latest_posts}{$post{'url'}}}{'threadurl'}, $l, $post{'threadurl'}, $p;
          if ($l eq $p) {
            #print STDERR "We already knew this post, bailing on: ", $p, "\n";
            next;
          }
        }
      }
    } else {
      print STDERR "No div_fulllink\n";
    }
	
	  $post{'whoid'} = $whoid;
	  #print STDERR Dumper(\%post), "\n";
    push(@new_posts, \%post);
    $new_posts_total++;
#    if ($err) {
#      die("Failed post: $post{'url'}\n");
#    }
	}
  # We're popping off an array so as to reverse the order we found them
  # else they'll go in the DB in the wrong order, particularly important
  # if more than one post by the same user has the same minute-resolution
  # datestamp.  Wrong order could lead to missing posts (we'll bail too soon).
  #print STDERR "Adding posts for ", $whoid, " START\n";
  my $p = pop(@new_posts);
  while (defined($p)) { 
	  #print STDERR Dumper($p), "\n";
    if (${$p}{'datestamp'}) {
	    $db->insert_post($p);
    }
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
# Sleep to be sure we don't run back to back if the forums are straining
if (defined($config->getconf('sleep_after')) and $config->getconf('sleep_after') > 0 ) {
  #printf STDERR "Sleeping for %d seconds\n", $config->getconf('sleep_after');
  sleep($config->getconf('sleep_after'));
}
exit(0);
