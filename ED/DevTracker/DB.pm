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
  # Just going to have to do a SELECT first and hope nothing changes in
  # meantime.  XXX When we're on Postgresql 9.5+ we can use
  #      INSERT ... ON CONFLICT UPDATE (or ON CONFLICT DO NOTHING)
	my $sth = $dbh->prepare('SELECT id FROM posts WHERE guid_url = ?');
	my $rv = $sth->execute(${$post}{'guid_url'});
	if (!defined($rv)) {
	# Error, but zero rows would be success
		printf STDERR "Error checking if a URL already exists in posts table\n";
		return undef;
	} elsif ($rv > 0) {
  # (At least, huh?) one row already exists
		$sth = $dbh->prepare('UPDATE posts SET datestamp=?,urltext=?,threadurl=?,threadtitle=?,forum=?,whoid=?,who=?,whourl=?,precis=? WHERE guid_url = ?');
		#printf STDERR "UPDATE posts SET datestamp='%s',urltext='%s',threadurl='%s',threadtitle='%s',forum='%s',whoid='%s',who='%s',whourl='%s',precis='%s' WHERE guid_url = '%s'\n", strftime("%Y-%m-%d %H:%M:%S", gmtime(${$post}{'datestamp'})), ${$post}{'urltext'}, ${$post}{'threadurl'}, ${$post}{'threadtitle'}, ${$post}{'forum'}, ${$post}{'whoid'}, ${$post}{'who'}, ${$post}{'whourl'}, '<post precis elided>', ${$post}{'guid_url'};
		$rv = $sth->execute(strftime("%Y-%m-%d %H:%M:%S", gmtime(${$post}{'datestamp'})), ${$post}{'urltext'}, ${$post}{'threadurl'}, ${$post}{'threadtitle'}, ${$post}{'forum'}, ${$post}{'whoid'}, ${$post}{'who'}, ${$post}{'whourl'}, ${$post}{'precis'}, ${$post}{'guid_url'});
		if (! $rv) {
			printf STDERR "Error updating a post\n";
			return undef;
		}
	} else {
		$sth = $dbh->prepare('INSERT INTO posts (datestamp,url,urltext,threadurl,threadtitle,forum,whoid,who,whourl,precis,guid_url) VALUES(?,?,?,?,?,?,?,?,?,?,?)');
		#printf STDERR "INSERT INTO posts (datestamp,url,urltext,threadurl,threadtitle,forum,whoid,who,whourl,precis,guid_url) VALUES('%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s')\n", strftime("%Y-%m-%d %H:%M:%S", gmtime(${$post}{'datestamp'})), ${$post}{'url'}, ${$post}{'urltext'}, ${$post}{'threadurl'}, ${$post}{'threadtitle'}, ${$post}{'forum'}, ${$post}{'whoid'}, ${$post}{'who'}, ${$post}{'whourl'}, ${$post}{'precis'}, ${$post}{'guid_url'};
		$rv = $sth->execute(strftime("%Y-%m-%d %H:%M:%S", gmtime(${$post}{'datestamp'})), ${$post}{'url'}, ${$post}{'urltext'}, ${$post}{'threadurl'}, ${$post}{'threadtitle'}, ${$post}{'forum'}, ${$post}{'whoid'}, ${$post}{'who'}, ${$post}{'whourl'}, ${$post}{'precis'}, ${$post}{'guid_url'});
		if (! $rv) {
			printf STDERR "Error inserting a post\n";
			return undef;
		}
	}
}

sub user_latest_known {
	my ($self, $id) = @_;
	my $sth = $dbh->prepare('SELECT * FROM posts WHERE whoid=? ORDER BY datestamp DESC,id DESC LIMIT 50');
	my $rv = $sth->execute($id);
	if (! $rv) {
		printf "ED::DevTracker::DB->user_latest_known - Failed to get latest known posts by id", $id, "\n";
		return undef;
	}
	my $rows = $sth->fetchall_hashref('guid_url');
	if (!defined($rows)) {
		#printf STDERR "ED::DevTracker::DB->user_latest_known - No data from query\n";
		return undef;
	}
	return $rows;
}

sub get_latest_posts {
	my ($self, $days) = @_;
	# We're assuming here that $days isn't user-supplied.  Couldn't find a way to make this work with a '?' placeholder and providing the value on ->execute();
	# But let's make some attempt at sanitisation here.
	if ($days !~ /^[0-9]+$/) {
		$days = 1;
	}
	my $sth = $dbh->prepare("SELECT * FROM posts WHERE datestamp > (current_timestamp - INTERVAL '$days days') ORDER BY DATESTAMP DESC");
	my $rv = $sth->execute();
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
	if ($#posts < 0) {
		printf STDERR "ED::DevTracker::DB->get_latest_posts - No posts?\n";
		return undef;
	}
	return \@posts;
}

sub precis_ts_search {
	my ($self, $query) = @_;
	#printf STDERR "ED::DevTracker::DB->precis_ts_search - query is '%s'\n", $query;
	my $sth = $dbh->prepare("SELECT ts_rank_cd(precis_ts_indexed, query,4) AS rank,datestamp,url,threadurl,threadtitle,forum,who,precis,query FROM posts,to_tsquery(?) query WHERE precis_ts_indexed @@ query ORDER BY rank DESC, datestamp DESC;");
	my $rv = $sth->execute($query);
	if (! $rv) {
		printf STDERR "ED::DevTracker::DB->precis_ts_search - Failed DB query\n";
		return undef;
	}
	my @posts;
	my $row = $sth->fetchrow_hashref;
	while (defined($row)) {
		push(@posts, $row);
		$row = $sth->fetchrow_hashref;
	}
	if ($#posts < 0) {
		printf STDERR "ED::DevTracker::DB->precis_ts_search - No posts?\n";
		return undef;
	}
	return \@posts;
}

1;
