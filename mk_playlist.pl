#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use File::Spec;
use Storable qw/:DEFAULT dclone/;
use Data::Dumper;

# make A simple m3u playlist from a given dir
use lib ".";
use CUEsmith;

use Cwd;

my (@indir, $help, $sort_by_name);
GetOptions(
	'dir=s{1,}'=>\@indir,
	'sort'=>\$sort_by_name,
	'help'=>\$help,
);

if ($help or !@indir) { die <<USAGE;
-------------------------
# make a combined m3u playlist of all cue files under each given dir.

--- required -----
[-d DIR1 DIR2 ...] # only cue files will be taken

--- optional -----
[-s] # sort cue files under each given folder by filename, useful for a compilation of albums

-------------------------

USAGE
}


foreach my $dir (@indir) {
	next if !-d $dir;
	$dir=~s/[\\\/]$//; # remove trailing / and \ , for easier processing of splitdir

	printf "- %s . . .\n", $dir;

	my @c=File::Spec->splitdir($dir);
	my $cuelist=CUEsmith::get_cue_from_dir($dir, $sort_by_name);
	my $ofile2=File::Spec->catfile($dir, sprintf('_%s.m3u', $c[-1]) );

	open (my $fh2, ">", $ofile2);

	my $tt=localtime(time);
	printf $fh2 "# generated on %s\n", $tt;
	foreach my $cuefile (@$cuelist) {
		printf "    %s\n", $cuefile;
		printf $fh2 "%s\n", $cuefile;
	}
	close ($fh2);
	printf "\n   >> %s\n\n", $ofile2;
}