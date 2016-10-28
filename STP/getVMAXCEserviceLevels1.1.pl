#!/usr/bin/perl
#
# getVMAXCEserviceLevels.pl
#
# This script suggests VMAX CE service levels based on
# data in the a symapi_db.bin file and a btp file.
######################################################
use Statistics::Descriptive;

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

$metricsFile="metrics.txt";

open(METRICSFILE,">$metricsFile") or die "Unable to create file: $metricsFile.";	
print METRICSFILE "Devices::device name\n";
print METRICSFILE "Devices::total ios per sec\n";
close(METRICSFILE);

print "Reading device performance data...\n";
opendir(DIR,".") or die "Unable to open current directory.";
while (readdir DIR) {
	if ($_ =~/.*\.btp$/) {
		$printLine="N";
		$btpfile=$_;
		print "\tReading $btpfile...";
		open(STP,"\"$stpexe\" -f \"$btpfile\" -std -m $metricsFile|");
		while(defined (my $line=<STP>) ) {
			chomp($line);
			if ($line =~ m/^Devices, Metric/ ) {
				$printLine="Y";
				next;
			} elsif ($printLine eq "Y" && $line =~ m/^$/) {
				last;
			} elsif ($printLine eq "Y") {
				@lineData=split(/,/,$line);
				$lineSize=scalar(@lineData);
				$device=$lineData[0];
				$device=~s/^0x//;
				while (length($device) < 4) {
					$device="0" . $device;
				}

				if (defined ($deviceIOPS{$device})) {
					$deviceStat=$deviceIOPS{$device};
				} else {
					$deviceStat=Statistics::Descriptive::Full->new();
				}

				for ($i=2; $i < $lineSize; $i++) {
					$lineData[$i]=~s/\s//g;
					next if $lineData[$i] eq "N/A" or $lineData[$i] == -1;
					$deviceStat->add_data($lineData[$i]);
				}
				$deviceIOPS{$device}=$deviceStat;
			}
		}
		close(STP);
		print "Done.\n"
	}
}
print "Done.\n";
closedir(DIR);
unlink($metricsFile);


#######################################
# Confirm that Solutions Enabler is installed
#######################################

$progDirOld='C:\Program Files (x86)\EMC\SYMCLI\bin';
$progDirNew='C:\Program Files\EMC\SYMCLI\bin';
$diskexe="symdisk.exe";
$cfgexe="symcfg.exe";
$devexe="symdev.exe";
if ( -e $progDirNew . "\\" . $cfgexe) {
	$symdiskexe=$progDirNew . "\\" . $diskexe;
	$symcfgexe=$progDirNew . "\\" . $cfgexe;
	$symdevexe=$progDirNew . "\\" . $devexe;
} elsif (-e $progDirOld . "\\" . $cfgexe) {
	$symdiskexe=$progDirOld . "\\" . $diskexe;
	$symcfgexe=$progDirOld . "\\" . $cfgexe;
	$symdevexe=$progDirOld . "\\" . $devexe;
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

print "Reading device capacity data...";
for $sym (keys %sids) {
	open(OUTFILE,">$sym-serviceLevels.csv") or die "Unable to create $sym-serviceLevels.csv\n";
	print OUTFILE "Device,IOPS/GB,Diamond,Platinum,Gold,Silver,Bronze,Capacity(GB),Max IOPS,95th IOPS\n";
	open(API,"\"$symdevexe\" list -sid $sym -tdev -identity|") or die "No!";
	while($line=<API>) {
		chomp($line);
		$device=$line;
		$device=~s/\s.*//g;

		next if (! exists($deviceIOPS{$device}) );
		$sizeInMB=$line;

		$sizeInMB=~s/.*\s//g;
		$sizeInMB=~s/--/0/;

		next if $sizeInMB == 0;

		$sizeInGB=$sizeInMB / 1024;

		$deviceIOPSMax=$deviceIOPS{$device}->max() ;
		$deviceIOPS95th=$deviceIOPS{$device}->percentile(95) ;
		if ($sizeInGB > 0 && defined($deviceIOPS{$device})) {
			$IOPSPerGB = $deviceIOPSMax/$sizeInGB ;
		} else {
			$IOPSPerGB=0;
		}

		#######################################################################
		# Service Levels - highest in each class
		# 			Diamond	Platinum	Gold	Silver	Bronze
		# IOPS/GB		3.87	2.96		1.07	0.48	0.16
		# TB Increment		1.83	2.89		15.01	25.53	11.32
		#######################################################################

		$diamondIOPSPerGB=3.87;
		$platinumIOPSPerGB=2.96;
		$goldIOPSPerGB=1.07;
		$silverIOPSPerGB=0.48;
		$bronzeIOPSPerGB=0.16;

		$diamondTBIncrement=1.83;
		$platinumTBIncrement=2.89;
		$goldTBIncrement=15.01;
		$silverTBIncrement=25.53;
		$bronzeTBIncrement=11.32;

		$diamondCapacity+=$sizeInGB if $IOPSPerGB > $platinumIOPSPerGB;
		$platinumCapacity+=$sizeInGB if $IOPSPerGB > $goldIOPSPerGB and $IOPSPerGB <= $platinumIOPSPerGB;
		$goldCapacity+=$sizeInGB if $IOPSPerGB > $silverIOPSPerGB and $IOPSPerGB <= $goldIOPSPerGB;
		$silverCapacity+=$sizeInGB if $IOPSPerGB > $bronzeIOPSPerGB and $IOPSPerGB <= $silverIOPSPerGB;
		$bronzeCapacity+=$sizeInGB if $IOPSPerGB <= $bronzeIOPSPerGB;

		print OUTFILE "'$device,$IOPSPerGB,$diamondIOPSPerGB,$platinumIOPSPerGB,$goldIOPSPerGB,$silverIOPSPerGB,$bronzeIOPSPerGB,$sizeInGB,$deviceIOPSMax,$deviceIOPS95th\n";
	}
	close(API);

	$diamondCapacity=$diamondCapacity /1024 ;
	$platinumCapacity=$platinumCapacity /1024 ;
	$goldCapacity=$goldCapacity /1024 ;
	$silverCapacity=$silverCapacity /1024 ;
	$bronzeCapacity=$bronzeCapacity /1024 ;

	print OUTFILE "\n\n\n\n";
	print OUTFILE "Service Level,Capacity (TB),TB increment,# of Increments\n";
	print OUTFILE "Diamond-1,$diamondCapacity,$diamondTBIncrement," . $diamondCapacity  / $diamondTBIncrement . "\n";
	print OUTFILE "Platinum-3,$platinumCapacity,$platinumTBIncrement," . $platinumCapacity  / $platinumTBIncrement ."\n";
	print OUTFILE "Gold-4,$goldCapacity,$goldTBIncrement," . $goldCapacity / $goldTBIncrement . "\n";
	print OUTFILE "Silver-4,$silverCapacity,$silverTBIncrement," . $silverCapacity / $silverTBIncrement . "\n";
	print OUTFILE "Bronze-2,$bronzeCapacity,$bronzeTBIncrement," . $bronzeCapacity / $bronzeTBIncrement . "\n";

	close(OUTFILE);
}
print "Done.\n";