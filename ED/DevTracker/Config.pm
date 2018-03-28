#!/usr/bin/perl -w
# vim: textwidth=0 wrapmargin=0 tabstop=2 shiftwidth=2 softtabstop

package ED::DevTracker::Config;

#use Data::Dumper;

our %config = (
	db_host => '',
	db_name => '',
	db_user => '',
	db_password => '',
	self_url => '',
	self_fulltext_url => '',
	sleep_after => 300,
	user_agent => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36',
	ua_timeout => 10,
	forum_user => '',
	forum_password => '',
	forum_base_url => 'https://forums.frontier.co.uk/'
);

sub new {
  my ($class, %args) = @_;
  my $self = bless {}, $class;
  my $file = $args{'file'};

  if (!open(CF, "<$file")) {
    printf STDERR "Failed to open file '%s' to read config\n", $file;
    return undef;
  }
  my $line = 0;
  while (<CF>) {
    $line++;
    chomp;
    if (/^\#/) {
      next;
		} elsif (/^db_host:\s+(.*)$/i) {
			$config{'db_host'} = $1;
		} elsif (/^db_name:\s+(.*)$/i) {
			$config{'db_name'} = $1;
		} elsif (/^db_user:\s+(.*)$/i) {
			$config{'db_user'} = $1;
		} elsif (/^db_password:\s+(.*)$/i) {
			$config{'db_password'} = $1;
		} elsif (/^self_url:\s+(.*)$/i) {
			$config{'self_url'} = $1;
		} elsif (/^self_fulltext_url:\s+(.*)$/i) {
			$config{'self_fulltext_url'} = $1;
		} elsif (/^sleep_after:\s+([0-9]+)$/i) {
			$config{'sleep_after'} = $1;
		} elsif (/^user_agent:\s+(\w+)$/i) {
			$config{'user_agent'} = $1;
		} elsif (/^ua_timeout:\s+(\w+)$/i) {
			$config{'ua_timeout'} = $1;
		} elsif (/^forum_user:\s+(\w+)$/i) {
			$config{'forum_user'} = $1;
		} elsif (/^forum_password:\s+(.+)$/i) {
			$config{'forum_password'} = $1;
		} elsif (/^forum_base_url:\s+(.+)$/i) {
			$config{'forum_base_url'} = $1;
		} elsif (/^memberid_file:\s+(.+)$/i) {
			$config{'memberid_file'} = $1;
		} elsif (/^forum_ignore_file:\s+(.+)$/i) {
			$config{'forum_ignore_file'} = $1;
		} else {
			printf STDERR "Unknown (or badly formatted) field in config file '%s', line %d : %s\n", $file, $line, $_;
		}
	}
	close(CF);
	#print "Config:\n", Dumper(\%config), "\n";

	return $self;
}

sub getconf {
  my $self = shift;
  my $field = shift;

  #printf STDERR "ConfigFile::getconf: field = '%s', which is: %s\n", $field, $config{$field};
  return $config{$field};
}

1;
