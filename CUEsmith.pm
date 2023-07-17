package CUEsmith;
use strict;
use warnings;
use File::Spec;
use Data::Dumper;
use Storable qw/:DEFAULT dclone/;
use utf8;

# deals with cue files
# originally PARSE_Cue , created: 2014-1-30
# remoduled on 2020 Aug 5
# note: as I don't use REM tag, it's not tested here

my $BOM=chr(65279);

our $AUDIO_FORMAT={
	flac=>1,
	ape=>1,
	wav=>1,
	tta=>1,
	mp3=>1,
	m4a=>1,
	ogg=>1,
};

my $ALBUM={ #valid keys
	path => 1, #full cue path
	artist => 1,
	title => 1,
	rem=>1,
};
my $TRLIST={
	file=>1,
	title => 1,
	artist => 1,
	index00 =>1,
	index01 =>1,
	rem=>1,
};

sub new { # {0} for $ALBUM, {1,2,3...} for $TRLIST
	my ($class,$file)=@_;
	my $cue= bless {},$class;
	$cue->read($file) if $file;
	return $cue;
}
sub read { #read from external cue file. open as UTF-8(+BOM) ONLY
	my ($cue,$file,$append)=@_; # use_given_path: abs or rel path for current cue. useful if dealing with subdirs
	# print Dumper $cue->{album};<>;
	if (!$file or !-e $file or -z $file or -B $file) {
		return undef;
	}

	my $chkbom=0;
	my $infileblock=0;
	my $album;
	my $files=[undef]; # data [0] is empty. so files will start at index 1
	my $tr=0;

	my $currfile;
	$album->{path}=$file; #full cue path
	open (my $fh, "<:encoding(utf-8)",$file);
	# open (my $fh, "<",$file);
	while (<$fh>) {
		# print $_;<>;
		chomp;
		if ($chkbom==0) {
			if (/^$BOM/) {
				$_=~s/^$BOM//;
			}
			$chkbom=1; #this must be assigned at the first line
		}

		# album block
		if (/^TITLE "(.*)"/i) {
			$album->{title}=$1;
		}
		elsif (/^PERFORMER "(.*)"/i) {
			$album->{artist}=$1;
		}
		elsif (/^REM\s+/i) {
			push @{$album->{rem}}, $';
		}
		#enter file block for tracklist
		elsif (/^FILE "(.+)" \w+/) {
			if ($currfile) {
				push @$files, dclone $currfile;
				$currfile=undef;
			}
			$currfile->{0}=$1;
			$infileblock=1;
			$tr=0; #reset track number in file
		}
		elsif ($infileblock) {
			if (/TRACK\s+\d+\s+AUDIO/) {
				$tr++;
			}
			elsif (/^\s+TITLE "(.*)"/i) {
				$currfile->{$tr}{title}=$1;
			}
			elsif (/^\s+PERFORMER "(.+)"/i) {
				$currfile->{$tr}{artist}=$1;
			}
			elsif (/^\s+REM\s+/i) {
				push @{$currfile->{$tr}{rem}},$';
			}
			elsif (/^\s+INDEX 00 (\S+)/) {
				$currfile->{$tr}{index00}=$1;
			}
			elsif (/^\s+INDEX 01 (\S+)/) {
				$currfile->{$tr}{index01}=$1;
			}
		}
	}
	if ($currfile) {
		push @$files, dclone $currfile;
	}
	if (!$append) { #new file
		$cue->{album}=dclone $album;
		$cue->{files}=dclone $files;
	} else { #append new cue, do NOT add album info
		shift @$files; #remove element [0] undef
		push @{$cue->{files}}, @$files;
	}
	$cue->unify;
	1;
}
sub unify {
	my $cue=shift;
	$cue->_unify_album;
	$cue->_unify_files;
}
sub _unify_files {
	my $cue=shift;
	for my $fid (1..$cue->filenum) {
		if (!$cue->file($fid)) {
			$cue->{files}[$fid]{0}='CDImage.flac';
		}
		for my $tr (1..$cue->tracknum($fid)) {
			if ($cue->artist($fid, $tr) and $cue->artist($fid, $tr) eq $cue->artist) {#remove artist if the same as album's
				delete $cue->{files}[$fid]{$tr}{artist};
			}
			foreach my $key (qw/title artist/) {
				if ($cue->{files}[$fid]{$tr}{$key}) {
					$cue->{files}[$fid]{$tr}{$key}=clean_text($cue->{files}[$fid]{$tr}{$key});
				}
			}
		}
	}
}
sub _unify_album {
	my $cue=shift;
	if (!$cue->title) {
		$cue->alter({title=>'UNKNOWN'});
	} else {
		$cue->{album}{title}=clean_text($cue->{album}{title});
	}

	if (!$cue->artist) {
		$cue->alter({artist=>'UNKNOWN'});
	} else {
		$cue->{album}{artist}=clean_text($cue->{album}{artist});
	}
}

