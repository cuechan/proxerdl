#!/usr/bin/perl

use strict;
use warnings;
use LWP;


foreach(0 .. 20) {
	print "$_\n";
	last if $_ == 12;
	print "OK\n";
}
