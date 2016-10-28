#!/usr/bin/perl
#
# NAR Analysis.pl
#
# This script dumps performance data from NAR files into
# a set of Excel files with graphs.
######################################################
use Config;
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility qw/xl_date_list/;
use Date::Calc qw/Delta_DHMS/;
	
$Config{useithreads} or die('Recompile Perl with threads to run this program.');

$makeCharts="Y";

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


$numberOfNARFiles=0;
while (readdir NARDIR) {
	if ($_ =~ /.*\.nar$/) {
		$narfiles[$numberOfNARFiles]=$_ ;
		$numberOfNARFiles+=1;
	}
}
closedir(NARDIR);


print "Done.\n\n";

$command="\"$naviCLI \"";
if (@narfiles > 0)
{
	processStandardStats($command);
} else {
	print "No NAR files found to process.\n";
}


######################################################################################
# Supporting functions
######################################################################################


sub processStandardStats {

	$command = $_[0];

	$objectCodes{'LUNs'}='hl';
	$objectCodes{'Pools'}='pool';
	$objectCodes{'FAST Cache'}='ml,hl,pool';

	$formatCodes{'Utilization'}= 'u';
	$formatCodes{'Queue Length'}= 'ql';
	$formatCodes{'Response Time'}= 'rt';
	$formatCodes{'Total Throughput'}= 'tt';
	$formatCodes{'Total Bandwidth'}= 'tb';
	$formatCodes{'Read Throughput'}= 'rio';
	$formatCodes{'Write Throughput'}= 'wio';
	$formatCodes{'Read Bandwidth'}= 'rb';
	$formatCodes{'Write Bandwidth'}= 'wb';
	$formatCodes{'Read Size'}= 'rs';
	$formatCodes{'Write Size'}= 'ws';
	$formatCodes{'Cache Dirty Pages'}= 'dp';
	$formatCodes{'High Water Flush On'}= 'hwfo';
	$formatCodes{'Write Cache Flushes-s'}= 'wcf';
	$formatCodes{'Queue Full Count'}='qfc';
	$formatCodes{'Average Seek Distance'}= 'asd';
	$formatCodes{'Forced Flushes-s'}= 'ff';
	$formatCodes{'FAST Cache Read Hits-s'}= 'fcrh';
	$formatCodes{'FAST Cache Write Hits-s'}= 'fcwh';

	$narStats[0]="tt"; #Total Throughput
	$narStats[1]="fcrh"; #FAST Cache Read Hits/s
	$narStats[2]="fcwh"; #FAST Cache Write Hits/s

	$statName[0]="Total Throughput";
	$statName[1]="FAST Cache Read Hits-s";
	$statName[2]="FAST Cache Write Hits-s";

	$objectType='FAST Cache';	
	$worksheetNames{$objectType}='FAST Cache Analysis.xlsx';
	$poolObjects={};
	for ($i=0; $i < $numberOfNARFiles ; $i++) {
		$file=$narfiles[$i];
		print "$narfiles[$i] ";
		print "(";
		print  $i + 1 . " of $numberOfNARFiles)\n";
		$interval=getInterval($file);
		getMetaLuns($file);
		getPoolLuns($file);
		getFastCacheStatus('FAST Cache',$file);			
		loadObjectData('FAST Cache',$file);			
	}

	$theWorkbook=createWorkbook($objectType);	
	loadWorkbook($objectType);	
	
	createCharts($objectType) if $makeCharts eq "Y";
	$theWorkbook->close();
}

sub getMetaLuns {
	###################################################
	# MetaLUNs do not have a FAST Cache status. In 
	# order to get the status for a MetaLun we will 
	# use the status of any one of its components.
	###################################################

	print "\tExtracting metaLUN information...";
	$file=$_[0];

	$params=' analyzer -archivedump -rel ';
	$objects=" -root ml ";	

	open(NAR,"$command $params $file  $objects|") or die "Unable to dump $objectType data from $file.\n";
	while ($line=<NAR>) {
		chomp($line);
		$line=~s/^\.\.*//;
		if ($line =~/^[^\s]/) {
			$metaHead=getLunNumber($line);
		} elsif ($line =~/^\t\t.*;/) {
			$component=getLunNumber($line);
			$metaLuns{$metaHead}=$component;
			$components{$component}=1;
		}
	}
	close(NAR);
	print keys(%metaLuns) . " MetaLUNs and " . keys(%components) . " component LUNs.\n";
}

