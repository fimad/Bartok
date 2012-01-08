package Bartok;
#A simple wrapper for handling downloads from various sites

use strict;
use Exporter;

our @EXPORT = ();

our @Downloaders; #an array of arrays which contain a can_download and a download method
our $Searcher;

#add a downloader to our list
sub register{
  my( $downloader ) = @_;
  push @Downloaders, $downloader;
}

sub set_searcher{
  my( $searcher ) = @_;
  $Searcher = $searcher;
}

#returns true if we have a downloader that can handle the given link
sub can_download{
  my( $url ) = @_;
  for my $downloader (@Downloaders){
    my( $can_download, $download ) = @$downloader;
    if( $can_download->($url) ){
      return 1;
    }
  }
  return 0;
}

#downloads a url, returns 1 on success, 0 on failure
sub download{
  my( $url, $file, $dir ) = @_;
  for my $downloader (@Downloaders){
    my( $can_download, $download ) = @$downloader;
    if( $can_download->($url) ){
      return $download->($url, $file, $dir);
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

1;

