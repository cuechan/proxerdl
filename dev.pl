#!/usr/bin/perl

use strict;
use warnings;
use LWP;


# can i add something something to an array in the middle of nowhere?

my @array;

$array[8] = "8";
$array[20] = "20";

foreach(@array) {
	if($_) {
		print("$_\n");
	}else {
		print("undefined\n");
	}
}


# yes i can! 
#perlisawesome
