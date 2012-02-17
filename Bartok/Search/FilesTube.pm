package Bartok::FilesTube;

use strict;
use English;
use Exporter;
use URI::Escape;
use Web::Scraper;
use URI;

our @EXPORT = ();

our $filestube_search_scraper = scraper{
  process "div.fsResultsEntry", "results_1[]" => scraper{
    process "a", title => 'TEXT';
    process "a", url => '@href';
    process "div.fsResultsDetails", detail => 'TEXT';
  };
  process "//div[contains(\@id,'newresult')]", "results_2[]" => scraper{
    process "a", title => 'TEXT';
    process "a", url => '@href';
    process "div > div > span", detail => 'TEXT';
#there is a bug where filestube includes a video add in a result throwing off details
#this will cause the result to be skipped
#    process "//div/div/span[contains(\@style,'style=\"color:#000;font-size:11px;\"')]", "detail" => 'TEXT';
  };
};

our $filestube_result_scraper = scraper{
  process "//pre[contains(\@id,'copy_paste_links')]", url => 'TEXT';
};

our %CurrentPage = (); #maps from a query to a current page number

#helper function to grab the actual link from filetubes go page
sub resolve_result{
  my( $result ) = @_;
  my $res = $filestube_result_scraper->scrape(URI->new($result->{'url'}));
  my @urls = split(/\s*\xa0\xa0\s*/,$res->{'url'});
  my $url = @urls[0];
  $url =~ s/[\n]//g;
  return {
    "title" => $result->{'title'},
    "url" => $url,
    "size" => $result->{'detail'}[2]
  };
}

sub search{
  my( $query, $max ) = @_;
  $query = uri_escape($query);
  my $no_change = 0;
  my $page = $CurrentPage{$query} or 1;
  $page++ if( $page == 0 );
  my @results;
  my $num_results = 0;

#build up a pool of at most $max results
  while( (not $no_change) && $num_results < $max ){
    $no_change = 1;
    my $search_result = $filestube_search_scraper->scrape(URI->new("http://www.filestube.com/search.html?q=$query&page=$page&hosting=3"));
    my @new_results = map {my @tmp = split(/\s*\xa0\xa0\s*/,$_->{'detail'}); $_->{'detail'} = \@tmp; $_ } (@{$search_result->{"results_1"}},@{$search_result->{"results_2"}}); #combine the two results
    @new_results = grep { @{$_->{'detail'}} == 4 } @new_results; #filter downloads that are in parts
    
#if there are results, add them to the pool, and mark that there are still resutls left
    if( @new_results ){
      @results = (@results,@new_results);
      $no_change = 0;
    };
    $page++;
    $num_results = @results;
  }

#save our place in case we want more results
  $CurrentPage{$query} = $page;

#filter out undownloadable links, and resolve the go pages
  @results = grep {$_->{'url'} and Bartok::can_download("http://$_->{'detail'}[0]/")} @results;
  @results = map {&resolve_result($_)} @results;
  return @results;
}

sub handle{
  return \&search;
}

1;

