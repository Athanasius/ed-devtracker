#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop

use strict;
use Encode;
use Data::Dumper;

use ED::DevTracker::Config;
use ED::DevTracker::DB;

$ENV{'TZ'} = 'UTC';
my $config = ED::DevTracker::Config->new(file => "config.txt");
if (!defined($config)) {
    die "No config!\n";
}
my $db = new ED::DevTracker::DB('config' => $config);

my %developers = (
#  1 => 'fdadmin',
  2 => 'Michael Brookes',
### XXX   6 => 'David Walsh',
### XXX   7 => 'David Braben',
### XXX 	8 => 'Colin Davis',
### XXX # 13 => 'Natalie Amos',
### XXX   52 => 'BrettC', # Community Assistant
### XXX # 119 => 'Sam Denney',
### XXX 	1110 => 'Stefan Mars',
### XXX # 1388 => 'Kyle Rowley',
### XXX # 1890 => 'Callum Rowley',
### XXX   2000 => 'Drew Wagar', # Book author, and driver of the 'Formidine Rift' mystery
### XXX # 2017 => 'Alistair Lindsay',
### XXX 	2323 => 'Carlos Massiah',
### XXX # 2724 => 'Carl Russell',
### XXX   10691 => 'Gary Richards',
### XXX 	14349 => 'Adam Woods',
### XXX 	14849 => 'Simon Brewer',
### XXX 	15645 => 'Ashley Barley',
### XXX 	15655 => 'Sandro Sammarco',
### XXX 	15737 => 'Andrew Barlow',
### XXX 	17666 => 'Sarah Jane Avory',
### XXX   19388 => 'Andrew Gillett',
### XXX 	22712 => 'Mike Evans',
### XXX   22717 => 'John Kelly',
### XXX #  22790 => 'Igor Terentjev',
### XXX   23261 => 'Raphael Gervaise',
### XXX   24195 => 'James Avery',
### XXX #	24222 => 'Greg Ryder', # Former employee
### XXX # 24659 => 'Josh Atack', # Former Frontier Employee
### XXX   24701 => 'Xavier Henry',
### XXX 	25094 => 'Dan Davies',
### XXX 	25095 => 'Tom Kewell',
### XXX 	25591 => 'Anthony Ross',
### XXX 	26549 => 'Mark Allen',
### XXX 	26755 => 'Barry Clark',
### XXX 	26966 => 'chris gregory',
### XXX 	27713 => 'Selena Frost-King',
### XXX #	27895 => 'Ben Parry', # No longer at Frontier as of ~2015-05
### XXX   29088 => 'John Li',
### XXX 	31252 => 'hchalkley',
### XXX 	31307 => 'Jonathan Bottone',
### XXX 	31348 => 'Kenny Wildman',
### XXX   31354 => 'Joe Hogan',
### XXX 	31484 => 'Richard Benton',
### XXX   31810 => 'Ruben Penalva',
### XXX   31870 => 'Sergei Lewis',
### XXX   32114 => 'Daniel Varela',
### XXX #	32310 => 'Mark Boss', # Now only 'Competent'
### XXX 	32348 => 'Jon Pace',
### XXX   32350 => 'Adam Waite',
### XXX 	32352 => 'Aaron Gordon',
### XXX   32382 => 'Thomas Wiggins',
### XXX   32385 => 'oscar_sebio_cajaraville',
### XXX 	32574 => 'Matt Dickinson',
### XXX   32802 => 'Laurie Cooper',
### XXX   32835 => 'Viktor Svensson',
### XXX   33100 => 'Bob Richardson',
### XXX   33396 => 'Eddie Symons',
### XXX #	33683 => 'QA-', # Mark Brett
### XXX   34587 => 'arfshesaid',
### XXX 	34604 => 'Matthew Florianz',
### XXX   35599 => 'Tom Clapham',
### XXX 	47159 => 'Edward Lewis',
### XXX # Michael Gapper ?
### XXX   65404 => 'Yokai', # Tutorial & Guide Writer
### XXX # 71537 => 'eft_recoil_org', # Friendly Spider/Scraper Bot
### XXX #  74198 => 'GalNet News', # GalNet News Transmissions are sponsored in part by the Bank of Zaonce.  Trust the Bank of Zaonce with your hard-earned credits. 
### XXX   74985 => 'GuyV', #FDEV
### XXX   78894 => 'Laura Massey', # 'Mostly Harmless' QA Tester <https://forums.frontier.co.uk/showthread.php?t=176323>
### XXX   81888 => 'Daniel G', # Frontier QA Team
### XXX   82776 => 'Frontier QA',
### XXX   84886 => 'Frontier Moderation Team', # Global Moderator
### XXX   93489 => 'SkyCline', # Test Account: Brett C So Dangerous, it's Fluffy.
### XXX #  94839 => 'QA-Donny', # Frontier QA Team
### XXX #  94841 => 'QA-Jonny', # Frontier QA Team
### XXX #  94842 => 'QA-Kae', # Frontier QA Team
### XXX   95307 => 'juanpablosans', # Localisation
### XXX   95888 => 'CMDR Vanguard', # Customer Support
### XXX   96285 => 'NotMatt', # Figment of your imagination
### XXX   97768 => 'Zac Antonaci', # Head of Community Management
### XXX #  97918 => 'Support-Black Arrow', # Customer Support Manager
### XXX #  97972 => 'Support-Sticks', # Customer Support
### XXX #  97973 => 'Support-Falcon', # Customer Support
### XXX #  97974 => 'Support-Taurus', # Customer Support
### XXX #  97975 => 'Support-Proton', # Customer Support
### XXX #  97976 => 'Support-Kosmos', # Customer Support
### XXX #  97977 => 'Support-Vanguard', # Customer Support
### XXX #  97978 => 'Support-Saturn', # Customer Support
### XXX #  97979 => 'Support-Delta', # Customer Support
### XXX #  97980 => 'Support-Atom', # Customer Support
### XXX #  97981 => 'Support-Titan', # Customer Support
### XXX #  97982 => 'Support-Ares', # Customer Support
### XXX #  97983 => 'Support-Vega', # Customer Support
### XXX #  97984 => 'Support-Miu', # Customer Support
### XXX #  98489 => 'FDTest1', # Administrator
### XXX   100780 => 'Ian Dingwall', # Senior Designer
### XXX   101652 => 'James Stimpson', # Senior Designer Elite: Dangerous
### XXX   102125 => 'Dav Stott', # Senior Server Developer
### XXX   106358 => 'Dale Emasiri', # Social Media Manager
### XXX   108846 => 'Steve Kirby', # Lead Games Designer
### XXX # 120185 => 'QA-Kit',
### XXX   148080 => 'Dominic Corner' # Programmer (Missions Team)
);

my $sth = $db->dbh->prepare('SELECT id,url FROM posts WHERE guid_url IS NULL');
my $rv = $sth->execute();
if (!defined($rv)) {
  die('Error selecting all posts');
}

my $usth = $db->dbh->prepare('UPDATE posts SET guid_url = ? WHERE id = ?');
my $row;
while ($row = $sth->fetchrow_hashref()) {
  my $guid_url = ${$row}{'url'};
  # Strip the embedded topic title
  $guid_url =~ s/^(?<start>showthread.php\/[0-9]+)(-[^\?]+)(?<end>\?p=[0-9]+#row[0-9]+)?$/$+{'start'}$+{'end'}/;
  printf STDERR "UPDATE posts SET guid_url = '%s' WHERE id = %d'\n", $guid_url, ${$row}{'id'};
  $rv = $usth->execute($guid_url, ${$row}{'id'});
  if (! $rv) {
    die("Error updating post: " . ${$row}{'id'});
  }
}

exit(0);
