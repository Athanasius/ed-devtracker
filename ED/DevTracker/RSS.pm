#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

package ED::DevTracker::RSS;

use strict;
use Carp;
#use feature 'unicode_strings';

use XML::RSS;
use Date::Manip;

use ED::DevTracker::Config;
use ED::DevTracker::DB;
use HTML::Entities qw/encode_entities_numeric/;

sub new {
	my $class = shift;
  my $self = {};

	my $config = new ED::DevTracker::Config('file' => 'config.txt');
	$self->{'db'} = new ED::DevTracker::DB('config' => $config);;
	$self->{'base_url'} = "http://forums.frontier.co.uk/";
	$self->{'rss'} = undef;
	$self->{'self_url'} = $config->getconf('self_url');
  bless($self, $class);
  return $self;
}

sub ed_rss_encode {
	my ($self, $text) = @_;

  #return "" unless defined $text;
  if (!defined($text)) {
      confess "\$text is undefined in ED::DevTracker::RSS::ed_rss_encode(). We don't know how " . "to handle it!";
  }

  return $text if (!$self->_main->_encode_output);

  my $encoded_text = '';

  while ($text =~ s/(.*?)(\<\!\[CDATA\[.*?\]\]\>)//s) {

      # we use &named; entities here because it's HTML
      $encoded_text .= encode_entities($1) . $2;
  }

  # we use numeric entities here because it's XML
  $encoded_text .= encode_entities_numeric($text, '<>&');

  return $encoded_text;
}

sub generate {
	my $self = shift;

	my $posts = $self->{'db'}->get_latest_posts(100);
  $ENV{'TZ'} = 'UTC';
  my $date = new Date::Manip::Date;
  $date->config(
   'DateFormat' => 'GB',
   'tz' => 'UTC'
  );
  my $err = $date->parse(${${$posts}[0]}{'datestamp'});
  if ($err) {
    printf STDERR "rss.pl - Couldn't parse first post's date from DB\n";
    return undef;
  }
  my $latest_date = $date->printf("%a, %e %b %Y %H:%M:%S %z");
  
  $self->{'rss'} = XML::RSS->new(version => '2.0', encoding => 'UTF-8', encode_output => 1, encode_cb => \&ed_rss_encode);
	$self->{'rss'}->add_module(prefix => 'atom', uri => 'http://www.w3.org/2005/Atom');
  $self->{'rss'}->channel(
    title           => 'Elite: Dangerous - Dev Posts (Unofficial Tracker)',
    link            => 'http://www.miggy.org/games/elite-dangerous/devposts.html',
    description     => 'Elite: Dangerous Dev Posts (Unofficial Tracker)',
    language        => 'en',
		# rating
		# copyright
    # pubDate         => $latest_date,
    lastBuildDate   => $latest_date,
		# docs
    generator       => 'XML::RSS from custom scraped data',
    managingEditor  => 'edrss@miggy.org (Athanasius)',
    webMaster       => 'edrss@miggy.org (Athanasius)',
		atom						=> { 'link' => { 'href' => $self->{'self_url'}, 'rel' => 'self', 'type' => 'application/rss+xml' } }
	#$output =~ s/<language>en<\/language>/<language>en<\/language>\n<atom:link href="http:\/\/www\.miggy\.org\/games\/elite-dangerous\/devtracker\/ed-dev-posts\.rss" rel="self" type="application\/rss+xml" \/>/;
  );
  $self->{'rss'}->image(
    title => 'Elite: Dangerous - Dev Posts (Unofficial Tracker)',
    link  => 'http://www.miggy.org/games/elite-dangerous/devposts.html',
    url   => 'http://www.miggy.org/games/elite-dangerous/pics/elite-dangerous-favicon.png',
    description => 'Assets borrowed from Elite: Dangerous, with permission of Frontier Developments plc'
  );
  
  
  foreach my $p (@{$posts}) {
    my $err = $date->parse(${$p}{'datestamp'});
    my $post_date;
    if ($err) {
      printf STDERR "rss.pl - Couldn't parse a post's date from DB\n";
      $post_date = $latest_date;
    } else {
      $post_date = $date->printf("%a, %e %b %Y %H:%M:%S %z");
    }
    my $precis = ${$p}{'precis'};
    $precis =~ s/\n/<br\/>/g;
		#printf STDERR "Precis = '%s'\n", $precis;
		# Bloody smart quotes
		$precis =~ s/\N{U+0091}/\N{U+2018}/sg;
		#printf STDERR "Precis = '%s'\n", $precis;
		#printf STDERR "Threadtitle = '%s'\n", ${$p}{'threadtitle'};
    $self->{'rss'}->add_item(
      title => ${$p}{'who'} . " - " . ${$p}{'threadtitle'},
      link  => $self->{'base_url'} . ${$p}{'url'},
      pubDate => $post_date,
      permaLink  => $self->{'base_url'} . ${$p}{'url'},
      description => "<a href=\"" . $self->{'base_url'} . ${$p}{'url'} . "\">" . ${$p}{'urltext'} . "</a>\n<p>" . $precis . "\n</p>",
      mode => 'append'
    );
  }

	return 1;
}

sub output {
	my $self = shift;

	my $output = $self->{'rss'}->as_string;

	return $output;
}

sub header {
	my $self = shift;

	return "Content-Type: application/rss+xml; charset=UTF-8\n\n";
}

sub print {
	my $self = shift;

	print $self->header;
	print $self->output;
}

1;
