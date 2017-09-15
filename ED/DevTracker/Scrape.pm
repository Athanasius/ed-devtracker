#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

package ED::DevTracker::Scrape;

use strict;
use Carp;
#use feature 'unicode_strings';

use ED::DevTracker::Config;
use ED::DevTracker::DB;
use HTML::Entities qw/encode_entities_numeric/;
use HTML::TreeBuilder;

use LWP::UserAgent;
use HTTP::Request;
use Encode;
use Data::Dumper;
use Date::Manip;

sub new {
	my $class = shift;
  my $self = {};

	my $config = new ED::DevTracker::Config('file' => 'config.txt');
	$self->{'db'} = new ED::DevTracker::DB('config' => $config);;

	$self->{'ua'} = LWP::UserAgent->new('agent' => $config->getconf('user_agent'));
	$self->{'ua'}->timeout($config->getconf('ua_timeout'));
	$self->{'ua'}->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));

	$self->{'forum_base_url'} = $config->getconf('forum_base_url');
	$self->{'forum_member_base_url'} = 'https://forums.frontier.co.uk/member.php?tab=activitystream&type=user&u=';
  bless($self, $class);
  return $self;
}

sub get_member_new_posts {
	my ($self, $whoid, $membername) = @_;

	my $latest_posts = $self->{'db'}->user_latest_known($whoid);
	if (!defined($latest_posts)) {
		$latest_posts = { 'url' => 'nothing_yet' };
	}
#	 print Dumper($latest_posts);

	my $req = HTTP::Request->new('GET', $self->{'forum_member_base_url'} . $whoid, ['Connection' => 'close']);
	my $res = $self->{'ua'}->request($req);
	if (! $res->is_success) {
		print STDERR "Failed to retrieve profile page: ", $whoid, " (", $membername, ")", $res->code, "(", $res->message, ")\n";
		return undef;
	}

#	 print STDERR $res->header('Content-Type'), "\n";
	my $hct = $res->header('Content-Type');
	if ($hct =~ /charset=(?<ct>[^[:space:]]+)/) {
		$hct = $+{'ct'};
	} else {
		undef $hct;
	}
#	 print STDERR "HCT: ", $hct, "\n";
#	 print STDERR Dumper($res->content);
#	 print STDERR Dumper($res->decoded_content('charset' => 'windows-1252'));
	my $tree = HTML::TreeBuilder->new(no_space_compacting => 1);
	if (!defined($hct) or ($hct ne 'WINDOWS-1252' and $res->content =~ /[\x{7f}-\x{9f}]/)) {
#		printf STDERR "Detected non ISO-8859-1 characters!\n";
#		exit (1);
		$tree->parse(decode("utf8", encode("utf8", $res->decoded_content('charset' => 'windows-1252'))));
	} else {
		$tree->parse(decode("utf8", encode("utf8", $res->decoded_content())));
	}
	$tree->eof();
#	print STDERR Dumper($tree);

	my $activitylist = $tree->look_down('id', 'activitylist');
	if (! $activitylist) {
		print STDERR "Failed to find the activitylist for ", $membername, " (" . $whoid, ")\n";
		return undef;
	}
	
	my @posts = $activitylist->look_down(
		_tag => 'li',
		sub { $_[0]->attr('class') =~ /forum_(post|thread)/; }
	);
	if (! @posts) {
#		print STDERR "Failed to find any posts for ", $membername, " (" . $whoid, ")\n";
		return undef;
	}
#	print STDERR "Posts: ", Dumper(\@posts), "\nEND Posts\n";
#	exit(0);

	my @new_posts;
	foreach my $p (@posts) {
		my %post;

		my $content = $p->look_down(_tag => 'div', class => 'content hasavatar');
		if ($content) {
		# datetime
			my $span_date = $content->look_down(_tag => 'span', class => 'date');
			my $span_time = $content->look_down(_tag => 'span', class => 'time');
# <span class="date">Today,&nbsp;<span class="time">2:00 PM</span> · 4 replies and 284 views.</span>
			$post{'datestampstr'} = $span_date->as_text;
			$post{'datestampstr'} =~ s/\xA0/ /g;
			$post{'datestampstr'} =~ s/ . [0-9]+ replies and [0-9]+ views\.//;
#			print STDERR "Date = '", $post{'datestampstr'}, "'\n";
			my $timestr = $span_time->as_text;
#			print STDERR "Time = '", $timestr, "'\n";
			my $date = new Date::Manip::Date;
			$date->config(
				'DateFormat' => 'GB',
				'tz' => 'UTC'
			);
			my $err = $date->parse($post{'datestampstr'});
			if (!$err) {
				$post{'datestamp'} = $date->secs_since_1970_GMT();
#				print STDERR "Date: ", $date->printf('%Y-%m-%d %H:%M:%S %Z'), "\n";
			} else {
				printf(STDERR "Problem parsing $post{'datestampstr'}, from $whoid\n");
				next;
			}
		} else {
			print STDERR "No content (didn't find div->content/hasavatar)\n";
			next;
		}
		# thread title and URL
		my $div_title = $content->look_down(_tag => 'div', class => 'title');
		if ($div_title) {
			my @a = $div_title->look_down(_tag => 'a');
			if (@a) {
				$post{'who'} = $a[0]->as_text;
				$post{'whourl'} = $a[0]->attr('href');
				$post{'threadtitle'} = $a[1]->as_text;
				$post{'threadurl'} = $a[1]->attr('href');
				$post{'forum'} = $a[2]->as_text;
			} else {
				print STDERR "No 'a' under div->title\n";
				next;
			}
		} else {
			print STDERR "No div->title\n";
			next;
		}

		my $div_excerpt = $content->look_down(_tag => 'div', class => 'excerpt');
		if ($div_excerpt) {
			$post{'precis'} = $div_excerpt->as_text;
		} else {
			print STDERR "No precis\n";
			next;
		}

    my $div_fulllink = $content->look_down(_tag => 'div', class => 'fulllink');
    if ($div_fulllink) {
      my $a = $div_fulllink->look_down(_tag => 'a');
      if ($a) {
        $post{'url'} = $a->attr('href');
        $post{'urltext'} = $a->as_text;
#				printf STDERR "Thread '%s' at '%s' new '%s'\n", $post{'threadtitle'}, $post{'threadurl'}, $post{'url'};
        # Newer: showthread.php/283153-The-Galaxy-Is-its-size-now-considered-to-be-a-barrier-to-gameplay-by-the-Developers?p=4414769#post4414769
        # New: showthread.php?t=51464&p=902587#post902587
        # Old: showthread.php?p=902218#post902218
        $post{'guid_url'} = $post{'url'};
        $post{'guid_url'} =~ s/t=[0-9]+\&//;
        # Strip the embedded topic title
        $post{'guid_url'} =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)$/$+{'start'}/;
        $post{'guid_url'} =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;
#        printf STDERR "Compare Thread '%s', new '%s'(%s)\n", $post{'threadtitle'}, $post{'threadurl'}, $post{'guid_url'};
        # Forum Activity List is unreliable, 'Frontier QA' showing just a single post from March, and none since, so our 'last 20 posts' check fails to find the dupe
        if ($post{'guid_url'} eq 'showthread.php?t=179414'
          or $post{'guid_url'} eq 'showthread.php?t=179414&p=2765130#post2765130'
          or $post{'guid_url'} eq 'showthread.php/290119'
          or $post{'guid_url'} eq 'showthread.php/290119?p=4525010#post4525010'
          ) {
#          print STDERR "Bailing because of a problematic post\n";
          next;
        }
#        printf STDERR "Checking for %s in latest posts\n", $post{'guid_url'};
        if (defined(${$latest_posts}{$post{'guid_url'}})) {
          my $l = ${${$latest_posts}{$post{'guid_url'}}}{'guid_url'};
          $l =~ s/t=[0-9]+\&//;
          $l =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)$/$+{'start'}/;
          $l =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;
#          printf STDERR "Compare Thread '%s' at '%s'(%s) new '%s'(%s)\n", $post{'threadtitle'}, ${${$latest_posts}{$post{'guid_url'}}}{'threadurl'}, $l, $post{'threadurl'}, $post{'guid_url'};
          if ($l eq $post{'guid_url'}) {
#            print STDERR "We already knew this post, bailing on: ", $post{'guid_url'}, "\n";
            next;
          } else {
#            print STDERR "Post is new despite guid_url in latest_posts: ", $post{'guid_url'}, "\n";
          }
        } #else {
          # Post is 'simply' new
#          print STDERR "guid_url of new post not found in latest posts\n";
        #}
      }
    } else {
      print STDERR "No div_fulllink\n";
			next;
    }
		my $fulltext_post = $self->get_fulltext($post{'guid_url'});
		if (defined($fulltext_post)) {
			$post{'fulltext'} = $fulltext_post->{'fulltext'};
			$post{'fulltext_stripped'} = $fulltext_post->{'fulltext_stripped'};
			$post{'fulltext_noquotes'} = $fulltext_post->{'fulltext_noquotes'};
			$post{'fulltext_noquotes_stripped'} = $fulltext_post->{'fulltext_noquotes_stripped'};
		}

		$post{'whoid'} = $whoid;
