package Bartok;
#A simple wrapper for handling downloads from various sites

use strict;
use Exporter;
use Bartok::Config;
use Fcntl ':flock';

our @EXPORT = ();

our @Downloaders; #an array of arrays which contain a can_download and a download method
our $Searcher;

#add a downloader to our list
sub register{
  my( $downloader ) = @_;
  if( $downloader->{download} and $downloader->{can_download} and $downloader->{info} ){
    push @Downloaders, $downloader;
  }else{
    print STDERR "Skipping invalid download engine...\n";
  }
}

sub set_searcher{
  my( $searcher ) = @_;
  $Searcher = $searcher;
}

#returns true if we have a downloader that can handle the given link
sub can_download{
  my( $url ) = @_;
  for my $downloader (@Downloaders){
    if( $downloader->{can_download}->($url) ){
      return 1;
    }
  }
  return 0;
}

#downloads a url, returns 1 on success, 0 on failure
sub download{
  my( $url, $file, $dir ) = @_;
  for my $downloader (@Downloaders){
    if( $downloader->can_download->($url) ){
      return $downloader->{download}->($url, $file, $dir);
    }
  }
  return 0;
}

#returns info for a download url
sub info{
  my( $url ) = @_;
  for my $downloader (@Downloaders){
    if( $downloader->{can_download}->($url) ){
      return $downloader->{info}->($url);
    }
  }
  return 0;
}

sub search{
  my( $query, $max ) = @_;
  if( $Searcher ){
    return &$Searcher($query, $max );
  }
}

#checks whether queue has been updated
sub check_queue{
  return 1;
}

sub write_queue{
  my( @queue ) = @_;
  open( QUEUE, ">", Bartok::Config::queue_file() ) or die( "Cannot write queue" );
  for my $item (@queue){
    if( @$item >= 1 && @$item <= 4 ){
      print QUEUE join("\t", @$item), "\n";
    }
  }
  close( QUEUE );
}

#returns a list of the entries in the queue sorted by priority and time added
sub read_queue{
  my @normal_queue; #holds normal priority entries
  my @high_queue;
  open( QUEUE, "<", Bartok::Config::queue_file() ) or die( "" );
  my $line;
  while(defined( $line=<QUEUE> )){
    chomp $line;
    if( $line =~ m/^1\t(.+)$/ ){
      my @entry = split("\t", $line);
      push @high_queue, \@entry;
    }elsif( $line =~ m/^0\t(.+)$/ ){
      my @entry = split("\t", $line);
      push @normal_queue, \@entry;
    }
  }
  close( QUEUE );
  return (@high_queue, @normal_queue);
}

sub pop_queue{
  my( $entryToRemove ) = @_;
  my @queue = read_queue();

#find the entry in the queue and remove it
  my $index = 0;
  while( $index <= $#queue ){
    my $entry = $queue[$index];
    if( $entry->[1] eq $entryToRemove->[1] and 
      $entry->[2] eq $entryToRemove->[2] and 
      $entry->[3] eq $entryToRemove->[3] ){
      splice(@queue, $index, 1);
      last;
    }
    $index++;
  }

  open( QUEUE, ">", Bartok::Config::queue_file ) or die log("Cannot access the queue");
  sleep(1) while( not flock( QUEUE, LOCK_EX ) ); #lock the queue
  for my $item (@queue){
    print QUEUE join("\t", @$item), "\n";
  }
  close( QUEUE );
}

#add a url to the queue
sub push_queue{
  my( $priority, $url, $file, $folder ) = @_;
  my $entry = "$url";
  if( $file ){
    $entry = "$entry\t$file";
    if( $folder ){
      $entry = "$entry\t$folder";
    }
  }
  open( QUEUE, ">>", Bartok::Config::queue_file() ) or die( "Cannot access the queue file.\n" );
  sleep(1) while( not flock( QUEUE, LOCK_EX ) ); #lock the queue
  print QUEUE "$priority\t$entry\n";
  close( QUEUE );
}

1;