sub getPoolLuns {
	print "\tExtracting pool LUN information...";
	$params=' analyzer -archivedump -rel ';
	$objects=" -root pool ";	

	open(NAR,"$command $params $file  $objects|") or die "Unable to dump $objectType data from $file.\n";
	while ($line=<NAR>) {
		chomp($line);
		if ($line =~/^[^\s]/) {
			$pool=$line;	
		} elsif ($line =~/^\s+.*;/) {
			$component=trimLunName($line);
			$poolObjects{$component}=$pool;
		}
	}
	close(NAR);
	print keys(%poolObjects) . " pool LUNs.\n";
}

sub getFastCacheStatus {
	print "\tExtracting FAST Cache Status information...";
	$objectType=$_[0];
	$file=$_[1];

	$params=' analyzer -archivedump -config ';
	$objects=" -object $objectCodes{$objectType},pl";	

	open(NAR,"$command $params $file  $objects|") or die "Unable to dump $objectType data from $file.\n";
	while ($line=<NAR>) {
		chomp($line);
		$line=~s/^\.\.*//;
		if ($line =~ /^(Logical Unit Number|Pool Name)/) {
			$objectName=$line;
			$objectName=~s/^(Logical Unit Number|Pool Name)\s+//;
		} elsif ($line =~ /^FAST Cache state/) {
			#############################################
			# For LUNs, the index is the LUN number. For
			# pools, the index is the Pool name
			#############################################

			$fastCacheStatus{$objectName}=$line;
			$fastCacheStatus{$objectName}=~s/^FAST Cache state\s+//;
		}

	}
	close(NAR);
	print "Done.\n";
}	


sub loadObjectData {
	$objectType=$_[0];
	$file=$_[1];
	print "\tExtracting data for $objectType...";
		
	$params=' analyzer -archivedump -data ';
		
	$format="on";

	for ($j=0; $j < @narStats; $j++ ) {
		$format=$format . "," . $narStats[$j];
	}

	$objects=" -object " . $objectCodes{$objectType} . " -format " . $format . " -header N ";	

	open(NAR,"$command $params $file  $objects|") or die "Unable to dump $objectType data from $file.\n";
	while ($line=<NAR>) {
		chomp($line);
		$line=~s/^\.\.*//;
		($on,$tt,$fcrh,$fcwh)=split (/,/ , $line);
		$on=trimLunName($on);

		if ($tt < ($fcrh + $fcwh) && $tt ne "" ) {
			$tt=0;
			$fcrh=0;
			$fcwh=0;
		}

		$on=$poolObjects{$on} if (defined($poolObjects{$on})) ;


		$objectList{$on}{'Total Throughput'}+= $tt * (60 * $interval);
		$objectList{$on}{'FAST Cache Read Hits-s'}+= $fcrh * (60 * $interval);
		$objectList{$on}{'FAST Cache Write Hits-s'}+= $fcwh * (60 * $interval);		
	}
	close(NAR);
	print "Done.\n";
}

