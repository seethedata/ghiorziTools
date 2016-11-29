#!/usr/bin/perl
#
# getCustomWorkloadValuesFromNAR.pl
#
# This script outputs a summary of a set of NAR data that
# can be used to create a custom workload in Symmerge.
# NOTE: This script does not work with pool-based LUNs. It 
# only works with classic RAID group LUNs.
##############################################################



use Statistics::Descriptive;

$filterFlag="N";
setupEnvironment();
convertNAZtoNAR();
loadNARList();


if (@narfiles > 0)
{
	if ( -f "lunlist.txt" ) {
		$filterFlag="Y";
		open(LUNLIST,"<lunlist.txt") or die  "Unable to open lunlist.txt\n"; 
		while(<LUNLIST>){
			chomp;
			s/\s+//g;
			s/^.*\[//;
			s/;.*$//;
			s/\]//;
			$lunList{$_}=1;
		}
		close(LUNLIST);
	}
	for ($i=0;$i < @narfiles; $i++) {

		$file=$narfiles[$i];

		$readSizeValue{"r512b"}=0.5;
		$readSizeValue{"r1kb"}=1;
		$readSizeValue{"r2kb"}=2;
		$readSizeValue{"r4kb"}=4;
		$readSizeValue{"r8kb"}=8;
		$readSizeValue{"r16kb"}=16;
		$readSizeValue{"r32kb"}=32;
		$readSizeValue{"r64kb"}=64;
		$readSizeValue{"r128kb"}=128;
		$readSizeValue{"r256kb"}=256;
		$readSizeValue{"r512kb"}=512;
		$writeSizeValue{"w512b"}=0.5;
		$writeSizeValue{"w1kb"}=1;
		$writeSizeValue{"w2kb"}=2;
		$writeSizeValue{"w4kb"}=4;
		$writeSizeValue{"w8kb"}=8;
		$writeSizeValue{"w16kb"}=16;
		$writeSizeValue{"w32kb"}=32;
		$writeSizeValue{"w64kb"}=64;
		$writeSizeValue{"w128kb"}=1328;
		$writeSizeValue{"w256kb"}=256;
		$writeSizeValue{"w512kb"}=512;

		getWorkloadFromFile($file);

	}
		createStats();
		printSymmWorkload();

} else {
	print "No NAR files found to process.\n";
}


