package App::SweeperBot;

# minesweeper.pl
# This is a program to manipulate a win32 minesweeper window. So far it can
# determine a value of a square, click squares, find the size of the grid,
# determine if the game is over, and start a new game.
#
# The original intent of this program was to beat minesweeper automatically,
# but after writing the framework, I decided that I would rather not code
# the algorithm portion. Thus, I'm releasing it in hopes that someone does
# finish the program. If you complete my work, please send me a copy, I'd like
# to see it. root@f0rked.com
#
# Win32::Screenshot, Win32::GuiTest, and Image::Magick are needed for this
# program. Use ActivePerl's PPM to install the first two:
#   ppm> install Win32-GuiTest
#   ppm> install http://theoryx5.uwinnipeg.ca/ppms/Win32-Screenshot.ppd
#
# Windows versions of ImageMagick (which also install PerlMagick) can be located
# at http://imagemagick.org/script/binary-releases.php
#
# 20050726, Matt Sparks (f0rked), http://f0rked.com

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Win32::Process qw(NORMAL_PRIORITY_CLASS);

use constant DEBUG => 0;
use constant CHEAT => 1;
use constant UBER_CHEAT => 0;

# use constant CHEAT_SAFE    => "d0737abfd3abdacfeb15d559e28c2f0b3662a7aa03ac5b7a58afc422110db75a";	# Old 58
use constant CHEAT_SAFE    => "ad95131bc0b799c0b1af477fb14fcf26a6a9f76079e48bf090acb7e8367bfd0e";
# use constant CHEAT_UNSAFE  => "374708fff7719dd5979ec875d56cd2286f6d3cf7ec317a3b25632aab28ec37bb";	# Old 58
use constant CHEAT_UNSAFE  => "e3820096cb82366b860b8a4e668453a7aaaf423af03bdf289fa308ea03a79332";

# alarm(180);	# Nuke process after three minutes, in case of run-aways.

use Win32::Screenshot;
use Win32::GuiTest qw(
    FindWindowLike
    GetWindowRect
    SendMouse
    MouseMoveAbsPix
    SendKeys
);

# Square width and height.

use constant SQUARE_W => 16;
use constant SQUARE_H => 16;

# Top-left square location (15,104)

use constant SQUARE1X => 15;
use constant SQUARE1Y => 104;
# use constant SQUARE1Y => 115;

my %char_for = (
        0            => 0,
        unpressed    => ".",
        1            => 1,
        2            => 2,
        3            => 3,
        4            => 4,
	5            => 5,
	6            => 6,
	7            => 7,
	8            => 8,
        bomb         => "x",
        bomb_hilight => "X",
	flag         => "*",
);

# old - Perl 5.8 and older ImageMagick
# new - Perl 5.10 and new ImageMagick

my %contents_of_square = (
        "0b6f3e019208789db304a8a8c8bd509dacf62050a962ae9a0385733d6b595427" => 0,           # old
	"cd348e1e78e4032f472c5c065c99d8289dffff7041096aa8746e29794a032698" => 0,           # new
        "35fc6aa19ab4b99bf7d4a750767ee329b773fb2709bec46204d0ffb0a2eae1e0" => "unpressed", # old
	"880113df76cbba6336d3d1c93b035e904dbce5663acb35f9494eb292bda0226c" => "unpressed", # new
        "7a66485db1fee47e7c33acff15df5b48feccbc0328ea6e68795e52ce43649e1a" => 1,	   # old
	"99a8c67265186adef6cb5d4d4b37fefc120f096fa9df6fe0b4f90d6843fcc1e1" => 1,	   # new
        "ab70100c9ac47c63edf679d838fbb10ca38a567a16132aaf42ed2fe159aa8605" => 2,	   # old
	"3bb6ebdba9eead463b427b9cc94881626275b9efc9dfd552e174a017c601d9c2" => 2,	   # new
        "799f98eb9f61f3e96def93145a6a065cf872e67647939a7e0f4c623f38f585c3" => 3,	   # old
	"bdb6e1609d57dfa5559860e9856919ba82c844043e6a294387d975bf55208133" => 3,           # new
        "b5b29ae361a9acf85ac81abb440d5a3f7525fe80738a5770df90832d0367f7d6" => 4,	   # old
	"56c72e77e03691789f10960bd4f728af2eb7a57dd04c977e6b2ab19b349e1943" => 4,	   # new
        "bff653f26af9160d66965635c8306795ca2440cd1e4eebf0f315c7abd0242fc6" => 5,           # old
	"2ce52acf436da1971ed234b8607d4928add74c5c02d8a012fce56477b52ba251" => 5,           # new
        "931b3e6a380fd85ee808fd4ac788123a0873bb3c1c30ec1737cea8e624ff866a" => 6,	   # old
	"36dc562ae36f15c7d3917e101a998736b3dc1a457872fea40e1f4bc896c3725c" => 6,	   # new
        "e5531a6de436ac50d36096b9d1b17bad2c919923650ca48063119f9868eb3943" => 7,           # old
	"2d95bf5bb506232fe283d18d3fac1ac331ddc8116c7dde83e02a3aaae7da47e6" => 7,	   # new
        "c18dd2d3747aa97a9f432993de175bd32f8e38a70a8c122c94c737f8909bc3ca" => 8,
        "ad10157084c576142c0b0e811ddf9f935c3aab5925831fe3bf9a2da226c0c6d9" => "bomb",
        "d748d75fb4fbff41cf54237a5e0fa919189a927f1776683f141a4e38feff06ab" => "bomb_hilight",
	"e4305b6c2c750ebf0869a465f5e4f7721107bf066872edbcacd15c399ae60bff" => "flag",      # old
	"645d48aa778b2ac881a3921f3044a8ed96b8029915d9b300abbe91bef3427784" => "flag",      # new
);