sub createWorkbook {
	print "Creating Excel workbook...";
	$objectType=$_[0];

	$workbooks{$objectType}= Excel::Writer::XLSX->new($worksheetNames{$objectType});
	$percent_format{$objectType} = $workbooks{$objectType}->add_format( num_format => '0%' );
	$number_format{$objectType} = $workbooks{$objectType}->add_format( num_format => '0' );



	$sheets{$objectType}{'FAST Cache Hits'} = $workbooks{$objectType}->add_worksheet('Percent of FAST Cache Hits');
	$sheets{$objectType}{'FAST Cache Hits'}->write(0, 0,"Object");
	$sheets{$objectType}{'FAST Cache Hits'}->write(0, 1,"FAST Cache Status");
	$sheets{$objectType}{'FAST Cache Hits'}->write(0, 2,"FAST Cache Hits");
	$sheets{$objectType}{'FAST Cache Hits'}->write(0, 3,"Percent of FAST Cache Hits");



	$sheets{$objectType}{'FAST Cache Hit Percentage'} = $workbooks{$objectType}->add_worksheet('FAST Cache Hit Percentage');	
	$sheets{$objectType}{'FAST Cache Hit Percentage'}->write(0, 0,"Object");
	$sheets{$objectType}{'FAST Cache Hit Percentage'}->write(0, 1,"Total IOs");
	$sheets{$objectType}{'FAST Cache Hit Percentage'}->write(0, 2,"FAST Cache Hit Percentage");



	if ($makeCharts eq "Y") {
		$charts{$objectType}{'pie'}=$workbooks{$objectType}->add_chart( type=>'pie',  embedded=>1 );
		$charts{$objectType}{'pie'}->set_style( 2 );
		$charts{$objectType}{'pie'}->set_title( name=> 'FAST Cache Hits');


		$charts{$objectType}{'column'}=$workbooks{$objectType}->add_chart( type=>'column',  embedded=>1 );
		$charts{$objectType}{'column'}->set_style( 2 );
		$charts{$objectType}{'column'}->set_title( name=> 'FAST Cache Hit Percentage');
	}

	print "Done.\n";	
	return($workbooks{$objectType});
}


sub loadWorkbook {
	print "Loading Excel workbook...";
	$objectType=$_[0];
	$workbook=$_[1];


	#############################################
	# Calculate the FAST Cache hit percentage for
	# each object
	#############################################

	for $object (sort keys %objectList ) {
		$sortedObjectList{$object}{'Total IOPS'}=$objectList{$object}{'Total Throughput'};
		$sortedObjectList{$object}{'Fast Cache Hits'}=$objectList{$object}{'FAST Cache Read Hits-s'} + $objectList{$object}{'FAST Cache Write Hits-s'};	

		if ( $sortedObjectList{$object}{'Fast Cache Hits'} > $sortedObjectList{$object}{'Total IOPS'} && $sortedObjectList{$object}{'Total IOPS'} < 1) {
			$sortedObjectList{$object}{'Total IOPS'}=0;
		}

	
		if ($sortedObjectList{$object}{'Total IOPS'} == 0) {
			$hitPercent=0;
		} else {
			$hitPercent= $sortedObjectList{$object}{'Fast Cache Hits'} / $sortedObjectList{$object}{'Total IOPS'};

		}

		$sortedObjectList{$object}{'hitPercent'}=$hitPercent;	
	}


	#############################################
	# We need to account for metaLun components
	# though in newer versions of NAR this may
	# not be required.
	#############################################
	if (keys(%sortedObjectList) > keys(%components)) {
		$numberOfRows=keys(%sortedObjectList) - keys(%components) + 1;
	} else {
		$numberOfRows=keys(%sortedObjectList) +1;
	}
	


	$row=1;	
	for $object (sort { $sortedObjectList{$b}{'Fast Cache Hits'} <=> $sortedObjectList{$a}{'Fast Cache Hits'} } keys %sortedObjectList ) {	
		$totalHits=$sortedObjectList{$object}{'Fast Cache Hits'};
		
		$lunNumber=getLunNumber($object);
	

		#############################################
		# We only want to report on objects if they
		# are not metaLun components
		#############################################

		if (! defined $components{$lunNumber}) {
			$sheets{$objectType}{'FAST Cache Hits'}->write($row,0,$object );
			
			if (! defined $fastCacheStatus{$lunNumber} ) {

				$status=$fastCacheStatus{$metaLuns{$lunNumber}};
			} else {
				$status=$fastCacheStatus{$lunNumber};
			}

			$sheets{$objectType}{'FAST Cache Hits'}->write($row,1,$status );
			$sheets{$objectType}{'FAST Cache Hits'}->write_number($row, 2, $totalHits, $number_format{$objectType} );
			$formula="=" . $totalHits . "/sum(C2:C" . $numberOfRows . ")";
			$sheets{$objectType}{'FAST Cache Hits'}->write_formula($row, 3, $formula, $percent_format{$objectType} );

			$row++;
		}
	}

	$row=1;
	for $object (sort { $sortedObjectList{$b}{'hitPercent'} <=> $sortedObjectList{$a}{'hitPercent'} } keys %sortedObjectList ) {	
		$lunNumber=getLunNumber($object);

		if ( ! defined $components{$lunNumber}) {	
			if ($sortedObjectList{$object}{'hitPercent'} > 0 ) {
				$percentValue=$sortedObjectList{$object}{'hitPercent'};
				$sheets{$objectType}{'FAST Cache Hit Percentage'}->write($row,0,$object );

				$totalIOPS=$sortedObjectList{$object}{'Total IOPS'};
				if ($totalIOPS == 0 and $totalHits > 0) {
					$sheets{$objectType}{'FAST Cache Hit Percentage'}->write($row, 1, "N/A");
				} else {
					$sheets{$objectType}{'FAST Cache Hit Percentage'}->write_number($row, 1, $totalIOPS, $number_format{$objectType} );
				}
				$sheets{$objectType}{'FAST Cache Hit Percentage'}->write_number($row, 2, $percentValue, $percent_format{$objectType} );
				
				$row++;
			}
		}
	}
	print "Done.\n";
}

