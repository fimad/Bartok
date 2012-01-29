package Bartok::Curses;
#a curses gui for bartok

use strict;
use Exporter;
use Bartok::Config;
use Curses::UI;
use threads;

our $cui; #global curses handle
our $windowAction;
our $windowStatus;
our $windowQueue;
our $windowInfo;
our @queueCache;
our $currentInfo; #which index in info Urls are we displaying?
our @infoUrls; #the current or last used info links
our %infoCache; #maps from links to info so we don't need to keep polling each time we inspect

#run the curses interface
sub run {
#initialize curses and keybindings
  $cui = new Curses::UI( -color_support => 1 );
  $cui->set_binding( sub{$cui->leave_curses(); exit} , "\cC");
  $cui->set_binding( sub{$windowAction->focus();} , "\ct");
  $cui->set_binding( sub{$windowQueue->focus();} , "\cq");

#set up the main windows
  showActions();
  showStatus();
  showQueue();
  think(); #fill in initial values for queue and status

#set up a timer to call the think functions
  $cui->set_timer("think",\&think,1);

#hand off control to curses
  $cui->mainloop();
}

sub timer {
  my($callback, $time) = @_;
  while(1){
    $callback->();
    sleep($time);
  }
}

sub think {
#update the status
  my $status = Bartok::Config::get_status;
  $windowStatus->getobj("message")->text("$status");
  $windowStatus->draw();

#update the queue
  my @queue = Bartok::read_queue();
  if( @queueCache != @queue ){
    @queueCache = @queue;
    my @values = ();
    my %labels = ();
    if( @queue ){
      my $number = 1;
      for my $item (@queue){
        push @values, ($number-1); #set the value equal to the index
        my( $priority, $url, $filename, $directory ) = @$item;
        my $label;
        $label.= "$number)\t$url";
        $label.= "\t($filename)" if $filename;
        
        $labels{$number-1}=$label;
        $number ++;
      }
    }
    $windowQueue->getobj("list")->values(\@values);
    $windowQueue->getobj("list")->labels(\%labels);
    $windowQueue->draw();
  }

}

sub refreshInfo{
#update the info window
  if( @infoUrls and $windowInfo ){
    my @queueInfo = @{$infoUrls[$currentInfo-1]};
    my $url = $queueInfo[1];
    #grab the info from the cache or from the net
    my $info = ( exists $infoCache{$url} ) ? $infoCache{$url} : Bartok::info($url) ;
    $infoCache{$url} = $info; #save the info the cache
    my $num = scalar @infoUrls;
#update the window
    $windowInfo->getobj("entry_number")->text("Entry $currentInfo of $num");
    $windowInfo->getobj("url")->text($url);
    $windowInfo->getobj("filename")->text($info->{filename});
    $windowInfo->getobj("size")->text($info->{size});
    $windowInfo->getobj("description")->text($info->{description});
    $windowInfo->getobj("localname")->text( ($queueInfo[2]) ? $queueInfo[2] : $info->{filename} );
    $windowInfo->getobj("folder")->text( ($queueInfo[3]) ? $queueInfo[3] : Bartok::Config::complete_dir );
    $windowInfo->draw();
  }
}

######################
#   Action Window    #
######################

#create the initial list of available actions
sub handleActions{
  my($list) = @_;
  showSearch() if $list->get eq "search";
  showDownload() if $list->get eq "download";
}
sub showActions {
  $windowAction = $cui->add("actions", "Window",
    -fg=>"blue",
    -border=>1,
    -width=>20,
    -title=>"Tasks",
  );
  my $list = $windowAction->add("list", "Listbox",
    -values=>["search","download","config"],
    -labels=>{
      "search"=>"Search for files",
      "download"=>"Queue Urls",
      "config"=>"Configure Bartok",
    },
    -height=>5,
    -onchange=>\&handleActions,
  );
}

#####################
#   Status Window   #
#####################

sub showStatus {
  $windowStatus= $cui->add("status", "Window",
    -title=>"Status",
    -fg=>"blue",
    -border=>1,
    -height=>5,
    -x=>20,
  );
  $windowStatus->add("message","Label",
    -text=>"Status: ",
    -width=>-1,
    -height=>2,
    -padtop=>1,
    -padleft=>2,
    -padright=>2,
  );
}

#####################
#   Queue Window    #
#####################

sub forSelectedInQueue{
  my( $action ) = @_;
  my @indices = sort $windowQueue->getobj("list")->get();
  map {$action->($_)} @indices;
}

sub forSelectedInQueueReverse{
  my( $action ) = @_;
  my @indices = reverse (sort $windowQueue->getobj("list")->get());
  map {$action->($_)} @indices;
}