# Click the left button of the mouse.
# Arguments: x, y as ABSOLUTE positions on the screen
sub click {
    my($x,$y,$button)=@_;
    $button ||= "{LEFTCLICK}";
    MouseMoveAbsPix($x,$y);
    print "Button: $button\n" if DEBUG;
    SendMouse($button);
}

# Start a new game
sub new_game {
    our ($reset_x,$reset_y);
    click($reset_x,$reset_y);
}

# Focus on the Minesweeper window by clicking a little to the left of the game
# button.
sub focus {
    our ($reset_x, $reset_y);
    click($reset_x-50,$reset_y);
}

# Get an image capture of a single field.
# Arguments: sx, sy where 1,1 is the top left field in the grid.
# Returns Image::Magick object
sub capture_square {
    my($sx,$sy)=@_;
    our($l,$t);
    my $image=CaptureRect(
        $l+SQUARE1X+($sx-1)*SQUARE_W,
        $t+SQUARE1Y+($sy-1)*SQUARE_H,
        SQUARE_W,
        SQUARE_H);
    return $image;
}

# Determine the value of a single field
# Arguments: sx, sy
# Returns string value
sub value {
    my($sx,$sy)=@_;
    my $sig=capture_square($sx,$sy)->Get("signature");

    my $result = $contents_of_square{$sig};

    defined($result) or die "Square $sx,$sy contains a value I don't recognise\n\n$sig\n\n";

    return $result;
}

# Find the signature of a square. This probably shouldn't be used since all (?)
# of the signatures have already been determined.
sub sig {
    my($sx,$sy)=@_;
    my $im=capture_square($sx,$sy);
    return $im->Get("signature");
}

# Click on a field.
# Arguments: sx, sy
sub press {
    my($sx,$sy,$button)=@_;
    $button ||= "{LEFTCLICK}";
    our($l,$t);
    click(
        $l+SQUARE1X+($sx-1)*SQUARE_W+SQUARE_W/2,
        $t+SQUARE1Y+($sy-1)*SQUARE_H+SQUARE_W/2,
	$button
    );
}

# Stomp on a square (left+right click)
sub stomp {
	press(@_,"{MIDDLECLICK}");
}

sub flag_mines {
	my $game_state = shift;
	foreach my $square (@_) {
		my ($x,$y) = @$square;

		# Skip to the next square if we have record that this
		# has already been flagged (earlier this iteration).
		next if $game_state->[$x][$y] eq "flag";

		press($x,$y,"{RIGHTCLICK}");
		$game_state->[$x][$y] = "flag";
	}
}

sub mark_adjacent {
	my ($x, $y) = @_;
	press($x-1,$y-1,"{RIGHTCLICK}");
	press($x  ,$y-1,"{RIGHTCLICK}");
	press($x+1,$y-1,"{RIGHTCLICK}");

	press($x-1,$y  ,"{RIGHTCLICK}");
	press($x+1,$y  ,"{RIGHTCLICK}");

	press($x-1,$y+1,"{RIGHTCLICK}");
	press($x  ,$y+1,"{RIGHTCLICK}");
	press($x+1,$y+1,"{RIGHTCLICK}");

}

