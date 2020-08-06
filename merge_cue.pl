#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use File::Spec;

use Data::Dumper;

# make sure the module is in same dir as the script. and before running, always go to the dir where this scripts stays so that it can finds the module.
use lib ".";
use CUEsmith;

# merge 2 or more cue files into one file
# updated 2020 aug 5

my (@files0,$help,$sort,$split, $ofile1);
GetOptions(
	'help'=>\$help,
	'order'=>\$sort, #by full path
	'writefile=s'=>\$ofile1,
	'split'=>\$split, # only works when given cue contains multiple files
	'files=s{1,}'=>\@files0,
);

my @files;
foreach my $f (@files0) {
	next if !-e $f or -z $f or -B $f;
	push @files, $f;
}
if ($sort) {
	@files=sort @files;
}

if ($help or !@files) { die <<USAGE;
-------------------------
# merge 2 or more cue files into one single file
# ideally for albums with 2 or more disks

[-f CUE1 CUE2 ...]
  files are supposed to belong to the same folder
[-o] order input files based by full path
  !! order is based on system, use with caution if a specific order is needed
[-w OUTPUT_CUE]
  merge mode only, does NOT work under split mode [-s]
-------------------------

USAGE
}

my $cue=CUEsmith->new;
foreach my $f (@files) {
	printf "\nreading : %s . . .\n", $f;
	if (!$split) { #merge all cue first, write merged data after this loop
		if (!$cue->title) { # first, no append
			$cue->read($f);
		} else {
			$cue->read($f,1);
		}
	}
	else { #split each input cue
		$cue->read($f);
		if ($cue->filenum >1) { #no splitting if only 1 file inside
			$cue->write(undef,1,1);
		} else {
			print "  >>only 1 audio file found, no output\n\n";
		}
	}
}

# to write combined cue data
if (!$split) {
	my $ofile=$files[0].'_merge.cue';
	if ($ofile1) {
		$ofile=$ofile1;
		if ($ofile!~/\.cue$/i) {
			$ofile.='.cue';
		}
		while (-e $ofile) {
			$ofile.='.cue';
		}
	}
	# die $ofile;
	open (my $fh, ">encoding(utf-8)", $ofile) or die "\n\ncan't write to output file\n";
	$cue->write($fh);
	printf "\n\n>>>output file wrote to: %s\n\n", $ofile;
}