#		print STDERR Dumper(\%post), "\n";
		push(@new_posts, \%post);
		last;
	}

	return \@new_posts;
}

sub get_fulltext {
	my ($self, $guid_url) = @_;

  my $page_url = $self->{'forum_base_url'} . $guid_url;
  my ($postid, $is_first_post);
  $is_first_post = undef;
  if ($page_url =~ /\#post(?<postid>[0-9]+)$/) {
#    printf STDERR "Found #postNNNNN in page URL: %s\n", $page_url;
    $postid = $+{'postid'};
  } elsif ($page_url =~ /showthread.php\/(?<postid>[0-9]+)/) {
#    printf STDERR "Found 1st post in page URL: %s\n", $page_url;
    $postid = $+{'postid'};
    $is_first_post = 1;
  } elsif ($page_url =~ /showthread.php\?t=[0-9]+\&p=(?<postid>[0-9]+)\#/) {
#    printf STDERR "Found old-style not-1st post in page URL: %s\n", $page_url;
    $postid = $+{'postid'};
  } elsif ($page_url =~ /showthread.php\?t=(?<postid>[0-9]+)$/) {
#    printf STDERR "Found old-style 1st post in page URL: %s\n", $page_url;
    $postid = $+{'postid'};
    $is_first_post = 1;
  } else {
    printf STDERR "Couldn't find any postid in page URL: %s\n", $page_url;
    return undef;
  }

  my $req = HTTP::Request->new('GET', $page_url);
  my $res = $self->{'ua'}->request($req);
  if (! $res->is_success) {
    printf STDERR "Failed to retrieve post page for '%s': (%d) %s\n", $page_url, $res->code, $res->message;
    return undef;
  }

  my $hct = $res->header('Content-Type');
  if ($hct =~ /charset=(?<ct>[^[:space:]]+)/) {
    $hct = $+{'ct'};
  } else {
    undef $hct;
  }
  my $tree = HTML::TreeBuilder->new(no_space_compacting => 1);
  if (!defined($hct) or ($hct ne 'WINDOWS-1252' and $res->content =~ /[\x{7f}-\x{9f}]/)) {
    $tree->parse(decode("utf8", encode("utf8", $res->decoded_content('charset' => 'windows-1252'))));
  } else {
    $tree->parse(decode("utf8", encode("utf8", $res->decoded_content())));
  }

  my $post_div;
  if ($is_first_post) {
#    print STDERR "Is a first post\n";
    $post_div = $tree->look_down(_tag => 'div', id => qr/^post_message_[0-9]+$/);
    if (! $post_div) {
      printf STDERR "Failed to find the post div element for first post in thread %d\n", $postid;
      return undef;
    }
  } else {
#    print STDERR "Is NOT a first post\n";
    $post_div = $tree->look_down('id', "post_message_" . $postid);
    if (! $post_div) {
      printf STDERR "Failed to find the post div element for post %d\n", $postid;
#			printf STDERR $tree->as_HTML, "\n";
#			printf STDERR Dumper($tree), "\n";
      return undef;
    }
  }
  my $new_content = $post_div->look_down(_tag => 'blockquote');
  if (! $new_content) {
    printf STDERR "Couldn't find main blockquote of post\n";
    return undef;
  }
#  printf STDERR "Full post text:\n'%s'\n", $post_div->as_HTML;
	my %post;
  $post{'fulltext'} = $post_div->as_HTML;
  $post{'fulltext_stripped'} = $post_div->format;

  my $post_div_stripped = $post_div;
  # Post with multiple 'code' segments: https://forums.frontier.co.uk/showthread.php/275151-Commanders-log-manual-and-data-sample?p=5885045&viewfull=1#post5885045
  # thankfully they use class="bbcode_container", not "bbcode_quote"
  my @bbcode_quote = $post_div_stripped->look_down(_tag => 'div', class => 'bbcode_quote');
  foreach my $bbq (@bbcode_quote) {
    $bbq->delete_content;
  }
  my $text = $post_div_stripped->as_trimmed_text;
#    printf STDERR "Stripped content (HTML):\n'%s'\n", $post_div_stripped->as_HTML;
  # This probably works for full-text search.  May have to strip ' * ' and ' - ' (used in lists) from it.
#    printf STDERR "Stripped content (format):\n'%s'\n", $post_div_stripped->format;
  $post{'fulltext_noquotes'} = $post_div_stripped->as_HTML;
  $post{'fulltext_noquotes_stripped'} = $post_div_stripped->format;

	return \%post;
}

1;