# Is the game over (we hit a mine)? 
# Returns -1 if game is over and we lost, 0 if not over, 1 if over and we won
sub game_over {
    # Capture game button and determine its sig
    # Game button is always at (x,56). X-value must be determined by 
    # calculation using formula: x=w/2-11
    # Size is 26x26
    our($l,$t,$w);
    # my $smiley=CaptureRect($l+$w/2-11,$t+56,26,26);
    my $smiley=CaptureRect($l+$w/2-11,$t+64,26,26);
    # my $smiley=CaptureRect($l+$w/2-11,$t+75,26,26);

    my $sig = $smiley->Get("signature");

    # (5.10 smileys first, then 5.8)
    
    if ($sig eq "d28bcc05d38fd736f6715388a12cb0b96da9852432669671ee7866135f35bbb7" or
	$sig eq "efef2037072c56fb029da1dd2cd626282173d0e1b2be39eab3e955cd2bcdc856") {
        return 1;
    }
    elsif ($sig eq "08938969d349a6677a17a65a57f2887a85d1a7187dcd6c20d238e279a5ec3c18" or
	   $sig eq "7cf1797ad25730136aa67c0a039b0c596f1aed9de8720999145248c72df52d1b") {
        return -1;
    }
    # XXX - NB, the following is only a 5.10 smiley
    elsif ($sig eq "0955e50dda3f850913392d4e654f9ef45df046f063a4b8faeff530609b37379f") { return 0; }

    die "I don't know what the smiley means\n$sig\n";

}


print "SweeperBot, Copyright 2005-06 Paul Fenwick <pjf\@cpan.org>\n";
print "Based upon code Copyright 2005 Matt Sparks <root\@f0rked.com>\n";
print "\n";

# Start Minesweeper.

Win32::Process::Create(my $minesweeper, 'c:\WINDOWS\system32\winmine.exe',"",0,NORMAL_PRIORITY_CLASS,".") or die "Cannot spawn minesweeper! - ".Win32::GetLastError();

print "Minesweeper spawned.  Starting game in five seconds...\n";

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

	# our($squares_x,$squares_y)=(($w-15-11)/SQUARE_W,($h-96-11)/SQUARE_H);
	our($squares_x,$squares_y)=(($w-15-11)/SQUARE_W,($h-104-11)/SQUARE_H);
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

sub make_move {
	my ($game_state) = @_;
	our ($squares_x, $squares_y);
	my $altered_board = 0;
	foreach my $y (1..$squares_y) {
		SQUARE: foreach my $x (1..$squares_x) {

			if (UBER_CHEAT) {
				if (cheat_is_square_safe([$x,$y])) {
					press($x,$y);
				}
				else {
					flag_mines($game_state,[$x,$y]);
				}
				$altered_board = 1;
			}

			# Empty squares are dull.
			next SQUARE if ($game_state->[$x][$y] eq 0);

			# Unpressed/flag squares don't give us any information.
			next SQUARE if (not looks_like_number($game_state->[$x][$y]));

			my @adjacent_unpressed = adjacent_unpressed_for($game_state,$x,$y);
			# If there are no adjacent unpressed squares, then
			# this square is boring.
			next SQUARE if not @adjacent_unpressed;

			my $adjacent_mines = adjacent_mines_for($game_state,$x,$y);

			# If the number of mines is equal to the number
			# on this square, then stomp on it.
			
			if ($adjacent_mines == $game_state->[$x][$y]) {
				print "Stomping on $x,$y\n" if DEBUG;
				stomp($x,$y);
				$altered_board = 1;
			}

			# If the number of mines plus unpressed squares is
			# equal to the number on this square, then mark all
			# adjacent squares as having mines.
			if ($adjacent_mines + @adjacent_unpressed == $game_state->[$x][$y]) {
				print "Marking mines next to $x,$y\n" if DEBUG;
				flag_mines($game_state,@adjacent_unpressed);
				$altered_board = 1;
			}
			
		}
	}
	if (not $altered_board) {
		# Drat!  Can't find a good move.  Pick a square at
		# random.
		
		my @unpressed = ();

		foreach my $x (1..$squares_x) {
			foreach my $y (1..$squares_y) {
				push(@unpressed,[$x,$y]) if $game_state->[$x][$y] eq "unpressed";
			}
		}

		my $square = $unpressed[rand @unpressed];

		if (CHEAT) {
			while (not cheat_is_square_safe($square)) {
				$square = $unpressed[rand @unpressed];
			}
		}

		print "Guessing square ",join(",",@$square),"\n" if DEBUG;
		press(@$square);

	}
	return;
}