sub showQueue {
  $windowQueue= $cui->add("queue", "Window",
    -title=>"Queue",
    -fg=>'blue',
    -border=>1,
    -y=>5,
    -x=>20,
  );
  $windowQueue->add("list","Listbox",
    -htmltext=>1,
    -multi=>1,
    -padbottom=>1,
    -y=>2,
    -values=>[(1..100)],
    -vscrollbar=>'right',
  );
  $windowQueue->add("misc_buttons","Buttonbox",
    -buttons=>[
      { -label=>" <Info> ",
        -onpress=>sub{hideInfo(); showInfo($windowQueue->getobj("list")->get())},
        -shortcut=>"\cI",
      },
      { -label=>" <Delete> ",
        -onpress=>sub{
          forSelectedInQueueReverse(sub{ splice @queueCache, $_[0], 1;});
          Bartok::write_queue(@queueCache);
          @queueCache = (); think(); #for refresh the queue
        },
        -shortcut=>"\cD",
      },
      { -label=>" <Move Up> ",
        -onpress=>sub{
          my @indices = $windowQueue->getobj("list")->get();
          my %transpose;
          for my $i (sort @indices){
            $transpose{$i} = (grep($_==$i-1,values %transpose) or $i == 0) ? $i : $i-1;
          }
          forSelectedInQueue(sub{
            my($i) = @_;
            if( $i != $transpose{$i} ){
              my $tmp = $queueCache[$i];
              splice @queueCache, $i, 1;
              splice @queueCache, $transpose{$i}, 0, $tmp;
            }
          });
          Bartok::write_queue(@queueCache);
          @queueCache = (); think(); #for refresh the queue
          $windowQueue->getobj("list")->set_selection(values %transpose);
          $windowQueue->draw();
        },
      },
      { -label=>" <Move Down> ",
        -onpress=>sub{
          my @indices = $windowQueue->getobj("list")->get();
          my $size = @queueCache;
          my %transpose;
          for my $i (reverse sort @indices){
            $transpose{$i} = (grep($_==$i+1,values %transpose) or $i+1 >= $size) ? $i : $i+1;
          }
          forSelectedInQueueReverse(sub{
            my($i) = @_;
            if( $i != $transpose{$i} ){
              my $tmp = $queueCache[$i];
              splice @queueCache, $i, 1;
              splice @queueCache, $transpose{$i}, 0, $tmp;
            }
          });
          Bartok::write_queue(@queueCache);
          @queueCache = (); think(); #refresh queue
          $windowQueue->getobj("list")->set_selection(values %transpose);
          $windowQueue->draw();
        },
      },
    ]
  );
}

#####################
#    Info Window    #
#####################

sub showInfo {
  my( @indices ) = @_;
#@infoUrls = map { $queueCache[$_][1] } @indices; #grab the url for the indices
  @infoUrls = map { $queueCache[$_] } (sort @indices); #grab the url for the indices

  $windowInfo = $cui->add("info","Window",
    -title=>"Info",
    -fg=>'blue',
    -border=>1,
    -centered=>1,
    -width=>60,
    -height=>12,
  );
  $windowInfo->add("buttons","Buttonbox",
    -y=>9,
    -buttonalignment=>'middle',
    -selected=> (@infoUrls <= 1 ) ? 0 : 3, #default to close if there are 0 or 1 entries, next otherwise
    -buttons=>[
      { -label=>' <Close> ',
        -onpress=>\&hideInfo,
      },
      { -label=>' <Save> ',
        -onpress=>sub{},
        -shortcut=>"\cS",
      },
      { -label=>' <Prev> ',
        -onpress=>sub{$currentInfo-- if $currentInfo > 1; refreshInfo();},
        -shortcut=>"\cp",
      },
      { -label=>' <Next> ',
        -onpress=>sub{$currentInfo++ if $currentInfo < @infoUrls; refreshInfo();},
        -shortcut=>"\cn",
      },
    ],
  );

#if we didn't select any url's, then don't display the fields
  if( @infoUrls ){
    my $num = scalar @infoUrls;
    $currentInfo = 1;
    $windowInfo->add("entry_number","Label",
      -textalignment=>'right',
      -width=>-1,
      -text=>"Entry $currentInfo of $num"
    );
    $windowInfo->add("labels","Label",
      -x=>1,
      -y=>1,
      -text=>
"        Url:
   Filename:
       Size:
Description: 

 Local Name:
Save Folder:"
    );
    $windowInfo->add("url", "Label",
      -width=>-1,
      -x=>14,
      -y=>1,
    );
    $windowInfo->add("filename", "Label",
      -width=>-1,
      -x=>14,
      -y=>2,
    );
    $windowInfo->add("size", "Label",
      -width=>-1,
      -x=>14,
      -y=>3,
    );
    $windowInfo->add("description", "Label",
      -width=>-1,
      -x=>14,
      -y=>4,
    );
    $windowInfo->add("localname", "TextEntry",
      -fg=>'white',
      -bg=>'blue',
      -bold=>1,
      -width=>-1,
      -x=>14,
      -y=>6,
    );
    $windowInfo->add("folder", "TextEntry",
      -fg=>'white',
      -bg=>'blue',
      -bold=>1,
      -width=>-1,
      -x=>14,
      -y=>7,
    );

    refreshInfo(); #fill in the fields
  }else{
    $windowInfo->add("error_message","Label",
      -y=>2,
      -width=>-1,
      -textalignment=>'middle',
      -text=>"No items selected.",
    );
  }

  $windowInfo->getobj("buttons")->focus();
  $windowInfo->focus();
}
sub hideInfo {
  @infoUrls = ();
  $cui->delete("info");
  $windowInfo = undef;
  $cui->draw();
}


1;

