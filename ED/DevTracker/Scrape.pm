#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

package ED::DevTracker::Scrape;

use strict;
use Carp;
#use feature 'unicode_strings';
use POSIX qw/strftime mktime/;

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
use Parse::BBCode;

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
	#printf STDERR "Script time is: %s\n", strftime("%Y-%m-%d %H:%M:%S %Z", localtime());
	#printf STDERR "Request:\n%s\n", Dumper($req);
	#printf STDERR "Cookies:\n%s\n", $self->{'ua'}->cookie_jar->as_string();
	my $member_done = 0;
	my $dupe_count = 0;
 	my @new_posts;
	while (! $member_done and $dupe_count < 5) {
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
			# in XF2 this can simply mean there's been no activity on the user yet
  		#print STDERR "Failed to find the activitylist for ", $membername, " (" . $whoid, ")\n";
  		last;
  	}
  	#print STDERR Dumper($activitylist);
  	#exit(0);
  	
		# Store the 'load more' URL for possible later use
		my $loadmore = $tree->look_down(
			_tag => 'a',
			'data-replace' => '.js-newsFeedLoadMore'
		);
		my $loadmore_url;
		if (! $loadmore) {
			# If the element isn't present then there's no more activity for this member
			$member_done = 1;
		} else {
			$loadmore_url = $loadmore->attr('href');
			#printf STDERR "Load More: %s\n", $loadmore_url;
		}

  	my @posts = $activitylist->look_down(
  		_tag => 'li',
  		sub { if ($_[0]->attr('class')) {$_[0]->attr('class') =~ /block-row block-row--separated/; } }
  	);
  	if (! @posts) {
  		print STDERR "Failed to find any posts for ", $membername, " (" . $whoid, ")\n";
  		return undef;
  	}
  	#print STDERR "Found ", $#posts, " new posts for ", $membername, " (", $whoid, ")\n";
  	#print STDERR "Posts: ", Dumper(\@posts), "\nEND Posts\n";
  	#exit(0);
  
  	foreach my $p (@posts) {
  		my %post;
  		#print STDERR "\n";
  
  		my $content = $p->look_down(_tag => 'div', class => 'contentRow-main');
  		#printf STDERR "Post text:\n%s\n", $content->as_text;
  		if ($content) {
  		# datetime
  			#printf STDERR "Post Content:\n%s\n\n", Dumper($content);
  			my $datetime = $content->look_down(_tag => 'time', class => 'u-dt');
  			$post{'datestampstr'} = $datetime->as_text;
  			#print STDERR "Date = '", $post{'datestampstr'}, "'\n";
  			$post{'datestamp'} = $datetime->attr('data-time');
  			#printf STDERR "Unix timestamp = '%s'\n", $post{'datestamp'};
				
				# Definitely not interested in anything before the migration to the
				# XF2 forum.  Old forums went down by 2019-03-25T12:00:00Z and were
				# down for over 2 days.
				# Yes, we're relying on the XF2 activity list being in strict
				# descending chronological order.
				if ($post{'datestamp'} < mktime(0, 0, 12, 25, 2, 119)) {
					printf STDERR "Post time before XF2 migration, bailing on user\n";
					$member_done = 1;
					next;
				}
  		} else {
  			print STDERR "No content (didn't find div->contentRow-main)\n";
  			next;
  		}
  		# thread title and URL
  		my $div_title = $content->look_down(_tag => 'div', class => 'contentRow-title');
  		if ($div_title) {
  			# Check if this is a 'reaction' and ignore if so.
  			my $title = $div_title->as_text;
  			#printf STDERR "Post Title: '%s'\n", $title;
  			if ($title =~ /reacted to .+ post in the thread.+with/) {
  				#printf STDERR "Skipping reaction\n";
  				next;
  			} elsif ($title =~ /commented on .+ profile post/) {
  				#printf STDERR "Skipping profile post comment\n";
					next;
				}
  
  			my @a = $div_title->look_down(_tag => 'a');
  			if (@a) {
					if ($a[0]->as_text) {
  					$post{'who'} = $a[0]->as_text;
  					#printf STDERR "Who: '%s'\n", $post{'who'};
  				} else {
  					printf STDERR "Can't find thread poster (membername: %s(%s)\n", $membername, $whoid;
  					next;
  				}
  				$post{'whourl'} = $a[0]->attr('href');
  				#printf STDERR "Who URL: '%s'\n", $post{'whourl'};
  				$post{'threadtitle'} = $a[1]->as_text;
					# XXX: Is this a 'status' ?
  				#printf STDERR "Thread Title: '%s'\n", $post{'threadtitle'};
  				$post{'url'} = $a[1]->attr('href');
  				#printf STDERR "Post URL: '%s'\n", $post{'url'};
  			} else {
  				print STDERR "No 'a' under div->title\n";
  				next;
  			}
  		} else {
  			printf STDERR "No div[contentRow-title] (membername: %s(%s)\n", $membername, $whoid;
  			next;
  		}
  
  		my $div_excerpt = $content->look_down(_tag => 'div', class => 'contentRow-snippet');
  		if ($div_excerpt) {
  			$post{'precis'} = $div_excerpt->as_text;
  			#printf STDERR "Precis:\n'%s'\n", $post{'precis'}
  		} else {
  			print STDERR "No precis\n";
  			next;
  		}
  
  		$post{'urltext'} = $post{'threadtitle'};
  
  #		printf STDERR "Thread '%s' at '%s' new '%s'\n", $post{'threadtitle'}, $post{'threadurl'}, $post{'url'};
  		# XF2: /posts/7715924/ or /threads/186768/
      $post{'guid_url'} = $post{'url'};
			# We're not interested in profile-posts
			if ($post{'url'} =~ /^\/profile-posts\//) {
        if (! $self->{'db'}->check_if_post_ignored($post{'url'})) {
					printf STDERR "Skipping profile-post from %s: %s\n", $post{'who'}, $post{'url'};

        	$self->{'db'}->add_ignored_post($post{'url'});
				}
				next;
			}
  		# Strip embedded title
  		$post{'guid_url'} =~ s/^(?<start>\/(index\.php\?)?(posts|threads)\/).+\.(?<id>[0-9]+)\/$/$+{'start'}$+{'id'}\//;
			# And then the XF2 forums suddenly grew a 'index.php?' at the start of the URLs.
			$post{'guid_url'} =~ s/^\/index\.php\?/\//;

      #printf STDERR "Checking for %s in ignored posts\n", $post{'guid_url'};
			if ($self->{'db'}->check_if_post_ignored($post{'guid_url'})) {
				#printf STDERR "%s is already ignored (ignored forum), skipping...\n", $post{'guid_url'};
				# NO!!! $dupe_count++; This means a run of ignored forum posts at the top would prevent scanning for more!
				next;
			}

      #printf STDERR "Compare Thread '%s', new '%s'(%s)\n", $post{'threadtitle'}, $post{'url'}, $post{'guid_url'};
      #printf STDERR "Checking for %s in latest posts\n", $post{'guid_url'};
      if (defined(${$latest_posts}{$post{'guid_url'}})) {
        my $l = ${${$latest_posts}{$post{'guid_url'}}}{'guid_url'};
      	# Old: showthread.php?p=902218#post902218
  			$l =~ s/^showthread\.php\?p=(?<postid>[0-9]+)(\#post[0-9]+)?$/\/posts\/$+{'postid'}\//;
      	# New: showthread.php?t=51464&p=902587#post902587
  			$l =~ s/^showthread\.php\?t=[0-9]+\&p=(?<postid>[0-9]+)(\#post[0-9]+)?$/\/posts\/$+{'postid'}\//;
      	# Newer (final vBulletin): showthread.php/283153-The-Galaxy-Is-its-size-now-considered-to-be-a-barrier-to-gameplay-by-the-Developers?p=4414769#post4414769
        $l =~ s/^showthread\.php\/(?<start>[0-9]+)(-[^\?]+)$/\/posts\/$+{'start'}\//;
  
        $l =~ s/^showthread\.php\/(?<start>[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#post[0-9]+)$/$+{'start'}$+{'end'}/;
        #printf STDERR "Compare Thread '%s' at '%s'(%s) new '%s'(%s)\n", $post{'threadtitle'}, ${${$latest_posts}{$post{'guid_url'}}}{'url'}, $l, $post{'url'}, $post{'guid_url'};
        if ($l eq $post{'guid_url'}) {
          #print STDERR "We already knew this post, bailing on: ", $post{'guid_url'}, "\n";
					$dupe_count++;
          next;
        } else {
          print STDERR "Post is new despite guid_url in latest_posts: ", $post{'guid_url'}, "\n";
        }
      } #else {
        # Post is 'simply' new
        #print STDERR "guid_url of new post not found in latest posts\n";
      #}
  
  		### BEGIN: Retrieve fulltext of post
  		my $fulltext_post;
  		if (!defined($post{'error'})) {
  			$fulltext_post = $self->get_fulltext($post{'guid_url'});
  			if (!defined($fulltext_post->{'error'})) {
					#printf STDERR "No error on post, populating remaining fields...\n";
  				$post{'fulltext'} = $fulltext_post->{'fulltext'};
  				$post{'fulltext_stripped'} = $fulltext_post->{'fulltext_stripped'};
  				$post{'fulltext_noquotes'} = $fulltext_post->{'fulltext_noquotes'};
  				$post{'fulltext_noquotes_stripped'} = $fulltext_post->{'fulltext_noquotes_stripped'};
  				$post{'threadurl'} = $fulltext_post->{'threadurl'};
  				$post{'forum'} = $fulltext_post->{'forum'};
  				$post{'forumid'} = $fulltext_post->{'forumid'};

        	### BEGIN: Check for if this is an ignored forum
      		#print STDERR grep(/^$post{'forumid'}$/, @{$self->{'forums_ignored'}}), "\n";
      		if (grep(/^$post{'forumid'}$/, @{$self->{'forums_ignored'}})) {
      			#printf STDERR "Skipping post/thread for ignored forum\n";
      			# We don't want to just return...
      			$post{'error'} = {'message' => 'This forum is ignored', no_post_message => 1};
      			# Mark the post as ignored for future reference.
        		if (! $self->{'db'}->check_if_post_ignored($post{'guid_url'})) {
        			#printf STDERR "Ignoring post '%s' in forum '%s'\n", $post{'guid_url'}, $post{'forum'};
        			$self->{'db'}->add_ignored_post($post{'guid_url'});
        		}
      		}
      		### END:   Check for if this is an ignored forum
  			}
  		}
  		### END: Retrieve fulltext of post
  
  
  		$post{'whoid'} = $whoid;
  #		print STDERR Dumper(\%post), "\n";
  		if (!defined($post{'error'}) and (!defined($fulltext_post->{'error'}) or $fulltext_post->{'error'}->{'no_post_message'} != 1)) {
  #			printf STDERR "Adding post...\n";
  			push(@new_posts, \%post);
  		}
  		#last; # XXX: This is DEBUG, don't leave it uncommented!
  	}
		# $member_done = 1; # XXX: Remove once we have proper detection of being done.
		$req = HTTP::Request->new('GET', $self->{'forum_base_url'} . $loadmore_url, ['Connection' => 'close']);
	}
	if ($dupe_count >= 5) {
		#printf STDERR "Dupe count reached 5 for %s(%s)\n", $membername, $whoid;
	}

	#printf STDERR "get_member_new_posts: DONE\n";
	return \@new_posts;
}

sub get_fulltext {
	my ($self, $guid_url) = @_;
	my %post;

	#printf STDERR "get_fulltext: guid_url = '%s'\n", $guid_url;
  my $page_url = $self->{'forum_base_url'} . $guid_url;
  my ($postid, $threadid, $is_first_post);
  if ($page_url =~ /\/(index.php\?)?threads\/(?<threadid>[0-9]+)\//) {
    #printf STDERR "Found 1st post in page URL: %s\n", $page_url;
    $threadid = $+{'threadid'};
	} elsif ($page_url =~ /\/(index.php\?)?posts\/(?<postid>[0-9]+)\/$/) {
    #printf STDERR "Found reply post in page URL: %s\n", $page_url;
		$postid = $+{'postid'};
  } else {
    printf STDERR "Couldn't find any postid in page URL: %s\n", $page_url;
		$post{'error'} = {'message' => "Couldn't find any postid in page URL", 'no_post_message' => 0};
    return \%post;
  }

	my $res;
	my $api_post;
	if (defined($threadid)) {
		#printf STDERR "Thread, calling API...\n";
		my $req = HTTP::Request->new( 'GET', $self->{'xf_api_baseurl'} . "/threads/" . $threadid . "/?with_posts=1");
		$req->header("XF-Api-Key" => $self->{'xf_api_key'});
		$res = $self->{'ua'}->request($req);
		if (! $res->is_success) {
			printf STDERR "XF API call for a thread failed: %s\n", $res->status;
			return undef;
		}
		#print("API returned content: ", $res->content, "\n");
		my $api = decode_json($res->content);
		#print STDERR Dumper($api);
		$api_post = @{$api->{'posts'}}[0];
		if (!defined($api_post)) {
			printf STDERR "XF API returned no posts[0] for Thread, alias post?\n";
			return undef;
		}
		$post{'threadurl'} = $post{'guid_url'};
		$post{'forum'} = $api->{'thread'}->{'Forum'}->{'title'};
		$post{'forumid'} = $api->{'thread'}->{'Forum'}->{'node_id'};
	} elsif (defined($postid)) {
		#printf STDERR "Post, calling API...\n";
		my $req = HTTP::Request->new( 'GET', $self->{'xf_api_baseurl'} . "/posts/" . $postid . "/");
		$req->header("XF-Api-Key" => $self->{'xf_api_key'});
		$res = $self->{'ua'}->request($req);
		if (! $res->is_success) {
			printf STDERR "XF API call for a post failed: %s\n", $res->status;
			return undef;
		}
		#print("API returned content: ", $res->content, "\n");
		$api_post = decode_json($res->content);
		$api_post = $api_post->{'post'};
		if (!defined($api_post)) {
			printf STDERR "XF API returned no post for Post, alias post?\n";
			return undef;
		}
		$post{'threadurl'} = "/threads/" . $api_post->{'thread_id'} . "/";
		$post{'forum'} = $api_post->{'Thread'}->{'Forum'}->{'title'};
		#printf STDERR "post's forum node_id is %d\n", $api_post->{'Thread'}->{'Forum'}->{'node_id'};
		$post{'forumid'} = $api_post->{'Thread'}->{'Forum'}->{'node_id'};
	} 

	#print STDERR Dumper($api_post);
	#printf STDERR "Setting forum '%s' and forumid '%s'\n", $post{'forum'}, $post{'forumid'};

	$post{'fulltext'} = $api_post->{'message'};
	#printf STDERR "Full Text:\n'%s'\n", $post{'fulltext'};

	# BEGIN: Munge user quoting into something that works in RSS feed/readers.
	my $pbb = Parse::BBCode->new({
		attribute_quote => q/'"/,
    tags => {
      Parse::BBCode::HTML->defaults,
      center => '<div style="text-align: center">%s</div>',
      'indent' => {
        code => sub {
          my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
          #printf STDERR "INDENT tag:\n\tcontent: '%s'\n\tattr: %s\n\ttag: '%s'\n", Dumper($content), Dumper($attr), Dumper($tag);
          my $multi = 1;
          if (defined($attr)) {
            $multi = $attr;
          }
          return sprintf("<div style=\"margin-left: %dpx\">%s</div>", 20 * $multi, ${$content});
        },
        parse => 1,
      },
      'url'   => 'url:<a href="%{link}A" rel="nofollow">%s</a>',
      'color' => {
        parse => 1,
        code => sub {
          my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
          #printf STDERR "COLOR tag:\n\tcontent: '%s'\n\tattr: %s\n\ttag: '%s'\n", Dumper($content), Dumper($attr), Dumper($tag);
          if ($attr =~ /^(?<rgb>rgb\([0-9]+, *[0-9]+, *[0-9]+\))$/) {
            #printf STDERR "Found COLOR with %s\n", $attr;
            return sprintf("<span style=\"color: %s\">%s</span>", $+{'rgb'}, ${$content});
          }
					return sprintf("[COLOR='%s']%s[/COLOR]", $attr, ${$content});
        },
        close => 0,
        #class => 'block'
      },
      'attach' => {
        parse => 1,
        code => sub {
          my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
          #printf STDERR "ATTACH tag:\n\tcontent: '%s'\n\tattr: %s\n\ttag: '%s'\n", Dumper($content), Dumper($attr), Dumper($tag);
          if (${$content} =~ /^(?<alt>[0-9]+)$/) {
            #printf STDERR "Found ATTACH with %s\n", ${$content};
            return sprintf("<img src=\"https://forums.frontier.co.uk/attachments/%s\" alt=\"%s\">", ${$content}, ${$content});
          }
					return sprintf("[ATTACH]%s[/ATTACH]", ${$content});
        },
        close => 0,
      },
      'table' => '<table style="width: 100%"><tbody>%s</tbody></table>',
      'tr' => '<tr>%s</tr>',
      'td' => '<td>%s</td>',
			's' => '<s>%s</s>',
      'media' => {
        parse => 1,
        code => sub {
          my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
          #printf STDERR "MEDIA tag:\n\tcontent: '%s'\n\tattr: %s\n\ttag: '%s'\n", Dumper($content), Dumper($attr), Dumper($tag);
          if ($attr =~ 'youtube') {
            return sprintf("<div class=\"bbMediaWrapper\"><div class=\"bbMediaWrapper-inner\"><iframe src=\"https://www.youtube.com/embed/%s?wmode=opaque\&start=0\" allowfullscreen=\"true\"></iframe></div></div>", ${$content});
          }
					return sprintf("[MEDIA='%s']%s[/MEDIA]", $attr, ${$content});
        },
        close => 0,
      },
      'user' => {
        code => sub {
          my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
          #printf STDERR "USER tag:\n\tcontent: '%s'\n\tattr: %s\n\ttag: '%s'\n", Dumper($content), Dumper($attr), Dumper($tag);
          if (defined($attr)) {
            return sprintf("<a href=\"https://forums.frontier.co.uk/members/%d/\" class=\"username\" data-xf-init=\"member-tooltip\" data-user-id=\"%d\" data-username=\"%s\">%s</a>", $attr, $attr, ${$content}, ${$content});
          }
          if (defined(${$content})) {
            return ${$content};
          }
        }
      },
    },
	});
	my $mungedtext = $post{'fulltext'};
	$mungedtext =~ s/\[COLOR=(?<rgb>rgb\([^\)]+\))\]/\[COLOR='$+{'rgb'}'\]/gm;
	$mungedtext =~ s/\[ATTACH [^\]]*(?<alt>alt="[0-9]+")[^\]]*\]/\[ATTACH $+{'alt'}\]/gm;
	my $bb = $pbb->render($mungedtext);
	my $bbt = HTML::TreeBuilder->new(no_space_compacting => 1, ignore_unknown => 0);
	$bbt->parse($bb);
	$bbt->eof();
	#printf STDERR Dumper($bbt);
	my @quotes = $bbt->look_down(_tag => 'div', 'class' => 'bbcode_quote_header');
	for my $q (@quotes) {
		# div[bbcode_quote_header]
		# div[quote_container]->blockquote[quote]->div[bbcode_quote_header]
		#$q->tag('blockquote');

		# Make an overall div[quote_container]
		my $quote_container = HTML::Element->new('div', class => 'quote_container');
		# Insert it before original div[bbcode_quote_header]
		$q->preinsert($quote_container);
		# Clone that div[bbcode_quote_header]
		my $qq = $q->clone();
		# And remove it from original position, leaving the new div[quote_container] there
		$q->destroy();

		# Now make a new blockquote[quote]
		my $blockquote = HTML::Element->new('blockquote');
		# And set it as first content of div[quote_container]
		$quote_container->push_content($blockquote);
		# And now put the clone of div[bbcode_quote_header] in as content of that
		$blockquote->push_content($qq);
		# And finally make $q the same as the cloned copy.
		$q = $qq;
		#printf STDERR "Quote:\n%s\n", Dumper($q);
		#printf STDERR "Original Version: '%s'\n", $q->as_HTML;
		#printf STDERR "bbcode_quote_header: %s\n", $q->{'_content'}[0];
		my $qh = $q->{'_content'}[0];
		if ($qh =~ /^(?<poster>[^,]+), post: (?<postid>[0-9]+), member: (?<posterid>[0-9]+)/) {
			#printf STDERR "\tMatched the string\n";
			# <a href="member profile url">member name</a> <a href="post url">Source</a>
			#$q->{'_content'}[0] = sprintf("");
			my $quoted = HTML::Element->new(
				'a',
				href => sprintf("%s/members/%s/", $self->{'forum_base_url'}, $+{'posterid'})
			);
			$quoted->push_content($+{'poster'} . " ");
			my $source = HTML::Element->new(
				'a',
				'href' => sprintf("%s/posts/%s/", $self->{'forum_base_url'}, $+{'postid'}),
			);
			$source->push_content("(Source) ");

			$q->splice_content(0, 1, $quoted, $source);
			#printf STDERR "\tReplace 'quoted': '%s'\n", $quoted->as_HTML();
			#printf STDERR "\tReplace 'source': '%s'\n", $source->as_HTML;
			#printf STDERR "Replaced Version: '%s'\n", $q->as_HTML;
		}
	}
	# END:   Munge user quoting into something that works in RSS feed/readers.

	$post{'fulltext_stripped'} = $bbt->format;
	#printf STDERR "New full text:\n'%s'\n", $bbt->guts()->as_HTML;
	my $guts = $bbt->clone();
	$guts = $guts->guts();
	$post{'fulltext'} = $guts->as_HTML;

  # Remove all the quotes from the post
	@quotes = $bbt->look_down(_tag => 'div', 'class' => 'bbcode_quote_header');
	for my $q (@quotes) {
		$q->detach();
	}
	$post{'fulltext_noquotes'} = $guts->as_HTML;
	$post{'fulltext_noquotes_stripped'} = $bbt->format;

	#printf STDERR "Full Text:\n%s\n.\n", $post{'fulltext'};
	#printf STDERR "Full Text, stripped:\n%s\n.\n", $post{'fulltext_stripped'};
	#printf STDERR "Full Text, noquotes:\n%s\n.\n", $post{'fulltext_noquotes'};
	#printf STDERR "Full Text, noquotes, stripped:\n%s\n.\n", $post{'fulltext_noquotes_stripped'};

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
