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
use JSON::PP;

sub new {
	my ($class, $ua, $forums_ignored) = @_;
  my $self = {};

	$self->{'config'} = new ED::DevTracker::Config('file' => 'config.txt');
	$self->{'db'} = new ED::DevTracker::DB('config' => $self->{'config'});

	$self->{'ua'} = $ua;

	$self->{'forum_base_url'} = $self->{'config'}->getconf('forum_base_url');
	$self->{'forum_member_base_url'} = $self->{'forum_base_url'} . "/members/%s/latest-activity";
	$self->{'xf_api_baseurl'} = $self->{'config'}->getconf('xf_api_baseurl');
	$self->{'xf_api_key'} = $self->{'config'}->getconf('xf_api_key');
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
	printf STDERR "Script time is: %s\n", strftime("%Y-%m-%d %H:%M:%S %Z", localtime());
	#printf STDERR "Request:\n%s\n", Dumper($req);
	#printf STDERR "Cookies:\n%s\n", $self->{'ua'}->cookie_jar->as_string();
	my $res = $self->{'ua'}->request($req);
	if (! $res->is_success) {
		print STDERR "Failed to retrieve profile page: ", $whoid, " (", $membername, ")", $res->code, "(", $res->message, ")\n";
		return undef;
	}
	#printf STDERR "RES CONTENT:\n%s\nRES CONTENT END\n\n", Dumper($res->content);

	my $tree = HTML::TreeBuilder->new(no_space_compacting => 1, ignore_unknown => 0);
	$tree->parse(decode("utf8", encode("utf8", $res->decoded_content())));
	$tree->eof();
	#print STDERR Dumper($tree);
	#exit(0);

	my $activitylist = $tree->look_down(
		_tag => 'ul',
		'class', 'block-body js-newsFeedTarget'
	);
	if (! $activitylist) {
		print STDERR "Failed to find the activitylist for ", $membername, " (" . $whoid, ")\n";
		return undef;
	}
	#print STDERR Dumper($activitylist);
	#exit(0);
	
	my @posts = $activitylist->look_down(
		_tag => 'li',
		sub { if ($_[0]->attr('class')) {$_[0]->attr('class') =~ /block-row block-row--separated/; } }
	);
	if (! @posts) {
		print STDERR "Failed to find any posts for ", $membername, " (" . $whoid, ")\n";
		return undef;
	}
	print STDERR "Found ", $#posts, " new posts for ", $membername, " (", $whoid, ")\n";
	#print STDERR "Posts: ", Dumper(\@posts), "\nEND Posts\n";
	#exit(0);

	my @new_posts;
	foreach my $p (@posts) {
		my %post;
		print STDERR "\n";

		my $content = $p->look_down(_tag => 'div', class => 'contentRow-main');
		#printf STDERR "Post text:\n%s\n", $content->as_text;
		if ($content) {
		# datetime
			#printf STDERR "Post Content:\n%s\n\n", Dumper($content);
			my $datetime = $content->look_down(_tag => 'time', class => 'u-dt');
# <time class="u-dt" dir="auto" datetime="2019-04-04T10:16:43+0100" data-time="1554369403" data-date-string="Apr 4, 2019" data-time-string="10:16 AM" title="Apr 4, 2019 at 10:16 AM">Today at 10:16 AM</time>
			$post{'datestampstr'} = $datetime->as_text;
			print STDERR "Date = '", $post{'datestampstr'}, "'\n";
			$post{'datestamp'} = $datetime->attr('data-time');
			printf STDERR "Unix timestamp = '%s'\n", $post{'datestamp'};
		} else {
			print STDERR "No content (didn't find div->content/hasavatar)\n";
			next;
		}
		# thread title and URL
		my $div_title = $content->look_down(_tag => 'div', class => 'contentRow-title');
		if ($div_title) {
			# Check if this is a 'reaction' and ignore if so.
			my $title = $div_title->as_text;
			#printf STDERR "Post Title: '%s'\n", $title;
			if ($title =~ /^[^ ]+ +reacted to .+ post in the thread.+with/) {
				printf STDERR "Skipping reaction\n";
				next;
			}

			my @a = $div_title->look_down(_tag => 'a');
			if (@a) {
				my $who = $a[0]->look_down(
					_tag => 'span',
					sub { if ($_[0]->attr('class')) {$_[0]->attr('class') =~ /username--/; } }
				);
				if ($who) {
					$post{'who'} = $who->as_text;
						printf STDERR "Who: '%s'\n", $post{'who'};
				} else {
					print STDERR "Can't find thread poster\n";
					next;
				}
				$post{'whourl'} = $a[0]->attr('href');
				printf STDERR "Who URL: '%s'\n", $post{'whourl'};
				$post{'threadtitle'} = $a[1]->as_text;
				printf STDERR "Thread Title: '%s'\n", $post{'threadtitle'};
				$post{'url'} = $a[1]->attr('href');
				printf STDERR "Post URL: '%s'\n", $post{'url'};
			} else {
				print STDERR "No 'a' under div->title\n";
				next;
			}
		} else {
			print STDERR "No div->title\n";
			next;
		}

		my $div_excerpt = $content->look_down(_tag => 'div', class => 'contentRow-snippet');
		if ($div_excerpt) {
			$post{'precis'} = $div_excerpt->as_text;
			printf STDERR "Precis:\n'%s'\n", $post{'precis'}
		} else {
			print STDERR "No precis\n";
			next;
		}

		$post{'urltext'} = $post{'threadtitle'};

#		printf STDERR "Thread '%s' at '%s' new '%s'\n", $post{'threadtitle'}, $post{'threadurl'}, $post{'url'};
		# XF2: /posts/7715924/ or /threads/186768/
    $post{'guid_url'} = $post{'url'};
		# Strip embedded title
		$post{'guid_url'} =~ s/^(?<start>\/(posts|threads)\/).+\.(?<id>[0-9]+)\/$/$+{'start'}$+{'id'}\//;
    printf STDERR "Compare Thread '%s', new '%s'(%s)\n", $post{'threadtitle'}, $post{'url'}, $post{'guid_url'};
    printf STDERR "Checking for %s in latest posts\n", $post{'guid_url'};
    if (defined(${$latest_posts}{$post{'guid_url'}})) {
      my $l = ${${$latest_posts}{$post{'guid_url'}}}{'guid_url'};
    	# Old: showthread.php?p=902218#post902218
			$l =~ s/^showthread\.php\?p=(?<postid>[0-9]+)(\#post[0-9]+)?$/\/posts\/$+{'postid'}\//;
    	# New: showthread.php?t=51464&p=902587#post902587
			$l =~ s/^showthread\.php\?t=[0-9]+\&p=(?<postid>[0-9]+)(\#post[0-9]+)?$/\/posts\/$+{'postid'}\//;
    	# Newer (final vBulletin): showthread.php/283153-The-Galaxy-Is-its-size-now-considered-to-be-a-barrier-to-gameplay-by-the-Developers?p=4414769#post4414769
      $l =~ s/^showthread\.php\/(?<start>[0-9]+)(-[^\?]+)$/\/posts\/$+{'start'}\//;

      $l =~ s/^showthread\.php\/(?<start>[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;

      printf STDERR "Compare Thread '%s' at '%s'(%s) new '%s'(%s)\n", $post{'threadtitle'}, ${${$latest_posts}{$post{'guid_url'}}}{'url'}, $l, $post{'url'}, $post{'guid_url'};
      if ($l eq $post{'guid_url'}) {
        print STDERR "We already knew this post, bailing on: ", $post{'guid_url'}, "\n";
        next;
      } else {
        print STDERR "Post is new despite guid_url in latest_posts: ", $post{'guid_url'}, "\n";
      }
    } #else {
      # Post is 'simply' new
      print STDERR "guid_url of new post not found in latest posts\n";
    #}

		### BEGIN: Retrieve fulltext of post
		my $fulltext_post;
		if (!defined($post{'error'})) {
			$fulltext_post = $self->get_fulltext($post{'guid_url'});
			if (!defined($fulltext_post->{'error'})) {
				$post{'fulltext'} = $fulltext_post->{'fulltext'};
				$post{'fulltext_stripped'} = $fulltext_post->{'fulltext_stripped'};
				$post{'fulltext_noquotes'} = $fulltext_post->{'fulltext_noquotes'};
				$post{'fulltext_noquotes_stripped'} = $fulltext_post->{'fulltext_noquotes_stripped'};
				$post{'threadurl'} = $fulltext_post->{'threadurl'};
				$post{'forum'} = $fulltext_post->{'forum'};
				$post{'forumid'} = $fulltext_post->{'forumid'};
			}
		}
		### END: Retrieve fulltext of post

  	### BEGIN: Check for if this is an ignored forum
		print STDERR grep(/^$post{'forumid'}$/, @{$self->{'forums_ignored'}}), "\n";
		if (grep(/^$post{'forumid'}$/, @{$self->{'forums_ignored'}})) {
			printf STDERR "Skipping post/thread for ignored forum\n";
			# XXX: We don't want to just return...
			$post{'error'} = {'message' => 'This forum is ignored', no_post_message => 1};
			# Mark the post as ignored for future reference.
  		if (! $self->{'db'}->check_if_post_ignored($post{'guid_url'})) {
  			printf STDERR "Ignoring post '%s' in forum '%s'\n", $post{'guid_url'}, $post{'forum'};
  			$self->{'db'}->add_ignored_post($post{'guid_url'});
  		}
		}
		### END:   Check for if this is an ignored forum

		$post{'whoid'} = $whoid;
#		print STDERR Dumper(\%post), "\n";
		if (!defined($post{'error'}) and (!defined($fulltext_post->{'error'}) or $fulltext_post->{'error'}->{'no_post_message'} != 1)) {
#			printf STDERR "Adding post...\n";
			push(@new_posts, \%post);
		}
		#last; # XXX: This is DEBUG, don't leave it uncommented!
	}

	return \@new_posts;
}

sub get_fulltext {
	my ($self, $guid_url) = @_;
	my %post;

	printf STDERR "get_fulltext: guid_url = '%s'\n", $guid_url;
  my $page_url = $self->{'forum_base_url'} . $guid_url;
  my ($postid, $threadid, $is_first_post);
  if ($page_url =~ /\/threads\/(?<threadid>[0-9]+)\//) {
    printf STDERR "Found 1st post in page URL: %s\n", $page_url;
    $threadid = $+{'threadid'};
	} elsif ($page_url =~ /\/posts\/(?<postid>[0-9]+)\/$/) {
    printf STDERR "Found reply post in page URL: %s\n", $page_url;
		$postid = $+{'postid'};
  } else {
    printf STDERR "Couldn't find any postid in page URL: %s\n", $page_url;
		$post{'error'} = {'message' => "Couldn't find any postid in page URL"};
    return \%post;
  }

	my $res;
	my $api_post;
	if (defined($threadid)) {
		my $req = HTTP::Request->new( 'GET', $self->{'xf_api_baseurl'} . "/threads/" . $threadid . "/?with_posts=1");
		$req->header("XF-Api-Key" => $self->{'xf_api_key'});
		$res = $self->{'ua'}->request($req);
		if (! $res->is_success) {
			printf STDERR "XF API call for a thread failed: %s\n", $res->status;
			return undef;
		}
		my $api = decode_json($res->content);
		#print STDERR Dumper($api);
		$api_post = @{$api->{'posts'}}[0];
		$post{'threadurl'} = $post{'guid_url'};
		$post{'forum'} = $api->{'thread'}->{'Forum'}->{'title'};
		$post{'forumid'} = $api->{'thread'}->{'Forum'}->{'node_id'};
	} elsif (defined($postid)) {
		my $req = HTTP::Request->new( 'GET', $self->{'xf_api_baseurl'} . "/posts/" . $postid . "/");
		$req->header("XF-Api-Key" => $self->{'xf_api_key'});
		$res = $self->{'ua'}->request($req);
		if (! $res->is_success) {
			printf STDERR "XF API call for a post failed: %s\n", $res->status;
			return undef;
		}
		$api_post = decode_json($res->content);
		$api_post = $api_post->{'post'};
		$post{'threadurl'} = "/threads/" . $api_post->{'thread_id'} . "/";
		$post{'forum'} = $api_post->{'Thread'}->{'Forum'}->{'title'};
		$post{'forumid'} = $api_post->{'Thread'}->{'Forum'}->{'node_id'};
	} 

	#print STDERR Dumper($api_post);
	printf STDERR "Setting forum '%s' and forumid '%s'\n", $post{'forum'}, $post{'forumid'};

	$post{'fulltext'} = $api_post->{'message'};
	#printf STDERR "Full Text:\n'%s'\n", $post{'fulltext'};
# XXX: Munge user quoting into something that works in RSS feed/readers.
# XXX: See Parse::BBCode
# [QUOTE="hos, post: 7716228, member: 222029"]
# nice way to hide the amount of issues. good job.
# [/QUOTE]
# 
# The Issue Tracker makes the number of reports more visible than the previous forum system and helps you keep track of their progress.
# XXX: Actually populate these properly.  We need the 'stripped' version(s) for full text search to not be full of HTML tags
	$post{'fulltext_stripped'} = $post{'fulltext'};
	$post{'fulltext_noquotes'} = $post{'fulltext'};
	$post{'fulltext_noquotes_stripped'} = $post{'fulltext'};

# XXX: Below here is the old scraping code
######   my $post_div;
######   if ($is_first_post) {
###### #    print STDERR "Is a first post\n";
######     $post_div = $tree->look_down(_tag => 'div', id => qr/^post_message_[0-9]+$/);
######     if (! $post_div) {
######       printf STDERR "Failed to find the post div element for first post in thread %d\n", $postid;
###### 			my $error = $self->check_forum_error($tree);
###### 			if (defined($error)) {
###### 				$post{'error'} = $error;
###### 			} else {
###### 				$post{'error'} = {'message' => 'Failed to find the post div element for first post in thread', 'no_post_message' => 1};
###### 			}
######      	return \%post;
######     }
######   } else {
###### #    print STDERR "Is NOT a first post\n";
######     $post_div = $tree->look_down('id', "post_message_" . $postid);
######     if (! $post_div) {
######       printf STDERR "Failed to find the post div element for post %d\n", $postid;
###### #			printf STDERR $tree->as_HTML, "\n";
###### #			printf STDERR Dumper($tree), "\n";
###### 			my $error = $self->check_forum_error($tree);
###### #			printf STDERR Dumper($error), "\n"; # XXX why does this sometimes give no output, despite other checks showing $error is defined ?
###### 			if (defined($error)) {
###### 				$post{'error'} = $error;
###### 			} else {
###### 				$post{'error'} = {'message' => 'Failed to find the post div element for post', 'no_post_message' => 1};
###### 			}
######       return \%post;
######     }
######   }
######   my $new_content = $post_div->look_down(_tag => 'blockquote');
######   if (! $new_content) {
######     printf STDERR "Couldn't find main blockquote of post\n";
###### 		$post{'error'} = {'message' => "Couldn't find main blockquote of post", 'no_blockquote' => 1};
######     return \%post;
######   }
###### #  printf STDERR "Full post text:\n'%s'\n", $post_div->as_HTML;
######   $post{'fulltext'} = $post_div->as_HTML;
######   $post{'fulltext_stripped'} = $post_div->format;
###### 
######   my $post_div_stripped = $post_div;
######   # Post with multiple 'code' segments: https://forums.frontier.co.uk/showthread.php/275151-Commanders-log-manual-and-data-sample?p=5885045&viewfull=1#post5885045
######   # thankfully they use class="bbcode_container", not "bbcode_quote"
######   my @bbcode_quote = $post_div_stripped->look_down(_tag => 'div', class => 'bbcode_quote');
######   foreach my $bbq (@bbcode_quote) {
######     $bbq->delete_content;
######   }
######   my $text = $post_div_stripped->as_trimmed_text;
###### #    printf STDERR "Stripped content (HTML):\n'%s'\n", $post_div_stripped->as_HTML;
######   # This probably works for full-text search.  May have to strip ' * ' and ' - ' (used in lists) from it.
###### #    printf STDERR "Stripped content (format):\n'%s'\n", $post_div_stripped->format;
######   $post{'fulltext_noquotes'} = $post_div_stripped->as_HTML;
######   $post{'fulltext_noquotes_stripped'} = $post_div_stripped->format;

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
