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

my $bot = App::SweeperBot->new;

# Start Minesweeper.

$bot->spawn_minesweeper;

sleep(2);	# Wait for game to start

$bot->locate_minesweeper;
$bot->enable_cheats if App::SweeperBot::CHEAT;

while (1) {

	print "Starting a new game\n";
	$bot->new_game();

	while(1) {

	    if (my $state = $bot->game_over) {
		print "Game over!  ", $state > 0 ? "We won!\n" : "We lost!\n";
		last;
	    }

	    my $game_state = $bot->capture_game_state();

	    $bot->make_move($game_state);
	}

	print "Waiting 5 seconds before next game\n";
	sleep(5);
}
