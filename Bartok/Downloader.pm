package Bartok::Downloader;
#downloader for megaupload

use warnings;
use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use URI::Escape;

our @EXPORT = ();
our $USER_AGENT = "Mozilla/5.0 (Windows NT 6.1; U; ru; rv:5.0.1.6) Gecko/20110501 Firefox/5.0.1 Firefox/5.0.1";

sub new{
  my $class = shift;
  my $self = {};

  my $ua = LWP::UserAgent->new();
  $ua->agent($USER_AGENT);
  $ua->cookie_jar({});

  $self->{_ua} = $ua;
  bless $self, $class;
}

#info is a hash that has the following values
#url: The url to download
#file: (Optional) the file to save the content received to
#method: (Optional) Either GET or POST, GET is assumed if not supplied
#form: (Optional) form values to be sent
sub download{
  my( $self, %info ) = @_;

#construct the http request
  my $request = (exists $info{method} and $info{method} eq 'POST') ?
    POST $info{url}, 
    ((exists $info{form}) ? $info{form} : {}) #if form is supplied, give it other wise give an empty hash
    :
    GET $info{url},
    ((exists $info{form}) ? $info{form} : {}) #if form is supplied, give it other wise give an empty hash
    ;
#  my $request = (($info->{method} eq 'POST') ? POST : GET )->( #depending on the method field, either use the POST or GET function
#    $info->{url}, #the first parameter is just the url
#    ((exists $info->{form}) ? $info->{form} : {}) #if form is supplied, give it other wise give an empty hash
#  );

#download the content and optionally save it to a file
  my $result = (exists $info{file}) ?
    $self->{_ua}->request( $request, $info{file} ) :
    $self->{_ua}->request( $request ) ;

  return ($result->code, $result->content);
}

sub scrape{
  my( $self, $scraper, %info ) = @_;
  my( $code, $content ) = $dl->download( %info );
  return $scraper->scrape( $content );
}

