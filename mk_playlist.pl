#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use File::Spec;
use Storable qw/:DEFAULT dclone/;
use Data::Dumper;

# make A simple m3u playlist from a given dir
# use lib ".";
# use CUEsmith;

use Cwd;

my (@indir, $help);
GetOptions(
	'dir=s{1,}'=>\@indir,
	'help'=>\$help,
);

if ($help or !@indir) { die <<USAGE;
-------------------------
# make simple m3u playlist from given dir(s)
# only read cue files

[-d DIR1 DIR2 ...]

-------------------------

USAGE
}


foreach my $dir (@indir) {
	next if !-d $dir;
	printf "%s . . .\n", $dir;
	my $ofile=File::Spec->catfile($dir, 'tmp_all_cue_files.txt');
	my $ofile2=File::Spec->catfile($dir, 'subdirplaylist.m3u');
	my $cmd=sprintf 'dir %s\*.cue /b /s >%s', $dir, $ofile; # hold all cue files into this txt file
	system($cmd);
	open (my $fh, $ofile);
	open (my $fh2, ">", $ofile2);
	my $tt=localtime(time);
	printf $fh2 "# generated on %s\n", $tt;
	while (<$fh>) {
		chomp;
		my $rel=File::Spec->abs2rel($_, $dir);
		printf "    %s\n", $rel;
		printf $fh2 "%s\n", $rel;
	}
	close ($fh);
	close ($fh2);
	unlink $ofile;
	printf "   >>%s\n\n", $ofile2;
}