#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use File::Spec;
use Storable qw/:DEFAULT dclone/;
use Data::Dumper;

# make sure the module is in same dir as the script. and before running, always go to the dir where this scripts stays so that it can finds the module.
use lib ".";
use CUEsmith;

# read/write cue files
# required module PARSE_Cue.pm has to be in the same dir as this script.
# 2014-7-2
# last update: 2020 aug 5

my (@files0,$help,$flist);
my (@indir,$csv,$force);
GetOptions(
	'dir=s{1,}'=>\@indir,
	'help'=>\$help,
	'screen'=>\$force,
	'files=s{1,}'=>\@files0,
	'list=s'=>\$flist, #list of cue paths
	'import=s'=>\$csv,
);

my @files;
if (@files0) {
	foreach my $file (@files0) {
		push @files, $file if (-e $file and !-d $file);
	}
}
if ($flist and -e $flist) {
	open (my $fh, $flist);
	while (<$fh>) {
		next if /^\s*$/;
		chomp;
		push @files, $_ if -e $_;
	}
}
if (@indir) {
	foreach my $indir (@indir) {
		next if !-d $indir;
		opendir (my $dh, $indir);
		use File::Spec;
		while (my $f=readdir $dh) {
			push @files, File::Spec->catfile($indir,$f) if $f=~/\.cue$/i;
		}
	}
}
if ($help or !@files) { die <<USAGE;
-------------------------
# read in files. use AT LEAST ONE of below:
[-f CUE1 CUE2 ...]
[-d INPUT_DIR1 2 3...] #fetch *.cue in each dir, do NOT process subdir
[-l PATHLIST] # list of cue paths. one path per line. will open as ANSI plain file

# force cue file output to screen instead of files
[-s]

# match external tracklist file into input cue's
[-i FORMATTED_TRACK_INFO]
# UTF-8 encoded WITHOUT bom.
# use "#" at begining of line for comment
# use "ARTIST/TITLE/FILE: XXXX" to specify album info.
# use TrackNo<TAB>Track Title<TAB>Artist" to specify track info
# TrackNo is used for reference, actual order will be assigned automatically
# use "//" to separate different albums.
# order of given files MUST match the list file, or you'll be screwed up
# ideally for one-disk-cue, not tested for multiple-file cue

# if [-i] isn't given, will output unified cue file in UTF-8-BOM.

-------------------------

USAGE
}

if (!$csv or !-e $csv) { #write utf8-bom cue file
	foreach my $file (@files) {
		my $cue=CUEsmith->new($file);
		printf "%s\n",$file;
		my $fh;
		my $ofile;
		if (!$force) {
			$ofile=$cue->path.'_unify.cue';
			open ($fh, ">:encoding(utf-8)", $ofile);
		} else {
			$fh=*STDOUT;
		}
		$cue->write($fh);
		printf "  >output: %s\n", $ofile;
	}
	exit;
}

#proceed rename file index
open (my $fh, "<:encoding(utf-8)",$csv);
my $index;
my $curr;
my $curr_file;
while (<$fh>) {
	chomp;
	next if /^\s*$/; #skip empty line
	next if /^\s*#$/; #skip comment line
	# next if /^\W$/;
	if (m{^\s*//\s*$}) { # cue separator
		if ($curr_file) { #push current file block to current cue block
			push @{$curr->{files}}, dclone $curr_file;
			$curr_file=undef;
		}
		if ($curr) {
			push @$index, dclone $curr;
			$curr=undef;
		}
	}
	elsif (/^\s*TITLE:\s*(.+)$/) {
		$curr->{title}=$1;
	}
	elsif (/^\s*ARTIST:\s*(.+)$/) {
		$curr->{artist}=$1;
	}
	elsif (/^\s*FILE:.*?(\S+)\s*$/) { # file name should NOT have any empty space.  in case line contains other info.
		if ($curr_file) {
			push @{$curr->{files}}, dclone $curr_file;
			$curr_file=undef;
		}
		push @{$curr_file},$1;
	}
	else {
		my @col=split /\t/;
		if (@col<2) { # a track line should have at least 2 elements: <track no> \t <track title>
			next;
		}
		# die Dumper \@col;
		# die Dumper $curr,$curr_file;
		push @$curr_file,{ title=>$col[1], artist=>($col[2]||'') };
	}
}
if ($curr_file) {
	push @{$curr->{files}}, dclone $curr_file;
}
if ($curr) {
	push @$index, dclone $curr;
}

if ( ( scalar @$index ) != scalar @files) {
	print STDERR "unequal number of indexed files and given input cue files\n";
	print STDERR "multi-file cues may cause this problem, better to first map single file cue and merge later.\n";
	printf STDERR "indexed cue blocks = %s\n", scalar @$index;
	printf STDERR "input cue files = %s\n" , scalar @files;
	exit;
}
foreach my $file (@files) {
	printf "\n%s . . .\n", $file;
	my $idx = shift @{$index};
	# die Dumper $idx;
	my $cue=CUEsmith->new($file);
	# die Dumper $cue;
	if ($cue->filenum != (scalar @{$idx->{files}})) {
		print STDERR "unequal number of tracks in at least one file block, skipped\n";
		next;
	}

	$cue->alter({artist=>$idx->{artist}, title=>$idx->{title}});
	for my $fid (1..$cue->filenum) {
		$cue->alter({file=>$idx->{files}[$fid-1][0]}, $fid);
		for my $tr (1..$cue->tracknum($fid)) {
			# die Dumper $idx->{files}[$fid-1][$tr];
			# print Dumper $cue->{files}[$fid]{$tr};
			my $trdata=$idx->{files}[$fid-1][$tr];
			$cue->alter({artist=>$trdata->{artist}, title=>$trdata->{title}}, $fid, $tr);
			# print Dumper $cue->{files}[$fid]{$tr};
		}
	}
	my $ofile=$cue->path.'__remap.cue';
	# die Dumper $cue;
	open (my $fh2, ">:encoding(UTF-8)", $ofile);
	$cue->write($fh2);
	printf "   >>%s\n\n",$ofile;
}

# $cue->write(($force?undef:$cue->{0}{path})) if $cue; #last
