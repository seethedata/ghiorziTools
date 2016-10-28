#!/usr/bin/perl
#
# nar2ttp.pl
#
# This script converts NAR files to TTP files.
######################################################



###################################
# Confirm that naviseccli and
# nazdecrypt are installed.
###################################
$progDirOld='C:\Program Files (x86)\EMC\Navisphere CLI';
$progDirNew='C:\Program Files\EMC\Navisphere CLI';
$exe="NaviSECCli.exe"
$naviCLI="";
if ( -e $progDirNew . "\\" . $exe) {
	$naviCLI=$progDirNew . "\\" . $exe;
} elsif (-e $progDirOld . "\\" . $exe) {
	$naviCLI=$progDirOld . "\\" . $exe;
} else {

	die "$exe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}

$progDirOld='C:\Program Files (x86)\AnalyzerDecryptionUtility';
$progDirNew='C:\Program Files\EMC\AnalyzerDecryptionUtility';
$exe="nazdecrypt.exe"
$decrypt="";
if ( -e $progDirNew . "\\" . $exe) {
	$decrypt=$progDirNew . "\\" . $exe;
} elsif (-e $progDirOld . "\\" . $exe) {
	$decrypt=$progDirOld . "\\" . $exe;
} else {

	die "$exe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}

###################################
# Check to see if there are *.naz
# files that need to be decrypted.
###################################
opendir(NARDIR, '.' ) or die "Unable to open local directory\n";

print "Checking for encrypted *.naz files...\n";
while (readdir NARDIR) {
	if ($_ =~/.*\.naz$/) {
		$result=system('"' . $decrypt . '" ' . $_ . " " . $_ . ".nar");
	}
}

closedir(NARDIR);

###################################
# Process NAR files.
###################################

opendir(NARDIR,'.') or die "Unable to open local directory\n";

while (readdir NARDIR) {
	if ($_ =~ /.*\.nar$/ && $_ !~ /merge/) {
		$narfiles[$numberOfNARFiles]=$_;
		$numberOfNARFiles++;	
	}
}
closedir(NARDIR);