# view/change hash info
sub totaltr { #of all files
	my $cue=shift;
	my $n=0;
	foreach my $fid (1..$cue->filenum) {
		$n+=$cue->tracknum($fid);
	}
	return $n;
}
sub title {
	my ($cue,$fileid,$tr)=@_;
	if ($fileid and $tr) {
		return $cue->{files}[$fileid]{$tr}{title}||'';
	}
	else {
		return $cue->{album}{title}||'';
	}
}
sub artist {
	my ($cue,$file,$tr)=@_;
	if ($file and $tr) {
		return $cue->{files}[$file]{$tr}{artist}||'';
	}
	else {
		return $cue->{album}{artist};
	}
}
sub path {
	my $cue=shift;
	return $cue->{album}{path}||'';
}
sub file { #file name
	my ($cue,$fid)=@_;
	return $cue->{files}[$fid]{0}||'';
}
sub rem {
	my ($cue, $fileid, $tr)=@_;
	if ($fileid and $tr) {
		return $cue->{files}[$fileid]{$tr}{rem}||[];
	} else {
		return $cue->{album}{rem}||[];
	}
}
sub index {
	my ($cue, $fid, $tr, $idx)=@_;
	return $cue->{files}[$fid]{$tr}{$idx?'index01':'index00'}||'';
}
sub tracknum { #give file-index, return number of file
	my ($cue, $fid)=@_;
	$fid=1 if !$fid;
	return ((scalar keys %{$cue->{files}[$fid]})-1); #-1 to avoid index [0]
}
sub filenum { #of audio files
	my $cue=shift;
	return (scalar @{$cue->{files}}-1); #-1 to avoid index [0]
}
sub alter { #album info OR track info if $tr is given // to remove the value, input white space
	my ($cue,$alter,$file,$tr)=@_; #self, H ref
	foreach (keys %$alter) {
		if ($_ eq 'file' and $file) {
			$cue->{files}[$file]{0}=$alter->{$_};
			next;
		}
		if ($file and $tr and $TRLIST->{$_}) {
			$cue->{files}[$file]{$tr}{$_} = $alter->{$_} if $TRLIST->{$_};
		} else {
			$cue->{album}{$_} = $alter->{$_} if $ALBUM->{$_}; #otherwise do nothing
		}
	}
	1;
}


#write sum list, plain text
sub write_list {
	my ($cue,$fh)=@_;
	if (!$fh) {
		$fh=*STDOUT;
	}
	$cue->_write_list_header($fh);
	$cue->_write_list_files($fh);
}
sub _write_list_header {
	my ($cue,$fh)=@_;
	printf $fh "PATH: %s\n", $cue->path;
	printf $fh "TITLE: %s\n", $cue->title;
	printf $fh "ARTIST: %s\n", $cue->artist;
}
sub _write_list_files {
	my ($cue,$fh)=@_;
	my $ctr=0;
	foreach my $fid (1..$cue->filenum) { #loop audio files
		printf $fh "FILE: [%d/%d] %s\n", $fid, $cue->filenum, $cue->file($fid);
		foreach my $tr (1..$cue->tracknum($fid)) {
			printf $fh "%02d\t%s%s\n",
				$tr,
				$cue->title($fid, $tr),
				$cue->artist($fid, $tr)?"\t".$cue->artist($fid, $tr):'';
		}
		$ctr+=$cue->tracknum($fid);
	}
}

