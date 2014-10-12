#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

package ED::DevTracker::DB;

use strict;
use DBI;
use POSIX qw/strftime/;

my $db_host = 'db.fysh.org';
my $db_user = 'ed_devtracker_crawl';
my $db_name = 'ed_devtracker';
my $db_password = 'X3NFUI8HB6x0kD1D';

my $dsn = "DBI:Pg:database=" . $db_name . ";host=" . $db_host;
my $dbh = DBI->connect($dsn, $db_user, $db_password);
if (!defined($dbh)) {
                die("Couldn't connect to database");
}
$dbh->do('SET TIME ZONE \'UTC\'');

sub new {
  my $self = {};
  bless($self);
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
	my $sth = $dbh->prepare('INSERT INTO posts VALUES(DEFAULT,?,?,?,?,?,?,?,?,?)');
	my $rv = $sth->execute(strftime("%Y-%m-%d %H:%M:%S", gmtime(${$post}{'datestamp'})), ${$post}{'url'}, ${$post}{'urltext'}, ${$post}{'threadurl'}, ${$post}{'threadtitle'}, ${$post}{'forum'}, ${$post}{'who'}, ${$post}{'whourl'}, ${$post}{'precis'});
	if (! $rv) {
		printf STDERR "Error inserting a post\n";
		return undef;
	}
}

1;
