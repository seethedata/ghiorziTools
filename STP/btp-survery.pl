#!/usr/bin/perl
#
# btpsurvey.pl
#
# This script pulls out summary information from a 
# btp file.
######################################################


#######################################
# Confirm that STP tools are installed
#######################################
$stpexe="";
$progDirOld='C:\Program Files (x86)\EMC\STPTools';
$progDirNew='C:\Program Files\EMC\STPTools';
$exe="StpRpt.exe";
if ( -e $progDirNew . "\\" . $exe) {
	$stpexe=$progDirNew . "\\" . $exe;
} elsif (-e $progDirOld . "\\" . $exe) {
	$stpexe=$progDirOld . "\\" . $exe;
} else {

	die "$exe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}

$printLine="N";
opendir(DIR,".") or die "Unable to open current directory.";
while (readdir DIR) {
	if ($_ =~/.*\.btp$/) {
		chomp;
		$btpfile=$_;
		open(STP,"\"$stpexe\" -f \"$btpfile\" -std |");
		while(defined (my $line=<STP>) ) {
			if ($line =~ m/^System, Metric/ ) {
				$printLine="Y";
			}
			if ($printLine eq "Y" && $line =~ m/^$/) {
				last;
			}
			print "$line" if ($printLine eq "Y" && $line =~ m/(System, Metric|reads per sec|writes per sec|read hits per sec|write hits per sec|% reads|% writes|% hit)/);
		}
		close(STP);
	}
}
closedir(DIR);