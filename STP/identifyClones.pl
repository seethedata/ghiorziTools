#!/usr/bin/perl
#
# identifyClones.pl
#
# This script lists the clone source/target relationship 
# for devices.
######################################################

use Statistics::Descriptive;
use Statistics::Descriptive::Weighted;

#######################################
# Confirm that Solutions Enabler is installed
#######################################
$stpexe="";
$progDirOld='C:\Program Files (x86)\EMC\SYMCLI\bin';
$progDirNew='C:\Program Files\EMC\SYMCLI\bin';
$diskexe="symdisk.exe";
$cfgexe="symcfg.exe";
$sgexe="symsg.exe";
$stprptexe="C:\\Program Files (x86)\\EMC\\STPTools\\StpRpt.exe";

if ( -e $progDirNew . "\\" . $exe) {
	$symdiskexe=$progDirNew . "\\" . $diskexe;
	$symcfgexe=$progDirNew . "\\" . $cfgexe;
	$symsgexe=$progDirNew . "\\" . $sgexe;
} elsif (-e $progDirOld . "\\" . $exe) {
	$symdiskexe=$progDirOld . "\\" . $diskexe;
	$symcfgexe=$progDirOld . "\\" . $cfgexe;
	$symsgexe=$progDirOld . "\\" . $sgexe;
} else {

	die "$exe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}

open(API,"\"$symcfgexe\" -version |");
while ($line=<API>) {
	chomp($line);
	if ($line =~ /Symmetrix CLI \(SYMCLI\) Version/) {
		$line=~s/^\s+/ /;
		($blank,$symmetrix,$cli,$symmcli, $ver, $colon,$version,$editlevel)=split (/\s+/, $line);
		$version=~s/V//;
		last;
	}

}
close(API);

$requiredVersion="7.4.0";

($requiredMajor,$requiredMinor,$other)=split (/\./,$requiredVersion);

($major,$minor,$other)=split /\./,$version;


if ($major < $requiredMajor || ($major == $requiredMajor && $minor < $requiredMinor) ) {
	print"SYMCLI version $version installed. Version $requiredVersion required.\n";
	system("pause");
	die;
}

$ENV{"SYMCLI_OFFLINE"}=1;
$ENV{"SYMCLI_DB_FILE"}="symapi_db.bin";

open(API,"\"$symcfgexe\" list |");
while ($line=<API>) {
	chomp($line);
	$line=~s/^\s+//;
	if ($line =~ /(DMX|VMAX)/) {
		($sid,$attach,$model,$mcode,$cache,$devs,$symdevs)=split (/\s+/, $line);
		$sids{$sid}=$model;
	}
}
close(API);

print "Reading configuration data...";
for $sym (keys %sids) {
	$capture=0;
	open(API,"\"$symcfg\" -sid $sym list -v|");
	while ($line=<API>) {
		chomp($line);
		next if ($line =~ /N\/A/);
		if ($line =~ /Source (SRC) Device Symmetrix Name/) {
			($label,$sourceDev)=split (/:/, $line);
			$sourceDev=~s/\s+//g;
		} elsif ($line =~ /Target (TGT) Device Symmetrix Name/) {
			($label,$targetDev)=split (/:/, $line);
			$targetDev=~s/\s+//g;
			$cloneMapping{$targetDev}=$sourceDev
		}
	}
	close(API);

	open(OUTFILE,">$sym-cloneMapping.csv") or die "Unable to create file $sym-cloneMapping.csv\n";	
	print OUTFILE "Source, Target\n";

	for $dev (keys %cloneMapping) {
		print OUTFILE "$cloneMapping{$dev},$dev\n";
	}
	close(OUTFILE);
}
print "Done.\n";

