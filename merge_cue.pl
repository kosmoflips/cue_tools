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

my (@files0,@dirs0,$help, $sort_by_name);
GetOptions(
	'help'=>\$help,
	'sort'=>\$sort_by_name,
	'files=s{1,}'=>\@files0,
	'dirs=s{1,}'=>\@dirs0,
);

my @files; # merge all individually given files
foreach my $f (@files0) {
	next if !-e $f or -z $f or -B $f;
	push @files, $f;
}

if ($help or (!@files and !@dirs0)) { die <<USAGE;
-------------------------
# merge 2 or more cue files into one single file
# ideally for albums with 2 or more disks

--- required ---
* specify at least one of [-f] and [-d]
[-f CUE1 CUE2 ...] all cues should belong to the same folder
[-d DIR1 DIR2 ...] will generate a merged cue file for all cues under each dir

--- optional ---
[-s] sort all cue files by name

!! output file will be named as "_merge.CURRENTFILE.cue", and thus, the filex including "merge." in file name will be automatically ignored for further merging!!

-------------------------

USAGE
}

if (@files) {
	print "--- combining given cue files ---\n";
	my $cue=CUEsmith->new;
	foreach my $f (@files) {
		printf "  - %s . . .\n", $f;
		next if is_merged_cue($f,1);
		if (!$cue->title) { # first, no append
			$cue->read($f);
		} else {
			$cue->read($f,1);
		}
	}

	# write combined cue data
	my $ofile=mk_merged_cue_name($files[0]);
	open (my $fh, ">encoding(utf-8)", $ofile) or die "\n\ncan't write to output file\n";
	$cue->write($fh);
	printf "\n\n>>>output file wrote to: %s\n\n", $ofile;
}
if (@dirs0) {
	print "--- combining cue under each of given directories ---\n";
	foreach my $dir (@dirs0) {
		next if !-d $dir;
		printf "\n- %s . . .\n", $dir;

		my $cuelist=CUEsmith::get_cue_from_dir($dir, $sort_by_name, 1);
		if (!$cuelist) {
			print "  there're no cue files under given folder, skip!\n";
			next;
		}
		my $cue=CUEsmith->new;
		foreach my $cuefile (@$cuelist) { # each line has a cue file path under current dir
			printf "  - %s\n", $cuefile;
			next if is_merged_cue($cuefile,1);
			my $fullpath=File::Spec->catfile($dir, $cuefile);
			if (!$cue->title) { # first, no append
				$cue->read($fullpath);
			} else {
				$cue->read($fullpath,1);
			}
		}

		my $ofile2=File::Spec->catfile($dir, '_merged.allcues.cue');
		open (my $fh2, ">encoding(utf-8)", $ofile2) or die "\n\ncan't write to output file\n";
		$cue->write($fh2);
		printf "\n>>>output file wrote to: %s\n\n", $ofile2;
	}
}


sub mk_merged_cue_name { # from dir1/file.cue to dir1/merge.file.cue
	my ($basefile, $dirmode)=@_; # dirmode : input path is dir.
	my @x=File::Spec->splitdir($basefile);
	my $y='';
	if ($dirmode) {
		while (@x) {
			my $y1=pop @x;
			if ($y1) {
				$y=$y1;
				push @x, $y;
				last;
			}
		}
	} else {
		$y=pop @x;
	}
	my $z='_merge.';
	if ($y!~/\.cue$/i) { # in case this is a folder
		$z.=$y.'.cue';
	} else {
		$z.=$y;
	}
	return File::Spec->catfile(@x, $z);
}
sub is_merged_cue {
	my ($f, $printinfo)=@_;
	my @x=File::Spec->splitpath($f);
	my $fname=$x[-1];
	if ($f=~/^_merge\.\w+\.cue/i) {
		if ($printinfo) {
			print "    looks like it's a previously merged file, skip\n";
		}
		return 1;
	} else {
		return 0;
	}
}