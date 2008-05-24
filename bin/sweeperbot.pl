#!/usr/bin/perl -w
use strict;

use App::SweeperBot;

print "SweeperBot, Copyright 2005-2008 Paul Fenwick <pjf\@cpan.org>\n";
print "Based upon code Copyright 2005 Matt Sparks <root\@f0rked.com>\n";
print "\n";

END {
	print "Program terminated.  Press enter to continue.\n";
	<STDIN>;
}


# Start Minesweeper.

App::SweeperBot->spawn_minesweeper();

package App::SweeperBot;

sleep(5);

enable_cheats() if CHEAT;

while (1) {

	# About the window
	our $id=(FindWindowLike(0, "^Minesweeper"))[0];
	our($l,$t,$r,$b)=GetWindowRect($id);
	our($w,$h)=($r-$l,$b-$t);
	# our($reset_x,$reset_y)=($l+$w/2,$t+70);
	our($reset_x,$reset_y)=($l+$w/2,$t+81);

	# Figure out our total number of squares
	# "header" of window is 96px tall
	# left side: 15px, right side: 11px
	# bottom is 11px tall

	# XXX - These constants are bogus, and depend upon the windowing
	# style used.
	# our($squares_x,$squares_y)=(($w-15-11)/SQUARE_W,($h-96-11)/SQUARE_H);
	our($squares_x,$squares_y)=(($w-15-11)/SQUARE_W,($h-104-11)/SQUARE_H);

	# Round up squares_y
	$squares_y = int ($squares_y + 0.9);

	our $squares=$squares_x*$squares_y;

	# Demo the program
	print "Width: $w, height: $h\n";
	print "$squares_x across, $squares_y down, $squares total\n";

	print "Focusing on the window\n";
	focus();

	print "Starting a new game\n";
	new_game();

	TURN: while(1) {
	    my $go=game_over;
	    if ($go==1) { print "Game is over, we won.\n"; last; }
	    elsif ($go==-1) { print "Game is over, we lost.\n"; last; } 

	    my $game_state = capture_game_state();

	    make_move($game_state);
	}

	print "Waiting 5 seconds before next game\n";
	sleep(5);
}
