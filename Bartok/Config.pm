package Bartok::Config;

use strict;
use English;
use DateTime;
use Exporter;
use Fcntl ':flock';

our @EXPORT = ();
#our @EXPORT_OK = qw(&load &lock_file &history_file &status_file &incoming_dir &complete_dir &daily_limit &daemon_running);

#The following are valid config file options:
# lock_file
our $LOCK_FILE = "$ENV{'HOME'}/.bartok/lock";
# history_file
our $HISTORY_FILE = "$ENV{'HOME'}/.bartok/history";
# queue_file
our $QUEUE_FILE = "$ENV{'HOME'}/.bartok/queue";
# log_file
our $LOG_FILE = "$ENV{'HOME'}/.bartok/log";
# status_file
our $STATUS_FILE = "$ENV{'HOME'}/.bartok/status";
# incoming_dir
our $INCOMING_DIR = "$ENV{'HOME'}/Downloads";
# complete_dir
our $COMPLETE_DIR = "$ENV{'HOME'}/Downloads";
# daily_limit (in bytes, 0 for unlimited)
our $DAILY_LIMIT = 0;

sub load{
  my( $configFile ) = @_;
  open( CONFIG, "<", "$configFile" ) or die( "Error: Cannot open '$configFile'\n" );
  my $line;
  while(defined( $line=<CONFIG> )){
    if( $line =~ m/^\s*#/ ){
      #skip, just a comment
    }elsif( $line =~ m/^lock_file\s+(.+)$/ ){
      $LOCK_FILE = $1;
    }elsif( $line =~ m/^history_file\s+(.+)$/ ){
      $HISTORY_FILE = $1;
    }elsif( $line =~ m/^queue_file\s+(.+)$/ ){
      $QUEUE_FILE = $1;
    }elsif( $line =~ m/^status_file\s+(.+)$/ ){
      $STATUS_FILE = $1;
    }elsif( $line =~ m/^incoming_dir\s+(.+)$/ ){
      $INCOMING_DIR = $1;
    }elsif( $line =~ m/^complete_dir\s+(.+)$/ ){
      $COMPLETE_DIR = $1;
    }elsif( $line =~ m/^daily_limit\s+(.+)$/ ){
      $DAILY_LIMIT = int($1);
    }
  }
  close( CONFIG );
}

#getters
sub lock_file{ $LOCK_FILE; }
sub log_file{ $LOG_FILE; }
sub history_file{ $HISTORY_FILE; }
sub queue_file{ $QUEUE_FILE; }
sub status_file{ $STATUS_FILE; }
sub incoming_dir{ $INCOMING_DIR; }
sub complete_dir{ $COMPLETE_DIR; }
sub daily_limit{ $DAILY_LIMIT; }

#updates the lock file
sub write_lock{
  open( LOCK, ">", "$LOCK_FILE" ) or die( "Error: Cannot open lock file.\n" );
  print LOCK "$PID\n";
  close( LOCK );
}

#is the daemon running?
sub daemon_running{
  my $pid = `cat $LOCK_FILE`;
  chomp $pid;
  if( $pid ){
    return kill 0, $pid;
  }
  return 0;
}

sub set_status{
  my( $status ) = @_;
  open( STATUS, ">", $STATUS_FILE ) or return;
  print STATUS "$status\n";
  close( STATUS );
}

sub get_status{
  open( STATUS, "<", $STATUS_FILE ) or die( "" );
  my $status=<STATUS>;
  close( STATUS );
  chomp $status;
  return $status;
}

sub log{
  my( $line ) = @_;
  open( LOG, ">>", $LOG_FILE ) or die( "Cannot open log file!\n" );
  print LOG DateTime->now()->datetime(), "\t$line\n";
  close( LOG );
}

1;