#write to cue files. force to be UTF8 with bom
sub write { #NOT split
	my ($cue,$fh, $split,$verbose)=@_;
	if ($cue->filenum==1 or !$split) { # $split not given OR contains only 1 audio file
		$fh=*STDOUT if !$fh;
		$cue->_write_cue_header($fh);
		$cue->_write_cue_fileblock($fh);
	} else { # will NOT write to specified fh.
		close ($fh) if $fh;
		foreach my $fid (1..$cue->filenum) {
			my $odir=$cue->_mk_odir_split;
			my $ofile=File::Spec->catfile($odir, $cue->file($fid).'.cue');
			if ($verbose) {
				printf "  write sub-file to: %s\n", $ofile;
			}
			open (my $fh2, ">:encoding(UTF-8)", $ofile) or return undef;
			$cue->_write_cue_header($fh2);
			$cue->_write_cue_fileblock($fh2, $fid);
		}
	}
}
sub _mk_odir_split {
	my $cue=shift;
	my @c=File::Spec->splitpath($cue->path);
	pop @c;
	return File::Spec->catdir(@c);
}
sub _write_cue_header {
	my ($cue, $fh)=@_;
	printf $fh "%s",$BOM; #chr(65279); #force everything out to be utf-8
	printf $fh 'PERFORMER "%s"%s',$cue->artist,"\n";
	printf $fh 'TITLE "%s"%s',$cue->title,"\n";
	if ($cue->rem) {
		foreach my $line (@{$cue->rem}) {
			# die $line;
			printf $fh "REM %s\n", $line;
		}
	}
}
sub _write_cue_fileblock { #will write all files or specified file
	my ($cue, $fh, $fid_only)=@_; #fid is used when writing only 1 file's data
	my $ctr=0; # current  track number
	foreach my $fid (1..$cue->filenum) {
		# printf "fid=%s  need fid %s\n", $fid, $fid_only;
		if ($fid_only) {
			next if $fid_only!=$fid;
		}
		printf $fh 'FILE "%s" WAVE%s',$cue->file($fid),"\n";
		$cue->_write_cue_tracklist($fh, $fid, $ctr);
		if (!$fid_only) { #only adjust wirting track number when writing all files
			$ctr+=$cue->tracknum($fid);
		}
	}
}
sub _write_cue_tracklist {
	my ($cue, $fh, $fid, $prev_tr)=@_;
	for my $tr (1..$cue->tracknum($fid)) {
		# die Dumper $cue->{files}[$fid];
		printf $fh "  TRACK %02d AUDIO%s", ($tr+$prev_tr),"\n";
		printf $fh '    TITLE "%s"%s',$cue->title($fid, $tr),"\n";
		printf $fh '    PERFORMER "%s"%s',$cue->artist($fid, $tr),"\n" if $cue->artist($fid, $tr);
		printf $fh "    INDEX 00 %s%s",$cue->index($fid, $tr, 0),"\n" if $cue->index($fid,$tr,0);
		printf $fh "    INDEX 01 %s%s",$cue->index($fid,$tr,1),"\n" if $cue->index($fid,$tr,1);
		if ($cue->rem($fid,$tr)) {
			foreach my $line (@{$cue->rem($fid,$tr)}) {
				printf $fh "    REM %s\n", $line;
			}
		}
	}
}
=pod

#change hash data
sub transfer_time_to { #transfer 1st cue's time index, map into 2nd cue's tr info
	my ($cue,$cue2)=@_;
	if ($cue->totaltr==$cue2->totaltr) {
		#copy header
		$cue->alter($cue2->{0});
		#copy list
		for my $tr (1..$cue->totaltr) {
			$cue->alter_track($tr,$cue2->{$tr});
		}
		1;
	} else {
		warn "\n!!the two cue files don't have equal track numbers. can't proceed.\n";
		0;
	}
}


=cut


# standalone subs
sub clean_text { #non OO
	my $txt=shift;
	$txt=~s/"/”/g;
	$txt=~s/^\s+|\s+$//g;
	return $txt;
}
sub sort_cue_by_name { # sort cue files by file name only, as it's common that input cue file is a full path
	my ($cuelist, $basedir, $sort_by_name)=@_; # A ref. if sort_by_name is 0, will not sort. returned value will be relative dir to input dir
	my $fnames;
	my $ds1;
	foreach my $file (@$cuelist) {
		next if !-e $file;
		my @ds=File::Spec->splitpath($file);
		my $dir=File::Spec->catdir($ds[0], $ds[1]);
		$dir=File::Spec->abs2rel($file, $basedir);
		my $cue=$ds[2];
		$fnames->{$cue}=$dir;
		push @$ds1, $dir;
	}
	if (!$sort_by_name) {
		return $ds1;
	} else {
		my $ds2;
		for my $cue (sort {$a cmp $b} keys %$fnames) {
			push @$ds2, $fnames->{$cue};
		}
		return $ds2;
	}
}
sub get_cue_from_dir { # get *.cue from all subdirs, return A ref
	my ($dir, $sort_by_name, $current_level_only)=@_;
	my $cmd0=sprintf 'dir %s\*.cue /b', $dir; # hold all cue files into this txt file
	if (!$current_level_only) {
		$cmd0.=' /s'; # also look in subdirs
	}
	my $x=`$cmd0`; # shouldn't be slow, assuming the input dir only contain a decent amount of subfolders
	my @infiles=split "\r?\n", $x;
	my $cuelist=sort_cue_by_name(\@infiles, $dir, $sort_by_name);
	return $cuelist;
}

1;