######################################################################################
# Supporting functions
######################################################################################
sub printSymmWorkload {
	for $array (keys %readCacheHits) {
		$outfile=$array . "_custom_workload.xml";
print "\nMin WCH:" . $writeCacheHits{$array}->min() . "\n";
print "Max WCH:" . $writeCacheHits{$array}->max() . "\n";
print "\nMin RCH:" . $readCacheHits{$array}->min() . "\n";
print "Max RCH:" . $readCacheHits{$array}->max() . "\n";
print "\nMin RCM:" . $readCacheMisses{$array}->min() . "\n";
print "Max RCM:" . $readCacheMisses{$array}->max() . "\n";
print "\nMin WCM:" . $writeCacheMisses{$array}->min() . "\n";
print "Max WCM:" . $writeCacheMisses{$array}->max() . "\n";


		print "Creating $outfile...";

		open(OUTFILE,">$outfile") or die "Unable to create $outfile.	";
		print OUTFILE '<?xml version="1.0"?>' . "\n";
		print OUTFILE '<Workload xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" Name="' . $file . '" Time="0001-01-01T00:00:00">' . "\n";
	
		print OUTFILE "\t" . '<WorkLoadComponent Emulation="OS" IOsType="WM">' . "\n";
		print OUTFILE "\t\t" . '<IOs>' . "\n";
	      	print OUTFILE "\t\t\t" . '<double>';
		print OUTFILE $writeCacheMisses{$array}->max();
		print OUTFILE '</double>' ."\n";
		print OUTFILE "\t\t" . '</IOs>' . "\n";
	    	print OUTFILE "\t\t" . '<Sizes>' . "\n";
	      	print OUTFILE "\t\t\t" . '<double>';
		print OUTFILE $writeSize{$array};
		print OUTFILE '</double>' . "\n";
		print OUTFILE "\t\t" . '</Sizes>' . "\n";
	    	print OUTFILE "\t\t" . '<SqlId>0</SqlId>' . "\n";
	  	print OUTFILE "\t" . '</WorkLoadComponent>' . "\n";

		print OUTFILE "\t" . '<WorkLoadComponent Emulation="OS" IOsType="WH">' . "\n";
		print OUTFILE "\t\t" . '<IOs>' . "\n";
	      	print OUTFILE "\t\t\t" . '<double>';
		print OUTFILE $writeCacheHits{$array}->max();
		print OUTFILE '</double>' ."\n";
		print OUTFILE "\t\t" . '</IOs>' . "\n";
	    	print OUTFILE "\t\t" . '<Sizes>' . "\n";
	      	print OUTFILE "\t\t\t" . '<double>';
		print OUTFILE $writeSize{$array};
		print OUTFILE '</double>' . "\n";
		print OUTFILE "\t\t" . '</Sizes>' . "\n";
	    	print OUTFILE "\t\t" . '<SqlId>0</SqlId>' . "\n";
	  	print OUTFILE "\t" . '</WorkLoadComponent>' . "\n";
	
		print OUTFILE "\t" . '<WorkLoadComponent Emulation="OS" IOsType="RH">' . "\n";
		print OUTFILE "\t\t" . '<IOs>' . "\n";
	      	print OUTFILE "\t\t\t" . '<double>';
		print OUTFILE $readCacheHits{$array}->max();
		print OUTFILE '</double>' ."\n";
		print OUTFILE "\t\t" . '</IOs>' . "\n";
		print OUTFILE "\t\t" . '<Sizes>' . "\n";
	      	print OUTFILE "\t\t\t" . '<double>';
		print OUTFILE $readSize{$array};
		print OUTFILE '</double>' . "\n";
		print OUTFILE "\t\t" . '</Sizes>' . "\n";
	    	print OUTFILE "\t\t" . '<SqlId>0</SqlId>' . "\n";
	  	print OUTFILE "\t" . '</WorkLoadComponent>' . "\n";
	
		print OUTFILE "\t" . '<WorkLoadComponent Emulation="OS" IOsType="RM">' . "\n";
		print OUTFILE "\t\t" . '<IOs>' . "\n";
	      	print OUTFILE "\t\t\t" . '<double>';
		print OUTFILE $readCacheMisses{$array}->max();
		print OUTFILE '</double>' ."\n";
		print OUTFILE "\t\t" . '</IOs>' . "\n";
		print OUTFILE "\t\t" . '<Sizes>' . "\n";
	      	print OUTFILE "\t\t\t" . '<double>';
		print OUTFILE $readSize{$array};
		print OUTFILE '</double>' . "\n";
		print OUTFILE "\t\t" . '</Sizes>' . "\n";
	    	print OUTFILE "\t\t" . '<SqlId>0</SqlId>' . "\n";
	  	print OUTFILE "\t" . '</WorkLoadComponent>' . "\n";
	
	  	print OUTFILE "\t" . '<SqlId>0</SqlId>' . "\n";
		print OUTFILE "\t" . '<TimeStamp>2013-01-10T00:00:00</TimeStamp>' . "\n";
	  	print OUTFILE "\t" . '<SnapPercent>0</SnapPercent>' . "\n";
	  	print OUTFILE "\t" . '<SnapProtection>RAID1</SnapProtection>' . "\n";
	  	print OUTFILE "\t" . '<IsSnap>false</IsSnap>' . "\n";
	  	print OUTFILE "\t" . '<Flash>30</Flash>' . "\n";
	  	print OUTFILE "\t" . '<Fiber>60</Fiber>' . "\n";
	  	print OUTFILE "\t" . '<SATA>10</SATA>' . "\n";
	  	print OUTFILE '</Workload>' . "\n";
	
		close(OUTFILE);
		print "Done.\n";
	}
}
sub getWorkloadFromFile {
	$file=$_[0];
	$arrayName=getArrayName($file);

	$params=' analyzer  -archivedump -data ';
	$objects=" -object hl -format on,pt,fcrh,fcrm,fcwh,fcwm,rch,rcm,wch,wcm,r512b,r1kb,r2kb,r4kb,r8kb,r16kb,r32kb,r64kb,r128kb,r256kb,r512kb,w512b,w1kb,w2kb,w4kb,w8kb,w16kb,w32kb,w64kb,w128kb,w256kb,w512kb ";	
	$command="\"" . $naviCLI . "\" " . $params . " " . $file . " " . $objects ;

	print "Reading $file ";
	print "(";
	print  $i + 1 ;
	print "/" . @narfiles . ")...";
	open (NAR, $command . "|");
		while (<NAR>) {
			chomp;
			s/^\.\.//g;	
			($on,$pt,$fcrh,$fcrm,$fcwh,$fcwm,$rch,$rcm,$wch,$wcm,$r512b,$r1kb,$r2kb,$r4kb,$r8kb,$r16kb,$r32kb,$r64kb,$r128kb,$r256kb,$r512kb,$w512b,$w1kb,$w2kb,$w4kb,$w8kb,$w16kb,$w32kb,$w64kb,$w128kb,$w256kb,$w512kb)=split /,/;
			$on=~s/\s+//g;
			$on=~s/^.*\[//;
			$on=~s/;.*$//;
			$on=~s/\]//;

			next if $filterFlag eq "Y" and (! $lunList{$on} == 1);

			$objectCount{$arrayName}{$pt}+=1;
			#$readCacheHit{$arrayName}{$pt}+=($rch + $fcrh);
			#$readCacheMiss{$arrayName}{$pt}+=($rcm + $fcrm);
			$readCacheHit{$arrayName}{$pt}+=$rch ;
			$readCacheMiss{$arrayName}{$pt}+=$rcm;
			
			$readSizes{$arrayName}{"r512b"}+=$r512b;
			$readSizes{$arrayName}{"r1kb"}+=$r1kb;
			$readSizes{$arrayName}{"r2kb"}+=$r2kb;
			$readSizes{$arrayName}{"r4kb"}+=$r4kb;
			$readSizes{$arrayName}{"r8kb"}+=$r8kb;
			$readSizes{$arrayName}{"r16kb"}+=$r16kb;
			$readSizes{$arrayName}{"r32kb"}+=$r32kb;
			$readSizes{$arrayName}{"r64kb"}+=$r64kb;
			$readSizes{$arrayName}{"r128kb"}+=$r128kb;
			$readSizes{$arrayName}{"r256kb"}+=$r256kb;
			$readSizes{$arrayName}{"r512kb"}+=$r512kb;
			
			#$writeCacheHit{$arrayName}{$pt}+=($wch + $fcwh);
			#$writeCacheMiss{$arrayName}{$pt}+=($wcm + $fcwm);
			$writeCacheHit{$arrayName}{$pt}+=$wch;
			$writeCacheMiss{$arrayName}{$pt}+=$wcm;
			
			$writeSizes{$arrayName}{"w512b"}+=$w512b;
			$writeSizes{$arrayName}{"w1kb"}+=$w1kb;
			$writeSizes{$arrayName}{"w2kb"}+=$w2kb;
			$writeSizes{$arrayName}{"w4kb"}+=$w4kb;
			$writeSizes{$arrayName}{"w8kb"}+=$w8kb;
			$writeSizes{$arrayName}{"w16kb"}+=$w16kb;
			$writeSizes{$arrayName}{"w32kb"}+=$w32kb;
			$writeSizes{$arrayName}{"w64kb"}+=$w64kb;
			$writeSizes{$arrayName}{"w128kb"}+=$w128kb;
			$writeSizes{$arrayName}{"w256kb"}+=$w256kb;
			$writeSizes{$arrayName}{"w512kb"}+=$w512kb;
		}
	close(NAR);

	$params=' analyzer  -archivedump -data ';
	$objects=" -object s -format on,pt,rio";	
	$command="\"" . $naviCLI . "\" " . $params . " " . $file . " " . $objects ;

	print "Done.\n";
}
sub createStats {	
	for $array (keys %readCacheHit) {
		$readCacheHitStat=Statistics::Descriptive::Full->new();
		$readCacheMissStat=Statistics::Descriptive::Full->new();
		$writeCacheHitStat=Statistics::Descriptive::Full->new();
		$writeCacheMissStat=Statistics::Descriptive::Full->new();

		for $time (keys %{$readCacheHit{$array}}) {
			$readCacheHitStat->add_data($readCacheHit{$array}{$time});
			$readCacheMissStat->add_data($readCacheMiss{$array}{$time});
			$writeCacheHitStat->add_data($writeCacheHit{$array}{$time});
			$writeCacheMissStat->add_data($writeCacheMiss{$array}{$time});	
		}
		$readCacheHits{$array}=$readCacheHitStat;
		$readCacheMisses{$array}=$readCacheMissStat;
		$writeCacheHits{$array}=$writeCacheHitStat;
		$writeCacheMisses{$array}=$writeCacheMissStat;

		for $size (keys %{$readSizes{$array}}) {
			$readSizeWeight{$array}+=($readSizes{$array}{$size} * $readSizeValue{$size});
			$readSizeTotal{$array}+=$readSizes{$array}{$size};
		}
		$readSize{$array}=($readSizeWeight{$array}/$readSizeTotal{$array});
	
		for $size (keys %{$writeSizes{$array}}) {
			$writeSizeWeight{$array}+=($writeSizes{$array}{$size} * $writeSizeValue{$size});
			$writeSizeTotal{$array}+=$writeSizes{$array}{$size};
		}
		$writeSize{$array}=($writeSizeWeight{$array}/$writeSizeTotal{$array});	
	
	}

}



#######################################
# General Functions
#######################################

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


sub getLunNumberFromLunName {
	my $hostName=$_[0];
	$lunNumber=$hostName;
	$lunNumber =~ s/.*\[//g;
	$lunNumber =~ s/;.*//g;

	return $lunNumber;
}

sub getArrayName {
	$file=$_[0];
	$params=' analyzer  -archivedump -config ';
	
	$objects=" -object stor ";	
	
	$command="\"" . $naviCLI . "\" " . $params . " " . $file . " " . $objects ;
	open (NAR, $command . "|");
	while (<NAR>) {
			chomp;
			s/^\.\.//g;
			if ($_ =~ m/^Name/) {
				($label,$name)=split /\s+/;
				last;
			}	
	}
	close(NAR);
	$name="No Array Name Found" if $name eq "";
	return $name;
}
