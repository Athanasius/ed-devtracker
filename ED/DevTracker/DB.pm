#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

package ED::DevTracker::DB;

use strict;
use DBI;
use POSIX qw/strftime/;

our $dsn;
our $dbh;

sub new {
  my ($class, %args) = @_;
	my $self = bless {}, $class;
	my $config = $args{'config'};
	
	$dsn = "DBI:Pg:database=" . $config->getconf('db_name') . ";host=" . $config->getconf('db_host');
	$dbh = DBI->connect($dsn, $config->getconf('db_user'), $config->getconf('db_password'));
	if (!defined($dbh)) {
		print STDERR "Couldn't connect to database\n";
		return undef;
	}
	$dbh->do('SET TIME ZONE \'UTC\'');

  return $self;
}

sub dbh {
  return $dbh;
}

sub insert_post {
	my ($self, $post) = @_;

#$VAR1 = {
#	          'urltext' => 'No need to for insults - discuss the post - not...',
#	          'threadurl' => 'showthread.php?t=44103',
#	          'threadtitle' => 'Beta 2.01 update scheduled for later today',
#	          'datestamp' => 1412164860,
#	          'forum' => 'Beta Discussion Forum',
#	          'datestampstr' => ' 01/10/2014, 1:01 PM ',
#	          'who' => 'Michael Brookes',
#	          'precis' => '  
#	
#	 No need to for insults - discuss the post - not the poster or we\'ll start issuing infractions. 
#	
#	 Michael ',
#	          'url' => 'showthread.php?p=805408#post805408',
#	          'whourl' => 'member.php?u=2'
#	        };
	my $sth = $dbh->prepare('INSERT INTO posts VALUES(DEFAULT,?,?,?,?,?,?,?,?,?,?)');
	my $rv = $sth->execute(strftime("%Y-%m-%d %H:%M:%S", gmtime(${$post}{'datestamp'})), ${$post}{'url'}, ${$post}{'urltext'}, ${$post}{'threadurl'}, ${$post}{'threadtitle'}, ${$post}{'forum'}, ${$post}{'whoid'}, ${$post}{'who'}, ${$post}{'whourl'}, ${$post}{'precis'});
	if (! $rv) {
		printf STDERR "Error inserting a post\n";
		return undef;
	}
}

sub user_latest_known {
	my ($self, $id) = @_;
	my $sth = $dbh->prepare('SELECT * FROM posts WHERE whoid=? ORDER BY DATESTAMP DESC LIMIT 1');
	my $rv = $sth->execute($id);
	if (! $rv) {
		printf "ED::DevTracker::DB->user_latest_known - Failed to get latest known post by id", $id, "\n";
		return undef;
	}
	my $row = $sth->fetchrow_hashref;
	if (!defined($row)) {
		#printf STDERR "ED::DevTracker::DB->user_latest_known - No data from query\n";
		return undef;
	}
	return $row;
}

sub get_latest_posts {
	my ($self, $count) = @_;
	my $sth = $dbh->prepare('SELECT * FROM posts ORDER BY DATESTAMP DESC LIMIT ?');
	my $rv = $sth->execute($count);
	if (! $rv) {
		printf STDERR "ED::DevTracker::DB->get_latest_posts - Failed to get latest known post\n";
		return undef;
	}
	my @posts;
	my $row = $sth->fetchrow_hashref;
	while (defined($row)) {
		push(@posts, $row);
		$row = $sth->fetchrow_hashref;
	}
	if ($#posts == 0) {
		printf STDERR "ED::DevTracker::DB->get_latest_posts - No posts?\n";
		return undef;
	}
	return \@posts;
}

1;
