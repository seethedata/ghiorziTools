#!/usr/bin/perl
#
# flushFactorLUNs.pl
#
# This script lists the write IOPs and bandwidth for
# the top ten host luns during times of high SP cache utilization.
# The script also prints out a list of LUNs that have made the top
# ten list.
##################################################################



$spCacheLimit=99;
	

setupEnvironment();
prepareFiles();

if (@narfiles > 0)
{
	for ($i=0;$i < @narfiles; $i++) {
		$file=$narfiles[$i];
		%fileHighWriteTimes =();
		print "(";
		print $i + 1 . " of " . @narfiles . ") $file\n";
		print "\tIdentifying SP Force Flush Times...";
		$params=' analyzer -archivedump -data ';
		$objects=" -object s -format on,pt,dp -header n";	
		$command="\"$naviCLI\" $params $file  $objects";
		open (NAR, $command . "|");
		while (<NAR>) {
			chomp;
			s/^\.//;
			($SP,$time,$dp)=split /,/;
			$SP=~s/\s+//g;
			if ( $dp >= $spCacheLimit) {
				$spForcedFlushes{$time}{$SP}=$dp ;
				$highWriteTimes{$time}=1;
				$fileHighWriteTimes{$time}=1;
			}
		}
		close(NAR);
		print "done.\n";
	
		print "\tIdentifying heavy writers...";
		$objects=" -object al -format on,pt,co,wb,wio -header n";	
		$command="\"$naviCLI\" $params $file  $objects";
		open (NAR, $command . "|");
		while (<NAR>) {
			chomp;
			s/^\.//;
			($LUN,$time,$owner,$wb,$wio)=split /,/;
			$owner=~s/\s+//g;
			$LUN=~s/\s+//g;
			$SP="SP" . $owner;

			if (defined($spForcedFlushes{$time}{$SP})) {
				$lunIOPS{$time}{$LUN}=$wio; 
				$lunBandwidth{$time}{$LUN}=$wb;
				$lunOwner{$LUN}=$SP;
			}
		}
		close(NAR);
		print "Done.\n";
		
		$fileHighWriteCount=keys(%fileHighWriteTimes);
		print "\t$fileHighWriteCount times found where dirty pages was higher than " . $spCacheLimit . "% on either SPA or SPB.\n";
	

	}
	$numberOfHighWriteTimes=keys(%highWriteTimes);
	print "Total of $numberOfHighWriteTimes times found where dirty pages was higher than " . $spCacheLimit . "% on either SPA or SPB.\n";

	open (HW,">highWritesTime.csv") or die "Unable to write highWritesTime.csv\n";
		for $time (sort keys %lunIOPS) { 
			print HW "Time,  SP A %DP, SP B %DP\n";
			$spaDP=$spForcedFlushes{$time}{"SPA"};
			$spbDP=$spForcedFlushes{$time}{"SPB"};
			$spaDP="N/A" if ! defined($spaDP);
			$spbDP="N/A" if ! defined($spbDP);

			print HW "$time,$spaDP,$spbDP\n";
			print HW ",LUN,  Write IOPS, Write Bandwidth, Owner\n";
			$cnt=1;
			for $lun (sort {$lunIOPS{$time}{$b} <=> $lunIOPS{$time}{$a} } keys %{$lunIOPS{$time}}) {	
				last if $cnt > 10;
				print HW ",$lun,$lunIOPS{$time}{$lun},$lunBandwidth{$time}{$lun},$lunOwner{$lun}\n";
				$hwLUN{$lun}+=1;
				$cnt++; 
			}
	}
	close(HW);


	open (HWLUN,">hwluns.csv") or die "Unable to write hwluns.csv\n";
	print HWLUN "LUN, # of times in top-10,% of times in top-10,Owner\n";
		for $lun (sort {$hwLUN{$b} <=> $hwLUN{$a} } keys %hwLUN) {
			$owner=$lunOwner{$lun};
			$numberOfHighWrites=$hwLUN{$lun};
			print HWLUN "$lun,$numberOfHighWrites," . $numberOfHighWrites*100/$numberOfHighWriteTimes . ",$owner\n";
		}
	close(HWLUN);	

} else {
	print "No NAR files found to process.\n";
}




######################################################################################
# Local Functions
######################################################################################


#######################################
# General Functions
#######################################
sub createConfigXML {
	print "Extracting config information.";


	if (@narfiles > 0)
	{
		$command="\"$naviCLI \"" . $params . $narfiles[0] . $objects ;
		system($command);# or die "Unable to dump xml config data from $narfiles[0].\n";
	} else {
		print "No NAR files found to process.\n";
	}
	print "Done.\n";


}

sub createRelationshipXML {
	print "Extracting relationship information.";
	$params=' analyzer -archivedump -rel ';
	$objects=" -root h -xml -out rel.xml -overwrite y";	


	if (@narfiles > 0)
	{
		$command="\"$naviCLI \"" . $params . $narfiles[0] . $objects ;
		system($command) ; #or die "Unable to dump xml relationship data from $narfiles[0].\n";
	} else {
		print "No NAR files found to process.\n";
	}

	print "Done.\n";

}

sub prepareFiles{
	convertNAZtoNAR();
	loadNARList();
}

sub convertNAZtoNAR {

	opendir(NARDIR, '.' ) or die "Unable to open local directory\n";

	print "Checking for encrypted *.naz files...";
	while (readdir NARDIR) {
		if ($_ =~/.*\.naz$/) {
			$result=system('"' . $decrypt . '" ' . $_ . " " . $_ . ".nar");
		}
	}
	print "Done.\n";
	closedir(NARDIR);
}

sub loadNARList {
	
	print "Looking for NAR files in current directory...";
	opendir(NARDIR,'.') or die "Unable to open local directory\n";
	
	
	$numberOfNARFiles=0;
	while (readdir NARDIR) {
		if ($_ =~ /.*\.nar$/) {
			$narfiles[$numberOfNARFiles]=$_ ;
			$numberOfNARFiles+=1;
		}
	}	
	closedir(NARDIR);	
	print "Done.\n\n";
}

sub setupEnvironment {

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
}

sub buildHostList {
	$file="hostlist.txt";
	
	if (-e $file) {
		open(HOSTLIST,"<$file") or die "Unable to open $file.\n";
		while(<HOSTLIST>) {
			chomp;
			$hostlist{$_}='X';
		}
		close(HOSTLIST);
	} else {
		die "hostlist.txt file not found.\n";
	}
}

sub hostIsInHostList {
	$xmlHost=$_[0];

	$retVal = 0;

	for $hostListHost (keys %hostlist) {
		if (index(uc($xmlHost), uc($hostListHost) ) > -1 ) {
			$retVal = 1;
			last;
		}
	}
	return $retVal;
}

sub getLunNumberFromLunName {
	my $hostName=$_[0];
	$lunNumber=$hostName;
	$lunNumber =~ s/.*\[//g;
	$lunNumber =~ s/;.*//g;

	return $lunNumber;
}
