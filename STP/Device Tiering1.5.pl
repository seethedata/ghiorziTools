#!/usr/bin/perl
#
# Device Tiering.pl
#
# This script dumps LUN configuration data from a
# btp file and shows how each device is allocated
# across FAST tiers
######################################################
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility;
use Date::Calc qw/Delta_DHMS/;





$stpexe="";
$progDirOld='C:\Program Files (x86)\EMC\SYMCLI\bin';
$progDirNew='C:\Program Files\EMC\SYMCLI\bin';


$exes[0]="symdisk.exe";
$exes[1]="symcfg.exe";
$exes[2]="symfast.exe";
$exes[3]="symsg.exe";


if ( -e $progDirNew . "\\" . $exes[0]) {
	$symdiskexe=$progDirNew . "\\" . $exes[0];
	$symcfgexe=$progDirNew . "\\" . $exes[1];
	$symfastexe=$progDirNew . "\\" . $exes[2];
	$symsgexe=$progDirNew . "\\" . $exes[3];
} elsif (-e $progDirOld . "\\" . $exes[0]) {
	$symdiskexe=$progDirOld . "\\" . $exes[0];
	$symcfgexe=$progDirOld . "\\" . $exes[1];
	$symfastexe=$progDirOld . "\\" . $exes[2];
	$symsgexe=$progDirOld . "\\" . $exes[3];
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

$requiredVersion="7.5.0";

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


$lastDevice="";

$stats{'totalGBs'}=1;
$stats{'poolSubscribed'}=1;
$stats{'allocatedGBs'}=1;
$stats{'percentAllocated'}=1;
$stats{'writtenGBs'}=1;
$stats{'percentWritten'}=1;
$stats{'compressedGBs'}=1;
$stats{'compressedRatio'}=1;

print "Reading symapi_db.bin file.\n";
for $sym (keys %sids) {

	############################################################################
	# FAST Policies
	############################################################################
	
	print "----Policies\n";
	open(API,"\"$symfastexe\" list -sid $sym -fp -v|");
	while ($line=<API>) {
		chomp($line);
		if ($line =~/^Policy Name/) {
			($label1,$label2,$colon,$policyName)=split (/\s+/,$line);
			$policyName=~s/\s+//g;
		} elsif ($line =~/^\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+$/ && $line !~ /---/) {
			($blank,$tier,$type,$maxPercent,$location,$technology,$raid,$flags)=split (/\s+/, $line);
			$maxPercent{$policyName}{$technology}=$maxPercent;
		} elsif ($line =~/^\s+[^\s]+\s+[^\s]\s+$/ && $line !~ /---/) {
			($blank,$storageGroupName,$blank2,$pri)=split (/\s+/,$line);
			$storageGroupName=~s/\s+//g;
			$SGToPolicy{$storageGroupName}=$policyName;
			$SGFAST{$storageGroupName}="Yes";
		} elsif ($line =~ /^Storage Groups/) {
			($label,$numberOfSGs)=split /\(/,$line;
			$numberOfSGs=~s/\).*//;
			$policies{$policyName}=$numberOfSGs;
		}
	}
	close(API);


	for $policy (keys %maxPercent) {
		print "--------$policy EFD: $maxPercent{$policy}{'EFD'} FC: $maxPercent{$policy}{'FC'}  SATA: $maxPercent{$policy}{'SATA'}\n";
	}

	############################################################################
	# FAST Policies to Storage Group Mappings
	############################################################################
	print "----Retreiving FAST Policy to Storage Group mappings.\n";
	open(API,"\"$symfastexe\" list -sid $sym -association|");
	while ($line=<API>) {
		chomp($line);
		if ($line =~/^[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]$/ && $line !~ /---/) {
			($sgName,$policyName,$priority,$flags)=split (/\s+/, $line);
			$sgToPolicy{$sgName}=$policyName;
		} 
	}
	close(API);


	############################################################################
	# Storage Group to Device Mappings
	############################################################################
	print "----Retreiving storage group to device mappings.\n";
	open(API,"\"$symsgexe\" list -sid $sym -v|");
	while ($line=<API>) {
		chomp($line);
		if ($line =~/^Name:/) {
			($label,$storageGroupName)=split (/:/, $line);
			$storageGroupName=~s/\s+//g;
			$fastPolicy="";
			$deviceName="";
		} elsif ($line=~/FAST Policy/) {
			($label,$fastPolicy)=split (/:/, $line);
			$fastPolicy=~s/\s+//g;
			$SGInFAST{$storageGroupName}=$fastPolicy;
		} elsif ($line =~ /^\s+[^\s]+\s+[^\s]+\s+[^\s]*TDEV\s+[^\s]+\s+[^\s]+$/) {
			($blank,$deviceName,$pdevName,$config,$sts,$cap)=split (/\s+/,$line);
			$deviceToSG{$deviceName}=$storageGroupName if $SGFAST{$storageGroupName} eq "Yes";
		}

	}
	close(API);

	############################################################################
	# Storage Group compliance
	############################################################################
	print "----Retreiving storage group compliance information.\n";
	open(API,"\"$symfastexe\" list -sid $sym -association -demand|");
	while ($line=<API>) {
		chomp($line);
		if ($line =~/^Policy Name/) {
			($label,$policyName)=split (/:/, $line);
			$policyName=~s/\s+//g;
		} elsif ($line=~/^Storage Group/) {
			($label,$storageGroupName)=split (/:/, $line);
			$storageGroupName=~s/\s+//g;
		} elsif ($line =~ /^\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[^\s]+$/) {
			($blank,$tierName,$type,$raid,$max,$maxDemand, $used, $growth)=split (/\s+/,$line);
			$tierName=substr($tierName,0,20);
			$growth=~s/\+//g;
			$groupCompliance{$storageGroupName}{$tierName}{'used'}=$used;
			$groupCompliance{$storageGroupName}{$tierName}{'maxDemand'}=$maxDemand;
			$groupCompliance{$storageGroupName}{$tierName}{'growth'}=$growth;
			$groupCompliance{$storageGroupName}{$tierName}{'maxPercent'}=$max;
		} 
	}
	close(API);

	
	############################################################################
	# Pool Technology
	############################################################################
	print "----Retreiving pool technology information.\n";
	open(API,"\"$symcfgexe\" list -sid $sym -thin -pool -detail -gb|");
	while ($line=<API>) {
		chomp($line);
		$line=~s/2-Way Mir/2-WayMir/;
		if ($line =~ /[^\s]+\s+[^\s]+\s+[^\s]+\s+[.0-9]+\s+[.0-9]+\s+[.0-9]+\s+[.0-9]+\s+[.0-9]+\s+[.0-9]+\s+[.0-9]+\s+[.0-9]+$/ && $line !~ /----/) {
			($poolName,$flags,$raid,$total,$usable,$free,$used,$fullPercent,$subscribedPercent,$compressionPercent,$sharedGBs)=split (/\s+/,$line);
			$tech=$flags;
			$tech=~s/^.(.)..../$1/;
	
			$poolStats{$poolName}{'total'}=$total;
			$poolStats{$poolName}{'used'}=$used;
			$poolStats{$poolName}{'fullPercent'}=$fullPercent;
			$poolStats{$poolName}{'subscribedPercent'}=$subscribedPercent;

		
			if ($tech eq "E" ) {
				$poolTechnology{$poolName}="EFD";
			} elsif ($tech eq "F") {
				$poolTechnology{$poolName}="FC";
			} elsif ($tech eq "S") {
				$poolTechnology{$poolName}="SATA";
			}

			print "--------$poolName $poolTechnology{$poolName}\n";
			
		}

	}
	close(API);

	############################################################################
	# Pool Level Reserved Capacity
	############################################################################
	print "Retreiving pool level reserved capacities.\n";
	for $poolName (keys %poolStats) {
		open(API,"\"$symcfgexe\" show -sid $sym -thin -pool $poolName -detail|");
		while($line=<API>) {
			chomp($line);
			if ($line =~ /^Pool Reserved Capacity/) {
				($label,$value)=split /:/, $line;
				$value=~s/\s//g;
				$poolStats{$poolName}{'Pool Reserved Capacity'}=$value;
				print "--------$poolName $value" ."%\n";
				last;
			}

		}
		close(API);
	}

	############################################################################
	# FAST Parameters
	############################################################################
	print "----Retreiving FAST parameters.\n";
	open(API,"\"$symfastexe\" list -sid $sym -control_parms|");
	while ($line=<API>) {
		chomp($line);
		if ($line =~ /:/ and $line !~ /:$/) {
			($parameter,$value)=split (/:/,$line);
			$parameter=~s/\s//g;
			$value=~s/\s//g;
			$fastParameters{$parameter}=$value;		
		}
	}
	close(API);

	############################################################################
	# FAST Tiers
	############################################################################
	print "----Retreiving FAST Tiers.\n";
	open(API,"\"$symfastexe\" list -sid $sym -fp -v|");
	while ($line=<API>) {
		chomp($line);
		if ($line =~ /^\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]$/) {
			($blank,$tierName,$type,$maxPercent,$location,$tech,$protection,$flags)=split (/\s+/,$line);
			$tierName=substr($tierName,0,20);
			$tierTechnology{$tierName}=$tech;
		}
	}
	close(API);

	############################################################################
	# Device data
	############################################################################
	
	
	open(API,"\"$symcfgexe\" list -sid $sym -tdev -detail -gb|");
	while ($line=<API>) {
		chomp($line);
		if ($line =~ /[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+$/ && $line =~ /[0-9]/ && $line !~ /=/ && $line !~ /-{5,}/){

			($device,$pool,$flags,$totalGBs,$poolSubscribed,$allocatedGBs,$percentAllocated,$writtenGBs,$percentWritten,$compressedGBs,$compressedRatio) = split /\s+/, $line;

			next if $pool eq "-";
			if ($device eq "") {
				$device=$lastDevice;
			} else {
				$lastDevice=$device;
			}

			$devices{$device}{'totalGBs'}=$totalGBs if $totalGBs >= $devices{$device}{'totalGBs'};
			$devices{$device}{$pool}{'totalGBs'}=$totalGBs;
			$devices{$device}{$pool}{'poolSubscribed'}=$poolSubscribed;
			$devices{$device}{$pool}{'allocatedGBs'}=$allocatedGBs;
			$devices{$device}{$pool}{'percentAllocated'}=$percentAllocated;
			$devices{$device}{$pool}{'writtenGBs'}=$writtenGBs;
			$devices{$device}{$pool}{'percentWritten'}=$percentWritten;
			$devices{$device}{$pool}{'compressedGBs'}=$compressedGBs;
			$devices{$device}{$pool}{'compressedRatio'}=$compressedRatio;			
			
			$pools{$pool}=1;
		}
	}
	close(API);

	############################################################################
	# Create output Excel workbook
	############################################################################	
	print "Creating Excel workbook...\n";
	$deviceListWorkbook= Excel::Writer::XLSX->new("$sym-devices.xlsx");

#	print_device_stats($deviceListWorkbook);

	print_deviceTiering_sheet($deviceListWorkbook);

	print_policy_sheet($deviceListWorkbook);

	print_pools_sheet($deviceListWorkbook);
	
	print_groupCompliance_sheet($deviceListWorkbook);	


	$deviceListWorkbook->close();
	print "Done.\n";

}

sub print_device_stats {
	$deviceListWorkbook=shift;
	for $stat (sort keys %stats) {
		print "----Writing $stat data...";
		$sheets{$stat} = $deviceListWorkbook->add_worksheet($stat);
		$sheets{$stat}->write_string(0, 0,'Device');

		$headerColumn=1;
		for $pool (sort keys %pools) {
			$sheets{$stat}->write_string(0, $headerColumn,$pool . " (GB)");
			$headerColumn++;
		}
		
		$deviceRow=1;
		for $device (sort keys %devices) {
			next if $SGInFAST{$deviceToSG{$device}} ne "Yes";
			$deviceColumn=0;
			$sheets{$stat}->write_string($deviceRow, $deviceColumn,$device);			
			for $pool (sort keys %pools) {
				$deviceColumn++;
				$value=$devices{$device}{$pool}{$stat};
				$value=0 if $value eq "";
				$sheets{$stat}->write($deviceRow, $deviceColumn,$value);			
			}
			$deviceRow++;	
		}
		print "Done.\n";

	}
}

sub print_deviceTiering_sheet {

	$deviceListWorkbook=shift;
	$sheets{'deviceTiering'}=$deviceListWorkbook->add_worksheet('deviceTiering');
	$sheets{'deviceTiering'}->write_string(0,0,"Device");
	$headerColumn=1;
	for $pool (sort keys %pools) {
		$headerValue=$pool . " Allocated(GB)";
		$sheets{'deviceTiering'}->write_string(0, $headerColumn,$headerValue);
		$headerColumn++;
	}
	
	$sheets{'deviceTiering'}->write_string(0, $headerColumn,"Total (GB)");

	$deviceRow=1;
	for $device (sort keys %devices) {
		next if $SGInFAST{$deviceToSG{$device}} ne "Yes";
		$deviceColumn=0;
		$sheets{'deviceTiering'}->write_string($deviceRow, $deviceColumn,$device);			

		for $pool (sort keys %pools) {
			$deviceColumn++;
			$allocated=$devices{$device}{$pool}{'allocatedGBs'};
			$value=$allocated;

			$value=0 if $value < 0;
			$sheets{'deviceTiering'}->write($deviceRow, $deviceColumn,$value);			
		}
		$deviceColumn++;
		$total=$devices{$device}{'totalGBs'};
		$sheets{'deviceTiering'}->write($deviceRow, $deviceColumn,$total);			
		$deviceRow++;	
	}

}

sub print_policy_sheet {
	$deviceListWorkbook=shift;
	$sheets{'policy'} = $deviceListWorkbook->add_worksheet('Policy');
	$policyRow=1;
	for $policy (sort keys %maxPercent) {
		$sheets{'policy'}->write(0,0,"Policy");
		$sheets{'policy'}->write(0,1,"EFD Max %");
		$sheets{'policy'}->write(0,2,"FC Max %");
		$sheets{'policy'}->write(0,3,"SATA Max %");
		$sheets{'policy'}->write(0,4,"# of Storage Groups");
		
		$efdPercent=$maxPercent{$policy}{'EFD'};
		$efdPercent=0 if $efdPercent eq "";
		$fcPercent=$maxPercent{$policy}{'FC'};
		$fcPercent=0 if $fcPercent eq "";
		$sataPercent=$maxPercent{$policy}{'SATA'};
		$sataPercent=0 if $sataPercent eq "";

		$sheets{'policy'}->write($policyRow,0,$policy);
		$sheets{'policy'}->write_number($policyRow,1,$efdPercent);
		$sheets{'policy'}->write_number($policyRow,2,$fcPercent);
		$sheets{'policy'}->write_number($policyRow,3,$sataPercent);
		$sheets{'policy'}->write_number($policyRow,4,$policies{$policy});

		$policyRow++;
	}
	$policyRow=$policyRow + 3;

	$sheets{'policy'}->write($policyRow,0,"FAST Parameter");
	$sheets{'policy'}->write($policyRow,1,"Value");

	$policyRow=$policyRow + 1;
	for $parameter (sort keys %fastParameters) {
		$sheets{'policy'}->write($policyRow,0,$parameter);
		$sheets{'policy'}->write($policyRow,1,$fastParameters{$parameter});
		$policyRow++;
	}
}

sub print_pools_sheet {
	$deviceListWorkbook=shift;
	$sheets{'pools'} = $deviceListWorkbook->add_worksheet('Pools');
	$poolRow=1;
	for $pool (sort keys %poolStats) {
		$sheets{'pools'}->write(0,0,"Pool");
		$sheets{'pools'}->write(0,1,"% Full");
		$sheets{'pools'}->write(0,2,"% Subscribed");
		$sheets{'pools'}->write(0,3,"Total (GB)");
		$sheets{'pools'}->write(0,4,"Used (GB)");
		$sheets{'pools'}->write(0,5,"Pool Reserved Capacity %");


		$sheets{'pools'}->write($poolRow,0,$pool);
		$sheets{'pools'}->write($poolRow,1,$poolStats{$pool}{'fullPercent'});
		$sheets{'pools'}->write($poolRow,2,$poolStats{$pool}{'subscribedPercent'});
		$sheets{'pools'}->write($poolRow,3,$poolStats{$pool}{'total'});
		$sheets{'pools'}->write($poolRow,4,$poolStats{$pool}{'used'});
		$sheets{'pools'}->write($poolRow,5,$poolStats{$pool}{'Pool Reserved Capacity'});

		$poolRow++;
	}

}

sub print_groupCompliance_sheet {
	$tierColumn{"EFD"}=1;
	$tierColumn{"FC"}=2;
	$tierColumn{"SATA"}=3;
	$deviceListWorkbook=shift;
	$sheets{'groupCompliance'} = $deviceListWorkbook->add_worksheet('GroupCompliance');
	$groupRow=1;
	for $group (sort keys %groupCompliance) {
		$sheets{'groupCompliance'}->write(0,0,"Storage Group");	
		$sheets{'groupCompliance'}->write(0,1,"EFD Tier Allocated (GB)");
		$sheets{'groupCompliance'}->write(0,2,"FC Tier Allocated (GB)");
		$sheets{'groupCompliance'}->write(0,3,"SATA Tier Allocated (GB)");
		$sheets{'groupCompliance'}->write(0,4,"Unallocated (GB)");
		$sheets{'groupCompliance'}->write(0,5,"Full Group Size (GB)");
			
		$sheets{'groupCompliance'}->write(0,6,"EFD Excess/Overage (GB)");
		$sheets{'groupCompliance'}->write(0,7,"FC Excess/Overage (GB)");
		$sheets{'groupCompliance'}->write(0,8,"SATA Excess/Overage (GB)");		
		$sheets{'groupCompliance'}->write(0,9,"Policy");
		$sheets{'groupCompliance'}->write(0,10,"Policy EFD %");
		$sheets{'groupCompliance'}->write(0,11,"Policy FC %");
		$sheets{'groupCompliance'}->write(0,12,"Policy SATA %");

		$sheets{'groupCompliance'}->write($groupRow,0,$group);
		
		$groupSize="";
		for $tier (sort keys %{$groupCompliance{$group}} ) {
			if ($groupSize eq "" and $groupCompliance{$group}{$tier}{'maxPercent'} > 0 ) {
				$groupSize=$groupCompliance{$group}{$tier}{'maxDemand'}/($groupCompliance{$group}{$tier}{'maxPercent'}/100);
				$sheets{'groupCompliance'}->write($groupRow,5,$groupSize);
			}
			$technology=$tierTechnology{$tier};
			$sheets{'groupCompliance'}->write($groupRow,$tierColumn{$technology},$groupCompliance{$group}{$tier}{'used'});
print "$group has a tier $tier that is $technology and is in column $tierColumn{$technology}\n";
			$sheets{'groupCompliance'}->write($groupRow,$tierColumn{$technology}+5,$groupCompliance{$group}{$tier}{'growth'});
		}
		$totalCellName=xl_rowcol_to_cell($groupRow,5);
		$startSumCellName=xl_rowcol_to_cell($groupRow,1);
		$endSumCellName=xl_rowcol_to_cell($groupRow,3);
		$formula="=$totalCellName-SUM($startSumCellName" . ":" . "$endSumCellName)";
		$sheets{'groupCompliance'}->write_formula($groupRow,4,$formula);	

		$groupPolicy=$sgToPolicy{$group};
		$sheets{'groupCompliance'}->write($groupRow,9,$groupPolicy);		
		$sheets{'groupCompliance'}->write($groupRow,10,$maxPercent{$groupPolicy}{'EFD'});
		$sheets{'groupCompliance'}->write($groupRow,11,$maxPercent{$groupPolicy}{'FC'});
		$sheets{'groupCompliance'}->write($groupRow,12,$maxPercent{$groupPolicy}{'SATA'});
		$groupRow++;
	}

}