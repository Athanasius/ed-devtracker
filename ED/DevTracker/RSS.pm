#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

package ED::DevTracker::RSS;

use strict;
use Data::Dumper;

use XML::RSS;
use Date::Manip;

use ED::DevTracker::DB;

sub new {
	my $class = shift;
  my $self = {};
	$self->{'db'} = new ED::DevTracker::DB;
	$self->{'base_url'} = "http://forums.frontier.co.uk/";
	$self->{'rss'} = undef;
  bless($self, $class);
  return $self;
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
  
  $self->{'rss'} = XML::RSS->new(version => '2.0');
  $self->{'rss'}->channel(
    title           => 'Elite: Dangerous - Dev Posts',
    link            => 'http://www.miggy.org/games/elite-dangerous/devposts.html',
    language        => 'en',
    description     => 'Elite: Dangerous Dev Posts',
    # pubDate         => $latest_date,
    lastBuildDate   => $latest_date,
    generator       => 'XML::RSS from custom scraped data',
    managingEditor  => 'edrss@miggy.org (Athanasius)',
    webMaster       => 'edrss@miggy.org (Athanasius)'
  );
  $self->{'rss'}->image(
    title => 'Elite: Dangerous - Dev Posts',
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

	return $self->{'rss'}->as_string;
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
