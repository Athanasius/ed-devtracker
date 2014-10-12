#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Data::Dumper;

use LWP;
use HTML::TreeBuilder;
use Date::Manip;

use ED::DevTracker::DB;

my $db = new ED::DevTracker::DB;

my $ua = LWP::UserAgent->new;

my %developers = (
  1 => 'fdadmin',
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
	22712 => 'Mike Evans',
	24222 => 'Greg Ryder',
	25094 => 'Dan Davies',
	25095 => 'Tom Kewell',
	25591 => 'Anthony Ross',
	26549 => 'Mark Allen',
	26755 => 'Barry Clark',
	26966 => 'chris gregory',
	27713 => 'Selena Frost-King',
	27895 => 'Ben Parry',
	31252 => 'hchalkley',
	31307 => 'Jonathan Bottone',
	31348 => 'Kenny Wildman',
	31484 => 'Richard Benton',
	32310 => 'Mark Boss',
	32348 => 'Jon Pace',
	32352 => 'Aaron Gordon',
	32574 => 'Matt Dickinson',
	33683 => 'Mark Brett',
	34604 => 'Matthew Florianz',
	47159 => 'Edward Lewis'
# Michael Gapper ?
);
my $url = 'http://forums.frontier.co.uk/search.php?do=finduser&u=';

my $new_posts = 0;
foreach my $whoid (keys(%developers)) {
  my $latest_post = $db->user_latest_known($whoid);
	if (!defined($latest_post)) {
	  $latest_post = { 'url' => 'nothing_yet' };
	}
	my $req = HTTP::Request->new('GET', $url . $whoid);
	my $res = $ua->request($req);
	if (! $res->is_success) {
	  print STDERR "Failed to retrieve profile page: ", $whoid, " (", $developers{$whoid}, ")\n";
	  next;
	}
	
	#print Dumper($res->content);
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($res->decoded_content);
	$tree->eof();
	my $inlinemodform = $tree->look_down('id', 'inlinemodform');
	if (! $inlinemodform) {
	  #print STDERR "Failed to find the list of posts for ", $developers{$whoid}, " (" . $whoid, ")\n";
	  next;
	}
	
	my @posts = $inlinemodform->look_down(
	  _tag => 'table',
	  class => 'tborder',
	  sub { if (defined($_[0]->attr('id'))) { $_[0]->attr('id') =~ /^post[0-9]+$/; } else { return undef;} }
	);
	foreach my $p (@posts) {
	  my %post;
	
	  #printf "Post: %s\n", $p->attr('id');
	
	### tr class="thead" - For forum and datestamp
	  my $thead = $p->look_down(
	    _tag => 'td',
	    class => 'thead'
	  );
	  if ($thead) {
	  # forum
	    my $forum = $thead->look_down(
	      '_tag' => 'span'
	    );
	    if ($forum) {
	      #print $forum->as_text, "\n";
	      if ($forum->as_text =~ /Forum: (?<forum>.*) +$/) {
	        $post{'forum'} = $+{'forum'};
	      }
	    }
	  # datestamp
	    my @contents = $thead->content_list;
	    $post{'datestampstr'} = $contents[3];
	    my $date = new Date::Manip::Date;
	    $date->config(
	      'DateFormat' => 'GB',
	      'tz' => 'Europe/London'
	    );
	    my $err = $date->parse($post{'datestampstr'});
	    if (!$err) {
	      $post{'datestamp'} = $date->secs_since_1970_GMT();
	      #print "Date: ", $date->printf('%Y-%m-%d %H:%M:%S %Z'), "\n";
	    }
	  }
	### tr -> td(alt1) -> div, div<thread>
	  my @tr = $p->look_down(
	    _tag => 'tr'
	  );
	  if (@tr and defined($tr[1])) {
	    my @div = $tr[1]->look_down(
	      _tag => 'div'
	    );
	    if (@div) {
	  # thread title and URL
	      if (defined($div[1])) {
	        my $a = $div[1]->look_down(_tag => 'a');
	        if ($a) {
	          #print $a->dump, "\n";
	          $post{'threadurl'} = $a->attr('href');
	          $post{'threadurl'} =~ s/\?s=[^\&]+\&/\?/;
	          my $strong = $a->look_down(_tag => 'strong');
	          if ($strong) {
	            $post{'threadtitle'} = $strong->as_text;
	          }
	        }
	      }
	  # who
	      if (defined($div[3])) {
	        my $a = $div[3]->look_down(_tag => 'a');
	        if ($a) {
	          $post{'who'} = $a->as_text;
	          $post{'whourl'} = $a->attr('href');
	          $post{'whourl'} =~ s/\?s=[^\&]+\&/\?/;
	        }
	      }
	      if (defined($div[4])) {
	      ## precis and link
	  # url
	        my $a = $div[4]->look_down(_tag => 'a');
	        if ($a) {
	          $post{'url'} = $a->attr('href');
	          $post{'url'} =~ s/\?s=[^\&]+\&/\?/;
	          if ($post{'url'} eq ${$latest_post}{'url'}) {
	            #print STDERR "We already knew this post, bailing on: ", $post{'url'}, "\n";
	            last;
	          }
	          $post{'urltext'} = $a->as_text;
	        }
	  # precis
	        my $em = $div[4]->look_down(_tag => 'em');
	        if ($em) {
	          my @p = $em->content_list;
	          foreach my $q (@p) {
	            #print Dumper($q);
	            if (!ref($q)) {
	              $post{'precis'} .= $q;
	            } elsif ($q->tag eq 'br') {
	              $post{'precis'} .= "\n";
	            }
	          }
	        }
	      }
	    }
	  }
	
	  #print Dumper(\%post);
	  $post{'whoid'} = $whoid;
	  $db->insert_post(\%post);
    $new_posts++;
	}
}
if ($new_posts > 0) {
  printf "Found %d new posts.\n", $new_posts;
}
exit(0);
