#!/usr/bin/perl
#
# ttp2btp.pl
#
# This script converts all TTP files to BTP files
# in a directory.
######################################################

$progDirOld='C:\Program Files (x86)\EMC\STPTools';
$progDirNew='C:\Program Files\EMC\STPTools';
$exe="StpTtpCnv.exe";
$ttp2stpexe="";
if ( -e $progDirNew . "\\" . $exe) {
	$ttp2stpexe=$progDirNew . "\\" . $exe;
} elsif (-e $progDirOld . "\\" . $exe) {
	$ttp2stpexe=$progDirOld . "\\" . $exe;
} else {

	die "$exe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}


opendir(STPDIR,'.') or die "Unable to open local directory\n";

$numberOfSTPFiles=0;
while (readdir STPDIR) {
	if ($_ =~ /.*\.ttp$/ ) {
		chomp;
		$ttpfile=$_;
		$command='"' . $ttp2stpexe . '" -f ' . $ttpfile;
		system($command); 
		$numberOfSTPFiles++;	
	}
}

closedir(STPDIR);
print "Converted $numberOfSTPFiles TTP files to BTP.\n";
