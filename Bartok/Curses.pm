package Bartok::Curses;
#a curses gui for bartok

use strict;
use Exporter;
use Curses::UI;

our $cui; #global curses handle

#run the curses interface
sub run {
  $cui = new Curses::UI( -color_support => 1 );
}

############################
# Window Creation Routines #
############################

#create the initial list of available actions
sub windowActions {
  $cui->add("actions", "Window", -pad=>100);

}
