#!/usr/bin/perl
#
# MergeBTP.pl
#
# This script merges BTP files in a directory.
######################################################

$mergeBTPexe="";

if ( -e 'C:\\Program Files\\EMC Corporation\\SymmMerge4\\BtpCutPasteCLI.exe') {
	$mergeBTPexe='C:\Program Files\EMC Corporation\SymmMerge4\BtpCutPasteCLI.exe ';
} elsif (-e 'C:\\Program Files(x86)\\EMC Corporation\\SymmMerge4\\BtpCutPasteCLI.exe') {
	$mergeBTPexe='C:\Program Files (x86)\EMC Corporation\SymmMerge4\BtpCutPasteCLI.exe ';
} else {
	die "BtpCutPasteCLI.exe is required, but is not found.\nLocations checked were:\nC:\\Program Files\\EMC Corporation\\SymmMerge4\\BtpCutPasteCLI.exe\nC:\\Program Files (x86)\\EMC Corporation\\SymmMerge4\\BtpCutPasteCLI.exe";
}


opendir(STPDIR,'.') or die "Unable to open local directory\n";
$stplist="";

$numberOfSTPFiles=0;
while (readdir STPDIR) {
	if ($_ =~ /.*\.btp$/ && $_ !~ /merge/) {
		$stplist= $stplist . " " . $_;
		$numberOfSTPFiles++;	
	}
}
closedir(STPDIR);

$outfile="merged.btp";

if ($numberOfSTPFiles > 0) {
	$command='"' . $mergeBTPexe . '" merge ' . $stplist . ' ' . $outfile;
	system($command);
}

