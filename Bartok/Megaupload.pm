package Bartok::Megaupload;
#downloader for megaupload

use strict;
use Exporter;
use Web::Scraper;
use LWP::UserAgent;
use HTTP::Request;
use URI;
use URI::Escape;

our @EXPORT = ();
our $USER_AGENT = "Mozilla/5.0 (Windows NT 6.1; U; ru; rv:5.0.1.6) Gecko/20110501 Firefox/5.0.1 Firefox/5.0.1";
our $CHECK_BACK = 900; #15 minutes in seconds

sub can_download{
  my( $url ) = @_;
  return (lc $url) =~ m/^http:\/\/(www.)?megaupload.com/;
}

our $megaupload_scraper = scraper{
#  process 'div#downloadlink > a', 'link' => '@href';
  process 'a.download_regular_usual', 'link' => '@href';
  process 'div.download_file_name', 'filename' => 'TEXT';
  process 'div.description_bl', 'description' => 'TEXT';
  process 'div.download_file_size', 'size' => 'TEXT';
};

sub download{
  my( $url, $fileName, $dir ) = @_;
#grab an instance of curl
  my $ua = LWP::UserAgent->new();
  $ua->agent($USER_AGENT);
  $ua->cookie_jar({});

  while(1) { #sit in the download loop until we are allowed to download

#download the index page
    my $req = HTTP::Request->new( GET=>$url );
    my $result = $ua->request( $req );

#scrape the download link from the body
    $result = $megaupload_scraper->scrape( $result->content );
    return 0 if( not exists $result->{'link'} ); #drop out if there is not link
    my $fileUrl = $result->{'link'};

#figure out the name of the file if we don't have it
    if( not $fileName ){
      $fileUrl =~ m/\/([^\/]+)$/;
      $fileName = uri_unescape($1);
    }

#apparently they enforce the time limit server side :(
#    sleep(45);

#download the file
    my $req = HTTP::Request->new( GET=>$fileUrl );
    $result = $ua->request( $req, "$dir/$fileName");

    return "$dir/$fileName" if( $result->{'_msg'} ne 'Limit Exceeded' );
    sleep $CHECK_BACK;
  }

  return 0;
}

sub info{
  my( $url ) = @_;
  my $result = $megaupload_scraper->scrape( URI->new($url) );
  return 0 if( not exists $result->{'link'} ); #drop out if there is not link
  my $desc = $result->{'description'};
  $desc =~ s/^File description: //g;
  $result->{'size'} =~ s/^ +| +$//g;
  $result->{'filename'} =~ s/^ +| +$//g;
  return {
    description=>$desc,
    size=>$result->{'size'},
    filename=>$result->{'filename'},
  };
}

#a short cut for having to write out the array of can_download and download
sub handle{
  return {can_download=>\&can_download, download=>\&download, info=>\&info};
}

1;