sub capture_game_state {
	my $game_state = [];
	our ($squares_x, $squares_y);

	for my $y (1..$squares_y) {
    		for my $x (1..$squares_x) {
			my $square_value = value($x,$y);
			$game_state->[$x][$y] = $square_value;
			print $char_for{$square_value} if DEBUG;
		}
		print "\n" if DEBUG;
	}
	print "---------------\n" if DEBUG;

	# To make things easier later on, we provide a one square "padding"
	# of virtual squares that are always empty.
	
	for my $x (0..$squares_x+1) {
		$game_state->[$x][0] = 0;
		$game_state->[$x][$squares_y+1] = 0;
	}

	for my $y (0..$squares_y+1) {
		$game_state->[0][$y] = 0;
		$game_state->[$squares_x+1][$y] = 0;
	}

	return $game_state;
}

sub adjacent_mines_for {
	my ($game_state,$x,$y) = @_;
	return mines_at($game_state,
		[$x-1, $y-1],   [$x, $y-1],   [$x+1, $y-1],
		[$x-1, $y  ],                 [$x+1, $y  ],
		[$x-1, $y+1],   [$x, $y+1],   [$x+1, $y+1],
	);
}

sub adjacent_unpressed_for {
	my ($game_state, $x, $y) = @_;
	return unpressed_list($game_state,
		[$x-1, $y-1],   [$x, $y-1],   [$x+1, $y-1],
		[$x-1, $y  ],                 [$x+1, $y  ],
		[$x-1, $y+1],   [$x, $y+1],   [$x+1, $y+1],
	);
}

sub mines_at {
	my ($game_state, @locations) = @_;

	my $mines = 0;

	foreach my $square (@locations) {
		if ($game_state->[ $square->[0] ][ $square->[1] ] eq "flag") {
			$mines++;
		}
	}
	return $mines;
}

sub unpressed_list {
	my ($game_state, @locations) = @_;

	my @unpressed = grep { ($game_state->[ $_->[0] ][ $_->[1] ] eq "unpressed") } @locations;

	return @unpressed;
}

# Technically this should end with a "left-shift", but shift-space seems to work.

sub enable_cheats {
	SendKeys("xyzzy{ENTER}+ ");
}

sub cheat_is_square_safe {
	my ($square) = @_;
	our($l,$t);
	
	MouseMoveAbsPix(
		$l+SQUARE1X+($square->[0]-1)*SQUARE_W+SQUARE_W/2,
		$t+SQUARE1Y+($square->[1]-1)*SQUARE_H+SQUARE_W/2,
	);

	# Capture our pixel.
	my $pixel =  CaptureRect(0,0,1,1);

	my $signature = $pixel->Get("signature");

	print "Square at @$square has sig of $signature\n" if DEBUG;

	if ($signature eq CHEAT_SAFE) {
		print "This square (@$square) looks safe\n" if DEBUG;
		return 1;
	} elsif ($signature eq CHEAT_UNSAFE) {
		print "This square (@$square) looks dangerous!\n" if DEBUG;
		return;
	} 
	die "Square @$square has unknown cheat-signature\n$signature\n";
}

__END__

=head1 Minesweeper algorithm.

while (not game_over) {
	foreach (square) {

		# If the number of adjacent mines + uncovered squares
		# is equal to the number on the square, then mark all
		# uncovered squares as mines.

		# If the number of adjacent mines is equal to the
		# number on this square, and there are still uncovered
		# squares, then stomp on it.

		# If we complete all of our squares without finding any
		# of the above two conditions, then pick a square at
		# random.

	}
}

=head2 Square definitions

Our squares can either be:

	* A mine (marked)
	* Covered square (unknown)
	* An uncovered square (with a number / 0)


CHEAT MODE - xyzzy, enter, left-shift
		pixel abs(0,0) changes colour.  black is mine, white is good.

