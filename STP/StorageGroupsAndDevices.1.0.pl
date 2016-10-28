#!/usr/bin/perl
#
# StorageGroupsAndDevices.pl
#
# This script analyzes the configuration in a bin file
# and creates a csv file with the storage groups and
# their devices
######################################################


#######################################
# Confirm that Solutions Enabler is installed
#######################################

$progDirOld='C:\Program Files (x86)';
$progDirNew='C:\Program Files';
$seDir="EMC\\SYMCLI\\bin";
$diskexe="$seDir\\symdisk.exe";
$cfgexe="$seDir\\symcfg.exe";
$sgexe="$seDir\\symsg.exe";

if ( -e $progDirNew . "\\" . $diskexe) {
	$symdiskexe=$progDirNew . "\\" . $diskexe;
} elsif (-e $progDirOld . "\\" . $diskexe) {
	$symdiskexe=$progDirOld . "\\" . $diskexe;
} else {

	die "$diskexe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}


if ( -e $progDirNew . "\\" . $cfgexe) {
	$symcfgexe=$progDirNew . "\\" . $cfgexe;
} elsif (-e $progDirOld . "\\" . $cfgexe) {
	$symcfgexe=$progDirOld . "\\" . $cfgexe;
} else {

	die "$cfgexe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}

if ( -e $progDirNew . "\\" . $sgexe) {
	$symsgexe=$progDirNew . "\\" . $sgexe;
} elsif (-e $progDirOld . "\\" . $sgexe) {
	$symsgexe=$progDirOld . "\\" . $sgexe;
} else {

	die "$sgexe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
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
$binFile="";
$ENV{"SYMCLI_OFFLINE"}=1;
opendir(BINDIR,'.') or die "Unable to open local directory\n";
while (readdir BINDIR) {
	if ($_ =~ /.*\.bin$/) {
		$binFile=$_;
		last;
	}
} 

die "No bin file found\n" if ($binFile eq "");
$ENV{"SYMCLI_DB_FILE"}=$binFile;

print "SymDB file found: $binFile.\n";

open(API,"\"$symcfgexe\" list |");
$numberOfArrays=0;
while ($line=<API>) {
	chomp($line);
	$line=~s/^\s+//;
	if ($line =~ /(DMX|VMAX)/) {
		$numberOfArrays++;
		($sid,$attach,$model,$mcode,$cache,$devs,$symdevs)=split (/\s+/, $line);
		$sids[$numberOfArrays]=$sid;
	}
}
close(API);

for ($i=1;$i < $numberOfArrays + 1; $i++) {
	$symId=$sids[$i];
	print "Reading configuration data for $symId from file $binFile...";
	$capture=0;
	open(API,"\"$symsgexe\" -sid $symId list -v|");
	while ($line=<API>) {
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
	
		if ($capture == 1 && $line =~/\s+[0-9A-z]+/ ) {
			($devName,$pdevName,$deviceConfig,$status,$capacityInMB)=split (/\s+/, $line);	
			while (length($devName) < 4) {
				$devName= "0" . $devName;
			}
			$storageGroupToDevice{$sgName}{$devName}=$capacityInMB /1024;
			$sgSize{$sgName}+=$capacityInMB /1024;
			$sgMasked{$sgName}=$maskingViews;
		}
	
	}
	close(API);


	print "Done.\n";

	open (OUTFILE,">$symId-storageGroups.csv") or die "Unable to write to $symId-storageGroups.csv.";
	for $sg (keys %storageGroupToDevice) {
		for $dev (keys %{$storageGroupToDevice{$sg}}) {
			print OUTFILE "$sg,0x$dev,$symId\n";
		}
	}
	close(OUTFILE);
}	
system("pause");