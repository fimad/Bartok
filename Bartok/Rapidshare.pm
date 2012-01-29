package Bartok::Rapidshare;
#downloader for rapidshare links

use strict;
use Exporter;
use Web::Scraper;

our $CHECK_BACK = 900; #15 minutes in seconds
our @EXPORT = ();

our $rs_scraper = scraper{
  process 'span#js_downloaderror_filesize', 'size' => 'TEXT';
  process 'p.filelink', 'filename' => 'TEXT'; #contains the entire url, chop off all before last / to get filename
};

sub can_download{
  my( $url ) = @_;
  return (lc $url) =~ m/^http:\/\/(www.)?rapidshare\.com/;
}

sub download{
  my( $url, $fileName, $dir ) = @_;
}

sub info{
  my( $url ) = @_;
#  return {
#    description=>$desc,
#    size=>$result->{'size'},
#    filename=>$result->{'filename'},
#  };
}

#a short cut for having to write out the array of can_download and download
sub handle{
  return {can_download=>\&can_download, download=>\&download, info=>\&info};
}

1;
