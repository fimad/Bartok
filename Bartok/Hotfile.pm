package Bartok::Hotfile;
#downloader for hotfile links

use strict;
use Exporter;
use Web::Scraper;

our $CHECK_BACK = 900; #15 minutes in seconds
our @EXPORT = ();

#how to download:
#submit form 'f'
#grab the dl link with the inner_scraper

our $outer_scraper = scraper{
#form variables we need to pass to get the dl link
  process '//input[contains(@name, "action")]', 'f_action' => '@value';
  process '//input[contains(@name, "tm")]', 'f_tm' => '@value';
  process '//input[contains(@name, "tmhash")]', 'f_tmhash' => '@value';
  process '//input[contains(@name, "wait")]', 'f_wait' => '@value';
  process '//input[contains(@name, "waithash")]', 'f_waithash' => '@value';
  process '//input[contains(@name, "upidhash")]', 'f_upidhash' => '@value';
  process 'div.arrow_down', 'filename_size' => 'TEXT'; #contains the file name and size, must be further parsed
};
our $inner_scraper = scraper{
  process 'a.click_download', 'link' => '@href';
};

sub can_download{
  my( $url ) = @_;
  return (lc $url) =~ m/^http:\/\/(www.)?hotfile\.com/;
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
