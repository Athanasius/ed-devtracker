#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

package ED::DevTracker::Scrape;

use strict;
use Carp;
#use feature 'unicode_strings';
use POSIX qw/strftime/;

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
	my ($class, $ua, $forums_ignored) = @_;
  my $self = {};

	my $config = new ED::DevTracker::Config('file' => 'config.txt');
	$self->{'db'} = new ED::DevTracker::DB('config' => $config);;

	$self->{'ua'} = $ua;

	$self->{'forum_base_url'} = $config->getconf('forum_base_url');
	$self->{'forum_member_base_url'} = 'https://forums.frontier.co.uk/member.php/%s?tab=activitystream&type=user';
	$self->{'forums_ignored'} = $forums_ignored;
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

	my $req = HTTP::Request->new('GET', sprintf($self->{'forum_member_base_url'}, $whoid), ['Connection' => 'close']);
#	printf STDERR "Script time is: %s\n", strftime("%Y-%m-%d %H:%M:%S %Z", localtime());
#	printf STDERR "Request:\n%s\n", Dumper($req);
#	printf STDERR "Cookies:\n%s\n", $self->{'ua'}->cookie_jar->as_string();
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
#		printf STDERR "Post text:\n%s\n", $p->as_text;
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
				'SetDate' => 'now,UTC'
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

  	### BEGIN: Check for if this is an ignored forum
		my $page_url = $self->{'forum_base_url'} . $post{'guid_url'};
  	if (! $div_title) {
  		printf STDERR "Failed to find post div[title]: %s\n", $page_url
  	} else {
  		printf STDERR "Parsing div[title] for post: %s\n", $page_url;
  		foreach my $fi (keys(%{$self->{'forums_ignored'}})) {
  			my $fi_numberonly = ${$self->{'forums_ignored'}}{$fi};
  			$fi_numberonly =~ s/-[^0-9]+$//;
  			my @divtitle_a = $div_title->look_down(_tag => 'a'); 
  			if (@divtitle_a) {
					my $scraped_forum_url;
					foreach my $a (@divtitle_a) {
						if ($a->attr('href') =~ /forumdisplay\.php\/[0-9]+-/) {
							$scraped_forum_url = $a->attr('href');
						}
					}
  				if ($scraped_forum_url) {
  					printf STDERR "Compare stored '%s' to scraped '%s'\n", $fi_numberonly, $scraped_forum_url;
  					$scraped_forum_url = 'https://forums.frontier.co.uk/' . $scraped_forum_url;
  					$scraped_forum_url =~ s/-[^0-9]+$//;
  					printf STDERR "Compare stored '%s' to scraped '%s'\n", $fi_numberonly, $scraped_forum_url;
  					if ($fi_numberonly eq $scraped_forum_url) {
  					# XXX: We don't want to just return...
  						$post{'error'} = {'message' => 'This forum is ignored', no_post_message => 1};
  						if (! $self->{'db'}->check_if_post_ignored($page_url)) {
  							printf STDERR "Ignoring post '%s' in forum '%s'\n", $page_url, $scraped_forum_url;
  							$self->{'db'}->add_ignored_post($page_url);
  						}
  						else { printf STDERR "Already ignoring '%s' in forum '%s'\n", $page_url, $scraped_forum_url; } #return \%post;
  					}
  				}
  			}
  		}
		}
		### END:   Check for if this is an ignored forum

		my $fulltext_post = $self->get_fulltext($post{'guid_url'});
		if (!defined($fulltext_post->{'error'})) {
			$post{'fulltext'} = $fulltext_post->{'fulltext'};
			$post{'fulltext_stripped'} = $fulltext_post->{'fulltext_stripped'};
			$post{'fulltext_noquotes'} = $fulltext_post->{'fulltext_noquotes'};
			$post{'fulltext_noquotes_stripped'} = $fulltext_post->{'fulltext_noquotes_stripped'};
		}

		$post{'whoid'} = $whoid;
#		print STDERR Dumper(\%post), "\n";
		if (!defined($post{'error'}) and (!defined($fulltext_post->{'error'}) or $fulltext_post->{'error'}->{'no_post_message'} != 1)) {
			printf STDERR "Adding post...\n";
			push(@new_posts, \%post);
		}
		last;
	}

	return \@new_posts;
}

sub get_fulltext {
	my ($self, $guid_url) = @_;
	my %post;

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
		$post{'error'} = {'message' => "Couldn't find any postid in page URL"};
    return \%post;
  }

  my $req = HTTP::Request->new('GET', $page_url);
  my $res = $self->{'ua'}->request($req);
  if (! $res->is_success) {
    printf STDERR "Failed to retrieve post page for '%s': (%d) %s\n", $page_url, $res->code, $res->message;
		$post{'error'} = {'http_code' => $res->code, 'http_message' => $res->message};
    return \%post;
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
			my $error = $self->check_forum_error($tree);
			if (defined($error)) {
				$post{'error'} = $error;
			} else {
				$post{'error'} = {'message' => 'Failed to find the post div element for first post in thread', 'no_post_message' => 1};
			}
     	return \%post;
    }
  } else {
#    print STDERR "Is NOT a first post\n";
    $post_div = $tree->look_down('id', "post_message_" . $postid);
    if (! $post_div) {
      printf STDERR "Failed to find the post div element for post %d\n", $postid;
#			printf STDERR $tree->as_HTML, "\n";
#			printf STDERR Dumper($tree), "\n";
			my $error = $self->check_forum_error($tree);
#			printf STDERR Dumper($error), "\n"; # XXX why does this sometimes give no output, despite other checks showing $error is defined ?
			if (defined($error)) {
				$post{'error'} = $error;
			} else {
				$post{'error'} = {'message' => 'Failed to find the post div element for post', 'no_post_message' => 1};
			}
      return \%post;
    }
  }
  my $new_content = $post_div->look_down(_tag => 'blockquote');
  if (! $new_content) {
    printf STDERR "Couldn't find main blockquote of post\n";
		$post{'error'} = {'message' => "Couldn't find main blockquote of post", 'no_blockquote' => 1};
    return \%post;
  }
#  printf STDERR "Full post text:\n'%s'\n", $post_div->as_HTML;
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

sub check_forum_error {
	my ($self, $tree) = @_;
#	print STDERR $tree->as_HTML, "\n";
	my $error = $tree->look_down(_tag => 'div', class => 'standard_error');
	if ($error) {
#		printf STDERR "Found standard_error\n";
		return {'thread_invalid' => 1};
	}

	$error = $tree->look_down(_tag => 'ol', id => 'posts');
	if ($error) {
#		printf STDERR "Thread exists, but post doesn't\n";
		return {'post_invalid' => 1};
	}

	printf STDERR "Unknown post retrieval error\n";
	print STDERR $tree->as_HTML, "\n";

	return undef;
}

1;
