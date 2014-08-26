#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use LWP;
use Data::Dumper;
use HTML::TreeBuilder;

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
  printf "Post: %s\n", $p->attr('_tag');
}
exit(0);
