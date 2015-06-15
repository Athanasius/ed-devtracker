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
	sleep_after => 300
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
		} elsif (/^sleep_after:\s+([0-9]+)$/i) {
			$config{'sleep_after'} = $1;
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
