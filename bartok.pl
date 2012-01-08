#!/usr/bin/perl
use strict;
use warnings;
use lib '/home/tapeside/src/bartok/';
use Bartok;
use Bartok::Config;
use Bartok::Megaupload;
use Bartok::FilesTube;
use Bartok::Curses;
use Getopt::Long;
use Proc::Daemon;
use File::Copy;
use Fcntl ':flock';

########################
# command line options #
########################

#global options
my $_CONFIG = "$ENV{'HOME'}/.bartok/bartok.cfg"; #where is our config file?

#daemon options
my $_DAEMON = 0; #run the daemon

#client options
my $_HIGH = 0; #is this a high priority download?
my @_ADD = (); #will contain the url and optionally the file name
my @_SEARCH = (); #contains the search query and the file and folder name
my $_STATUS = 0; #print out the current status of the daemon
my $_QUEUE = 0; #list the download queue
my $_CURSES = 0; #should we launch the curses gui?

GetOptions(
#global
  "config=s" => \$_CONFIG,
#daemon
  "d" => \$_DAEMON,
#client
  "high" => \$_HIGH,
  "add=s{1,3}" => \@_ADD,
  "find=s{1,3}" => \@_SEARCH,
  "status" => \$_STATUS,
  "queue" => \$_QUEUE,
  "curses" => \$_CURSES
);

sub showUsageAndDie{
  die "usage: $0 -d

       $0 --add url
       $0 --add url filename
       $0 --add url filename directory

       $0 --find 'query'
       $0 --find 'query' filename
       $0 --find 'query' filename directory

       $0 --status
       $0 --queue

Note: --config file Can be supplied to use a configuration file other than the default of ~/.bartok/bartok.cfg
";
}

#Initialize Bartok
Bartok::Config::load($_CONFIG);
Bartok::set_searcher( Bartok::FilesTube::handle );
Bartok::register( Bartok::Megaupload::handle );


###############
# Client Code #
###############

if( not $_DAEMON ){

  if( not Bartok::Config::daemon_running() ){
    print STDERR "Warning: Daemon does not appear to be running.\n\n";
    exit;
  }

  if( $_CURSES ){
    Bartok::Curses::run();
  }elsif( @_ADD ){
#    my $priority = $_HIGH;
#    my $entry = join("\t", @_ADD);
#    open( QUEUE, ">>", Bartok::Config::queue_file() ) or die( "Cannot access the queue file.\n" );
#    sleep(1) while( not flock( QUEUE, LOCK_EX ) ); #lock the queue
#    print QUEUE "$priority\t$entry\n";
#    close( QUEUE );
    Bartok::client_add($_HIGH, @_ADD);
  }elsif( @_SEARCH ){
    while( 1 ){ #loop until the user says stop
      my @results = Bartok::search( $_SEARCH[0], 5 );

      if( @results ){
        my $index = 0;
        for my $r (@results){
          $index++;
          print "$index) $r->{'title'}\n";
          print "\tsize: $r->{'size'}\n";
          print "\turl: $r->{'url'}\n\n";
        }

#get user input
        my $choice = "";
        while( not ($choice =~ m/[0-9]+/ && $choice >= 1 && $choice <= $index)
            && not ($choice =~ m/^[NnQq]/) ){
          print "Would you like to download [1-${index}], [N]ext, or [Q]uit? [n] ";
          $choice = <>;
          chomp($choice);
        }

        if( $choice =~ m/^q|Q^/ ){
          last;
        }elsif( $choice =~ m/^[0-9]+$/ ){
          my $result = $results[$choice-1];
          client_add( $_HIGH, $result->{'url'}, $_SEARCH[1], $_SEARCH[2] );
          last;
        }

      }else{
        print "There are no results.\n";
        last;
      }
    }

  }elsif( $_STATUS ){
    open( STATUS, "<", Bartok::Config::status_file() ) or die( "" );
    print <STATUS>;
    close( STATUS );
  }elsif( $_QUEUE ){
    my @queue = Bartok::Config::read_queue();
    if( @queue ){
      my $number = 1;
      for my $item (@queue){
        my( $priority, $url, $filename, $directory ) = @$item;
        print "$number)\t$url",(($priority)?" (High Priority)":""),"\n";
        print "\tName: $filename\n" if $filename;
        print "\tDirectory: $directory\n" if $directory;
        print "\n";
        $number ++;
      }
    }else{
      print "There are no items in the queue.\n"
    }
  }else{
    showUsageAndDie;
  }

}


###############
# Daemon Code #
###############

if( $_DAEMON ){

  if( Bartok::Config::daemon_running ){
    die "Error: The daemon already appears to be running.\n";
  }
#TODO: Uncomment once you've tested the daemon more
#  Proc::Daemon::Init;
  Bartok::Config::write_lock; #own the lock file

#enter the download loop!
  while( 1 ){
    my($entry) = Bartok::Config::read_queue;
    if( $entry ){
      my( $priority, $url, $filename, $directory ) = @$entry;
      $filename = ($filename) ? $filename : 0;
      $directory = ($directory) ? $directory : Bartok::Config::complete_dir();

#update the status
      if( $filename ){
        Bartok::Config::set_status("Downloading '$url' as '$filename'");
      }else{
        Bartok::Config::set_status("Downloading '$url'");
      }
      
      my $downloadedFile;
      if( ($downloadedFile = Bartok::download($url, $filename, Bartok::Config::incoming_dir())) ){
#move the file to the final resting place if it is different from the incoming folder
        if( Bartok::Config::incoming_dir() ne $directory ){
          my $savedFile = $downloadedFile;
          $savedFile =~ s/^.+\/([^\/]+)$/$1/g; #change the path to the complete directory
          $savedFile = "$directory/$savedFile";
          move( $downloadedFile, $savedFile );
        }
      }else{
        Bartok::Config::log("Unable to download '$url'.");
      }

      Bartok::Config::pop_queue($entry);
    }

    Bartok::Config::set_status("Idle");
    sleep 5;
  }

}

