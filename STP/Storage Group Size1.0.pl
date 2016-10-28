#!/usr/bin/perl
#
# SymmDiskSummary.pl
#
# This script pulls out disk info from symmapi_db.bin.
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
	open(API,"\"$symsgexe\" -sid $sym list -v|");
	while ($line=<API>) {
;
		chomp($line);
		$line=~s/ Mir/Mir/g;
		$line=~s/^\s+//;
		next if ($line =~ /(Dev.*Pdev.*Config.*Sts.*MB.*|Sym.*)/);
		if ($line =~ /^Name:/) {
			($label,$sgName)=split (/:/, $line);
			$sgName=~s/\s+//g;
		} elsif ($line =~ /Masking Views/) {
			($label,$maskingViews)=split (/:/, $line);
			$maskingViews=~s/\s+//g;
		}

		$capture=1 if $line =~ /\{/;
		$capture=0 if $line =~ /\}/;
	
#		if ($capture == 1 && $line =~/\s+[0-9A-z]+/ && $maskingViews eq "Yes") {
		if ($capture == 1 && $line =~/\s+[0-9A-z]+/ ) {
			($devName,$pdevName,$deviceConfig,$status,$capacityInMB)=split (/\s+/, $line);	
			$deviceToSg{$devName}=$sgName;
			$sgSize{$sym}{$sgName}+=$capacityInMB /1024;
		}
	
	}
	close(API);
}
print "Done.\n";

for $sym (keys %sgSize) {
	open(OUTFILE,">$sym-storageGroupSizes.csv") or die "Unable to create file $sym-storageGroupSize.csv\n";	
	print OUTFILE "Storage Group, Size(GB)\n";
	for $sg (keys %{$sgSize{$sym}} ) {
		print OUTFILE "$sg,$sgSize{$sym}{$sg}\n";
	}
	close(OUTFILE);
}


print "Done.\n";
