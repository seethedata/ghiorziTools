#!/usr/bin/perl
#
# NAR Analysis.pl
#
# This script dumps performance data from NAR files into
# a set of CSV files.
######################################################
use Config;

$Config{useithreads} or die('Recompile Perl with threads to run this program.');

#######################################
# Confirm that naviseccli is installed.
#######################################
$naviCLI="";
$progDirOld='C:\Program Files (x86)\EMC\Navisphere CLI';
$progDirNew='C:\Program Files\EMC\Navisphere CLI';
$exe="NaviSECCli.exe";
if ( -e $progDirNew . "\\" . $exe) {
	$naviCLI=$progDirNew . "\\" . $exe;
} elsif (-e $progDirOld . "\\" . $exe) {
	$naviCLI=$progDirOld . "\\" . $exe;
} else {

	die "$exe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}

#######################################
# Confirm that nazdecrypt is installed.
#######################################
$decrypt="";
$progDirOld='C:\Program Files (x86)\AnalyzerDecryptionUtility';
$progDirNew='C:\Program Files\AnalyzerDecryptionUtility';

$exe="nazdecrypt.exe";
if ( -e $progDirNew . "\\" . $exe) {
	$decrypt=$progDirNew . "\\" . $exe;
} elsif (-e $progDirOld . "\\" . $exe) {
	$decrypt=$progDirOld . "\\" . $exe;
} else {

	die "$exe is required, but is not found.\nLocations checked were:\n$progDirNew\n$progDirOld";
}

opendir(NARDIR, '.' ) or die "Unable to open local directory\n";

print "Checking for encrypted *.naz files...";
while (readdir NARDIR) {
	if ($_ =~/.*\.naz$/) {
		$result=system('"' . $decrypt . '" ' . $_ . " " . $_ . ".nar");
	}
}
print "Done.\n";
closedir(NARDIR);

print "Looking for NAR files in current directory...";
opendir(NARDIR,'.') or die "Unable to open local directory\n";
$narlist="";

$numberOfNARFiles=0;
while (readdir NARDIR) {
	if ($_ =~ /.*\.nar$/) {
		$narfiles[$numberOfNARFiles]=$_ ;
		$numberOfNARFiles+=1;
	}
}
closedir(NARDIR);

#for ($i=0;$i < @narfiles ; $i++) {
#	if ($i == 0) {
#		$narlist=$narfiles[$i];
#	} else {
#		$narlist=$narlist . "," . $narfiles[$i];
#	}
#}

print "Done.\n";


if (@narfiles > 0)
{
	print "##############################################################\n";
	print "#### Nar Analysis                                         ####\n";
	print "####                                                      ####\n";
	print "#### This script will extract data from NAR files and     ####\n";
	print "#### output into a set of CSVs suitable for graphing the  ####\n";
	print "#### performance data.                                    ####\n";
	print "####                                                      ####\n";
	print "#### Please select which stats to extract:                ####\n";
	print "####                                                      ####\n";
	print "#### (S)tandard statistics - SP, Port, Raid Group, LUN    ####\n";
	print "#### (P)ool statistics - Pool Disks, Private RGs and LUNs ####\n";
	print "#### (B)oth                                               ####\n";
	print "####                                                      ####\n";
	print "#### The default is to collect only standard statistics.  ####\n";
	print "##############################################################\n";
	print "Please select statistics to collect (S/P/B): ";
	$choice="";
	$choice=<STDIN>;
	chomp($choice);
	$choice=uc($choice);
	$choice="S" if $choice eq "";

	$command='"' . $naviCLI . '" ';
	
	if ( $choice eq "S" ){
		processStandardStats($command);	
	} elsif ($choice eq "P" ) {
		processPoolStats($command);
	} elsif ($choice eq "B") {
		processStandardStats($command);
		processPoolStats($command);
	}


} else {
	print "No NAR files found to process.\n";
}


######################################################################################
# Supporting functions
######################################################################################

sub dumpData {
	$command=$_[0];
	$params=$_[1];
	$objects=$_[2];
	$file=$_[3];


	open(OUTFILE,">" . $file) or die "Unable to open $file.";

	for ($i=0; $i < @narfiles; $i++) {
		$execute=$command .  $params . $narfiles[$i] .  $objects  ;
		$execute=$execute . " -header n" if $i > 0;
		print "--$narfiles[$i] (";
		print $i + 1 . " of " . @narfiles . ")\n";
		open(NAR,$execute . "|") or die "Unable to dump $objectType data from $file.\n";
		while ($line=<NAR>) {
			chomp($line);
			$line=~s/^\.\.*//;
			print OUTFILE "$line\n";
		} 
		close(NAR);
	}
	
	close(OUTFILE);
}

sub processStandardStats {
	$command = $_[0];

	$params=' analyzer -messner -archivedump -data ';

	#################################
	# This command pulls SP information
	#################################
	
	print "\nExtracting Storage Processor performance data...\n";
	$spDataFile="storageProcessors.csv";	
	$objects=" -object s -format on,pt,u,ql,rt,rb,wb,tb,rio,wio,tt,rs,ws,dp,fcdp ";	
	
	dumpData($command , $params , $objects , $spDataFile);

	#################################
	# This command pulls port information
	#################################
	print "\nExtracting SP Port performance data...\n";
	$pDataFile="spPorts.csv";
	$objects=" -object p -format on,pt,tb,rb,wb,rio,wio,tt,rs,ws,rio,wio,qfc ";
	
	dumpData($command , $params , $objects , $pDataFile);

	#################################
	# This command pulls RAID group information
	#################################
	print "\nExtracting RAID Group performance data...\n";
	$rgDataFile="raidGroups.csv";
	$objects=" -object rg -format on,pt,u,ql,rt,rio,wio,tt,rb,wb,tb,rs,rs,ws,asd ";

	dumpData($command , $params , $objects , $rgDataFile);



	#################################
	# This command pulls LUN info
	#################################
	print "\nExtracting LUN performance data...\n";
	$lunDataFile="LUNs.csv";
	$objects=" -object hl -format on,pt,u,ql,rt,tb,tt,rb,wb,rs,ws,rio,wio,ff,rch,wch,fcrh,fcwh,st,dc,dcp";

	dumpData($command , $params , $objects , $lunDataFile);
}



sub processPoolStats {
	$command = $_[0];
	
	#################################
	# Cleanup an previous runs
	#################################
	opendir(DIR,".") or die "Unable to read current directory\n";
	while (readdir DIR) {
		if ($_ =~/.*-luns\.csv$/ || $_ =~/.*-privateRaidGroups\.csv$/ | $_ =~/.*-disks\.csv$/) {
			unlink($_);
		}
	}
	close(DIR);

	#################################
	# This series of commands pulls pool info
	#################################
			
	print "\nExtracting Pool information...\n";
	#################################
	# This command pulls out the relationship 
	# between pools and drives and luns
	#################################

	for ($i=0;$i < @narfiles ; $i++) {
		print "Analyzing NAR file $narfiles[$i]...\n";
		$params=' analyzer -messner -archivedump -rel ';
		$objects=" -root tp -level 2 ";
		open (NAR,$command . $params . $narfiles[$i] .  $objects . "|") or die "Unable to dump data from $_\n";
		while(defined($line=<NAR>)) {
			chomp($line);
			if ($line =~ /^[^	]/) {
				$line=~ s/^\.+//;
				$poolName=$line;
				$listOfPools{$poolName}=1;		
				next;
			} elsif ($line =~ /^\t[A-z0-9]/){
				if ($line =~ /.*\[[0-9]+;.*/) {
					$line =~s/(.*\[[0-9]+);.*/\1\]/;
				} 
				$line=~s/^\t//;
				$poolObjects{$line}=$poolName;
			}
		}
		close(NAR);
		#################################
		# This command pulls the private RAID Group information
		#################################
		print "---Private RAID Groups\n";
		
		#################################
		# Create output files
		#################################
		for $pool (keys %listOfPools) {
			$poolFileName=$pool;
			$poolFileName=~s/\//-/g;
			$fileHandle=$pool . "POOLFILE";
			$fileName=$poolFileName . "-privateRaidGroups.csv";
			
			if (! -e $fileName ) {
				open ($fileHandle, ">$fileName") or die "Unable to write file $fileName\n";
				print $fileHandle "Object Name,Poll Time,Utilization (%),Queue Length,Response Time (ms),Total Bandwidth (MB/s),Total Throughput (IO/s),Read Bandwidth (MB/s),Read Size (KB),Read Throughput (IO/s),Write Bandwidth (MB/s),Write Size (KB),Write Throughput (IO/s),Average Seek Distance (GB)\n";
			} else {
				open ($fileHandle, ">>$fileName") or die "Unable to write file $fileName\n";
			}	
		}

		#################################
		# Process NAR
		#################################

		$params=' analyzer -messner -archivedump -data ';
		$objects=" -object prg -format on,pt,u,ql,rt,tb,tt,rb,rs,rio,wb,ws,wio,asd ";
		open (NAR, $command . $params . $narfiles[$i] .  $objects . "|") or die "Unable to dump data from $_\n";
			while(defined($line=<NAR>)) {
				chomp($line);
				($on,$pt,$u,$ql,$rt,$tb,$tt,$rb,$rs,$rio,$wb,$ws,$wio,$asd)=split (/,/, $line);
				if (exists($poolObjects{$on})) {
					$fileHandle=$poolObjects{$on} . "POOLFILE";
					print $fileHandle "$line\n";
				}
			}
		close(NAR);

		#################################
		# Close output files
		#################################
	
		for $pool (keys %listOfPools) {
			$fileHandle=$pool . "POOLFILE";
			close($fileHandle);
		}

		#################################
		# This command pulls out the disk info
		#################################
		print "---Disks\n";

		#################################
		# Create output files
		#################################
		for $pool (keys %listOfPools) {
			$poolFileName=$pool;
			$poolFileName=~s/\//-/g;
			$fileHandle=$pool . "POOLFILE";
			$fileName=$poolFileName . "-disks.csv";

			if (! -e $fileName ) {
				open ($fileHandle, ">$fileName") or die "Unable to write file $fileName\n";
				print $fileHandle "Object Name,Poll Time,Utilization (%),Queue Length,Response Time (ms),Total Bandwidth (MB/s),Total Throughput (IO/s),Read Bandwidth (MB/s),Write Bandwidth (MB/s),Read Size (KB),Write Size (KB),Read Throughput (IO/s),Write Throughput (IO/s)\n";
			} else {
				open ($fileHandle, ">>$fileName") or die "Unable to write file $fileName\n";
			}	
		}

		#################################
		# Process NAR
		#################################

		$params=' analyzer -archivedump -data ';
		$objects=" -object d -format on,pt,u,ql,rt,tb,tt,rb,wb,rs,ws,rio,wio";
		open (NAR, $command . $params . $narfiles[$i] .  $objects . "|") or die "Unable to dump data from $_\n";
			while(defined($line=<NAR>)) {
				chomp($line);
				$line=~s/^\.\.//;
				($on,$pt,$u,$ql,$rt,$tb,$tt,$rb,$wb,$rs,$ws,$rio,$wio)=split (/,/, $line); 
				if (exists($poolObjects{$on})) {
					$fileHandle=$poolObjects{$on} . "POOLFILE";
					print $fileHandle "$line\n";
				}
			}
		close(NAR);

		#################################
		# Close output files
		#################################
	
		for $pool (keys %listOfPools) {
			$fileHandle=$pool . "POOLFILE";
			close($fileHandle);
		}


		#################################
		# This command pulls out the lun info
		#################################
		print "---LUNs\n";

		#################################
		# Create output files
		#################################
		for $pool (keys %listOfPools) {
			$poolFileName=$pool;
			$poolFileName=~s/\//-/g;
			$fileHandle=$pool . "POOLFILE";
			$fileName=$poolFileName . "-luns.csv";

			if (! -e $fileName ) {
				open ($fileHandle, ">$fileName") or die "Unable to write file $fileName\n";
				print $fileHandle "Object Name,Poll Time,Utilization (%),Queue Length,Response Time (ms),Total Bandwidth (MB/s),Total Throughput (IO/s),Read Bandwidth (MB/s),Write Bandwidth (MB/s),Read Size (KB),Write Size (KB),Read Throughput (IO/s),Write Throughput (IO/s), Forced Flushes/s\n";
			} else {
				open ($fileHandle, ">>$fileName") or die "Unable to write file $fileName\n";
			}
		}


		$params=' analyzer -archivedump -data ';
		$objects=" -object hl -format on,pt,u,ql,rt,tb,tt,rb,wb,rs,ws,rio,wio,ff";
		open (NAR, $command . $params . $narfiles[$i] .  $objects . "|") or die "Unable to dump data from $_\n";
			while(defined($line=<NAR>)) {
				chomp($line);
				$line=~s/^\.\.//;
				($on,$pt,$u,$ql,$rt,$tb,$tt,$rb,$wb,$rs,$ws,$rio,$wio,$ff)=split (/,/, $line);
				if ($on =~ /.*\[[0-9]+;.*/) {
					$on =~s/(.*\[[0-9]+);.*/\1\]/;
				}
				if (exists($poolObjects{$on})) {
					$fileHandle=$poolObjects{$on} . "POOLFILE";
					print $fileHandle "$line\n";
				}
			}
		close(NAR);

		#################################
		# Close output files
		#################################
	
		for $pool (keys %listOfPools) {
			$fileHandle=$pool . "POOLFILE";
			close($fileHandle);
		}


	}
}

