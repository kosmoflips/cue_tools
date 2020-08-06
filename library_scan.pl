#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Temp;
use Getopt::Long;
use Data::Dumper;

use lib ".";
use CUEsmith;

# read given dir and sub-dir, list all cue files.

# only works on windows OS

# [to be added] features: find all audio files, and list those not in cue


my ($indir,$help,$outfile,@infiles);
GetOptions(
	"dir=s"=>\$indir,
	"files=s{1,}"=>\@infiles,
	"help"=>\$help,
	"outfile=s"=>\$outfile,
);
if ($help or (!$indir and !@infiles) or ($indir and !-d $indir)) {die <<USAGE;
-----------------------------------------
# give either [-f] or [-d]
# if both are given, will only process [-f]
[-f CUE1 CUE2 ...] input individual cue files
[-d ROOT_DIR] input dir, ideally the root of music folder


*[-o] output file path, optional.
    if not given, will output under [-i]
-----------------------------------------

USAGE
}

my $fh;
{
	if (!$outfile) {
		if (@infiles) {
			$outfile=$infiles[0].'_tracklist.txt';
		}
		elsif ($indir) {
			$outfile=File::Spec->catfile($indir,'musiclib_'.time.'.txt');
		}
	}
	eval {
		open ($fh, ">:utf8", $outfile);
	};
	if ($@) {
		die "can't open OUTFILE";
	}
}

if ($indir) {
	my $time=localtime(time);
	printf $fh
"# music library archive
# generated on %s
# rootdir: %s
//
", $time,$indir;
}

#music lib cue files are supposed to use ascii standard chars only, so dont worry about en/de-code

if (@infiles) {
	foreach my $f (@infiles) {
		printf "%s . . .\n", $f;
		my $cue=CUEsmith->new($f);
		$cue->write_list($fh);
		print $fh "//\n";
	}

	printf "\n\n>>output tracklist written to: %s\n", $outfile;
	exit;
}

my $fh2 = File::Temp->new();
my $list=$fh2->filename;
close ($fh2);
print "\nparsing subdir. . .\n";
my $cmd=sprintf 'dir %s\*.cue /b /s >%s', $indir,$list;
# my $cmd=sprintf 'dir %s /b /s >%s', $indir,$list;

my $muf=$CUEsmith::AUDIO_FORMAT;
system ($cmd);
print "\n\n";
open (my $fh3, $list);
my $skip;
while (<$fh3>) {
	chomp;
	next if /^\.+$/;
	next if -d $_;
	# next if $skip->{$_};
	if (/\.cue$/i) {
		printf "%s\n",$_;
		my $cue=CUEsmith->new($_);
		$cue->write_list($fh);
		print $fh "//\n";
		# $skip->{$cue->full_path}=1;
	} else {
		next if -T $_;
		#planning to also include non-cue audio files, but too hard to work on. drop this idea for now
	}
}

printf "\n\n>>>all done. outfile: %s\n", $outfile;