sub createCharts {
	$objectType=$_[0];
	
	print "Creating charts...";

	$sheetName=$sheets{$objectType}{'FAST Cache Hits'}->get_name();


		
	$charts{$objectType}{'pie'}->add_series(
				        	categories    => [ $sheetName, 1, $numberOfRows, 0, 0 ],
	       					values        => [ $sheetName, 1, $numberOfRows, 2, 2 ],
	       					name          => $objectType,
					);
	$sheets{$objectType}{'FAST Cache Hits'}->insert_chart(2,8,$charts{$objectType}{'pie'}); 		

	$numberOfRows=0;
	
	for $object (keys %sortedObjectList) {
		$lunNumber=getLunNumber($object);

		next if (defined $components{$lunNumber});

		$numberOfRows++ if $sortedObjectList{$object}{'hitPercent'} > 0;
	} 


	$sheetName=$sheets{$objectType}{'FAST Cache Hit Percentage'}->get_name();
	$charts{$objectType}{'column'}->add_series(
				        	categories    => [ $sheetName, 1, $numberOfRows, 0, 0 ],
	       					values        => [ $sheetName, 1, $numberOfRows, 2, 2 ],
	       					name          => $objectType,
					);
	$sheets{$objectType}{'FAST Cache Hit Percentage'}->insert_chart(2,8,$charts{$objectType}{'column'}); 		
				
	print "Done.\n";	
}


sub getInterval {
	print "\tExtracting sample interval...";
	$file=$_[0];

	$params=' analyzer -archivedump -data ';
	$objects=" -object s -format pt -header N";	

	open(NAR,"$command $params $file  $objects|") or die "Unable to calculate interval from $file.\n";
	while ($line=<NAR>) {
		chomp($line);
		$line=~s/^\.\.*//;
		($date,$time)=split (/ /, $line);
		($month,$day,$year)=split (/\//,$date);
		($hour,$minute,$second)=split(/:/,$time);

		if ($. == 1) {
			$previousYear=$year;
			$previousMonth=$month;
			$previousDay=$day;
			$previousHour=$hour;
			$previousMinute=$minute;
			$previousSecond=$second;
			next;
		} 
		last if $. == 2;
	}
	close(NAR);	
	@interval=Delta_DHMS($previousYear,$previousMonth,$previousDay,$previousHour,$previousMinute,$previousSecond,$year,$month,$day,$hour,$minute,$second);
	$returnInterval=$interval[2];
	$returnInterval+=1 if $interval[3] > 30;
	print "$returnInterval minutes.\n";
	return($returnInterval);	
}

sub getLunNumber {
	$lunName=$_[0];

	$lunName=~s/^\.\.*//;
	$lunName=~s/.*\[//;
	$lunName=~s/;.*//;
	$lunName=~s/\].*//;
	
	return($lunName);
}

sub trimLunName {
	$lunName=$_[0];

	$lunName=~s/^ //;
	$lunName=~s/^\.\.*//;
	$lunName=~s/\;.*/\]/;
	
	return($lunName);

}