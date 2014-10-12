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

my $url = 'http://forums.frontier.co.uk/search.php?do=finduser&u=2';
my $req = HTTP::Request->new('GET', $url);
my $res = $ua->request($req);
if (! $res->is_success) {
  print STDERR "Failed to retrieve Michael Brookes' profile page";
  exit(1);
}

#print Dumper($res->content);
my $tree = HTML::TreeBuilder->new;
$tree->parse($res->decoded_content);
$tree->eof();
my $inlinemodform = $tree->look_down('id', 'inlinemodform');
if (! $inlinemodform) {
  print STDERR "Failed to find the list of posts";
  exit(2);
}

my @posts = $inlinemodform->look_down(
  _tag => 'table',
  class => 'tborder',
  sub { if (defined($_[0]->attr('id'))) { $_[0]->attr('id') =~ /^post[0-9]+$/; } else { return undef;} }
);
foreach my $p (@posts) {
  my %post;

  printf "Post: %s\n", $p->attr('id');

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

  print Dumper(\%post);
  $db->insert_post(\%post);
}
exit(0);
