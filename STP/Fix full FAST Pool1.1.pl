#!/usr/bin/perl
#
# Fix Full FAST Pool.pl
#
# This script recommends a FAST policy that is 
# designed to aleviate thrashing between pools when
# one pool becomes too full
######################################################
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility;
use Date::Calc qw/Delta_DHMS/;

$targetPercent=80;

$fullTargetPercent=$targetPercent;
$nextTargetPercent=$targetPercent;

setupSEEnvironment();
checkSEVersion();
getSymmList();

print "Reading symapi_db.bin file.\n";
for $sym (keys %sids) {

	getFASTPolicies();
	getDev2SG();
	getPoolInfo();
	getFASTDevices();

	getFASTParameters();
	getFASTTiers();
	getGroupCompliance();

	calculateNewPolicy();
	print "Done.\n";
}

system("pause");

$stats{'totalGBs'}=1;
$stats{'poolSubscribed'}=1;
$stats{'allocatedGBs'}=1;
$stats{'percentAllocated'}=1;
$stats{'writtenGBs'}=1;
$stats{'percentWritten'}=1;
$stats{'compressedGBs'}=1;
$stats{'compressedRatio'}=1;




sub setupSEEnvironment {
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
	
	setSEEnvironmentVariables();
}

sub setSEEnvironmentVariables {
	$ENV{"SYMCLI_OFFLINE"}=1;
	$ENV{"SYMCLI_DB_FILE"}="symapi_db.bin";
}

sub checkSEVersion {
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

}

sub getSymmList {
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
}

sub getFASTPolicies {

	############################################################################
	# FAST Policies
	############################################################################
	
	print "----Policies\n";
	open(API,"\"$symfastexe\" list -sid $sym -fp -v|");
	while ($line=<API>) {
		chomp;
		if ($line =~/^Policy Name/) {
			($label1,$label2,$colon,$policyName)=split (/\s+/,$line);
			$policyName=~s/\s+//g;
			$FASTPolicies{$policyName}=0;
		} elsif ($line =~/^\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[^\s]+$/ && $line !~ /---/) {
			($blank,$tier,$type,$maxPercent,$location,$technology,$raid,$flags)=split (/\s+/, $line);
			$maxPercent{$policyName}{$technology}=$maxPercent;
			$tierToPolicy{$tier}=$policyName;
		} elsif ($line =~/^\s+[^\s]+\s+[^\s]\s+$/ && $line !~ /---/) {
			($blank,$storageGroupName,$blank2,$pri)=split (/\s+/,$line);
			$storageGroupName=~s/\s+//g;
			$SGToPolicy{$storageGroupName}=$policyName;
			$SGFAST{$storageGroupName}="Yes";
			$FASTPolicies{$policyName}+=1; # This counts the number of storage groups under control of the policy
		}
	}
	close(API);


	for $policy (keys %maxPercent) {
		print "--------$policy EFD: $maxPercent{$policy}{'EFD'} FC: $maxPercent{$policy}{'FC'}  SATA: $maxPercent{$policy}{'SATA'} Storage Groups: $FASTPolicies{$policy}\n";
	}

}

sub getDev2SG {

	############################################################################
	# Storage Group to Device Mappings
	############################################################################
	print "----Retreiving storage group to device mappings.\n";
	open(API,"\"$symsgexe\" list -sid $sym -v|");
	while ($line=<API>) {
		chomp;
		if ($line =~/^Name:/) {
			($label,$storageGroupName)=split (/:/, $line);
			$storageGroupName=~s/\s+//g;
			$fastPolicy="";
			$deviceName="";
		} elsif ($line=~/FAST Policy/) {
			($label,$fastPolicy)=split (/:/, $line);
			$fastPolicy=~s/\s+//g;
			$SGInFAST{$storageGroupName}=$fastPolicy;
		} elsif ($line =~ /^\s+[^\s]+\s+[^\s]+\s+TDEV\s+[^\s]+\s+[^\s]+$/) {
			($blank,$deviceName,$pdevName,$config,$sts,$cap)=split (/\s+/,$line);
			$storageGroups{$storageGroupName}{'MBs'}+=$cap;
			$deviceToSG{$deviceName}=$storageGroupName if $SGFAST{$storageGroupName} eq "Yes";
		}

	}
	close(API);

}

sub getPoolInfo {
	
	############################################################################
	# Pool Information
	############################################################################
	print "----Retreiving pool technology information.\n";
	open(API,"\"$symcfgexe\" list -sid $sym -thin -pool -detail -gb|");
	while ($line=<API>) {
		chomp;
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

}


sub getFASTParameters {

	############################################################################
	# FAST Parameters
	############################################################################
	print "----Retreiving FAST parameters.\n";
	open(API,"\"$symfastexe\" list -sid $sym -control_parms|");
	while ($line=<API>) {
		chomp;
		if ($line =~ /:/ and $line !~ /:$/) {
			($parameter,$value)=split (/:/,$line);
			$parameter=~s/\s//g;
			$value=~s/\s//g;
			$fastParameters{$parameter}=$value;		
		}
	}
	close(API);

}

sub getFASTTiers {

	############################################################################
	# FAST Tiers
	############################################################################
	print "----Retreiving FAST Tiers.\n";
	open(API,"\"$symfastexe\" list -sid $sym -demand -vp -technology all|");
	while ($line=<API>) {
		chomp;
		if ($line =~ /^Technology /) {
			($parameter,$tech)=split (/:/,$line);
			$tech=~s/\s//g;
		} elsif ($line =~ /^\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[^\s]+$/) {
			($blank,$tierName,$attr,$raid,$tierEnabled,$tierFree,$tierUsed,$used,$avail,$maxDemand,$excess)=split (/\s+/,$line);
			$tierTechnology{$tierName}=$tech;
		}
	}
	close(API);

}

sub getFASTTiers2 {

	############################################################################
	# FAST Tiers
	############################################################################
	print "----Retreiving FAST Tiers2.\n";
	$tech="";
	$tierName="";
	open(API,"\"$symfastexe\" list -sid $sym -demand -vp -technology all -v|");
	while ($line=<API>) {
		chomp;
		if ($line =~ /^Technology/) {
			($parameter,$tech)=split (/:/,$line);
			$tech=~s/\s//g;
		} elsif ($line =~ /\s+Tier Name/) {
			($parameter,$tierName)=split (/:/,$line);
			$tierName=~s/\s//g;
		} 

		if ($tech ne "" and $tierName ne "") {
			$tierTechnology{$tierName}=$tech;
			$tech="";
			$tierName="";
		}
	}
	close(API);

}

sub getFASTDevices {
	############################################################################
	# Device data
	############################################################################
	
	$lastDevice="";
	
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
	
}

sub calculateNewPolicy {
	$fullPool=getFullPool();
	$fullPoolTechnology=$poolTechnology{$fullPool};
	reduceFullPool($fullTargetPercent, $fullPool, $fullPoolTechnology);
	$nextPool=getNextPool($fullPoolTechnology);
	while (checkNextPool($nextPool,$usedInFullPool) eq "NextPoolTooFull" and $fullTargetPercent < 100) {
		$fullTargetPercent+=1;
		reduceFullPool($fullTargetPercent,$fullPool,$fullPoolTechnology);
	}

	$fullPoolUtil=$usedInFullPool*100/$poolStats{$fullPool}{'total'};
	$nextPoolUtil=$nextUsedPercent * 100;
	if ($nextPoolUtil > $targetPercent ) {
		print "Unable to reduce Pool $fullPool without Pool $nextPool exceeding $targetPercent% used.\n";
	} else {
		printf("\n\n%s%.0f%%%s%.2f%s\n", "New max policy percent for $fullPool is ",$newPolicyPercent, " and ", $dataToMove, "GB will be moved to $nextPool.");
		printf("%s%.0f%%%s%.0f%%%s\n\n","This will have Pool $fullPool at ", $fullPoolUtil," used and Pool $nextPool at ", $nextPoolUtil," used.");
	}

}

sub reduceFullPool {
	$fullTargetPercent=$_[0];
	$fullPool=$_[1];
	$fullPoolTechnology=$_[2];
	
	for $policy (keys %FASTPolicies) {
		next if $FASTPolicies{$policy} < 1;
		$usedInFullPool =$poolStats{$fullPool}{'total'};
		$newPolicyPercent=$maxPercent{$policy}{$fullPoolTechnology};
		
		while (($usedInFullPool / $poolStats{$fullPool}{'total'}) >= $fullTargetPercent/100)	{		
			$usedInFullPool = 0;
			$newPolicyPercent--;
			for $storageGroup  (keys %groupCompliance) {
				for $tier (keys %{$groupCompliance{$storageGroup}}) {	
					if ( $tierTechnology{$tier} eq $fullPoolTechnology ) {
						$storageGroupUsed=$groupCompliance{$storageGroup}{$tier}{'used'} ;
						break;
					}
				}
				$storageGroupTotal=$storageGroups{$storageGroup}{'MBs'} / 1024;
				if ($newPolicyPercent/100 < $storageGroupUsed / $storageGroupTotal ) {
					$percent = $newPolicyPercent/100;
				} else {
					$percent = $storageGroupUsed / $storageGroupTotal ;
				}
				$usedInFullPool+=$storageGroups{$storageGroup}{'MBs'} /1024 * $percent;	
			}
		}
	}
}

sub checkNextPool {
	$nextPool=$_[0];
	$usedInFullPool=$_[1];

	$retval="NextPoolTooFull";
	$dataToMove=$poolStats{$fullPool}{'total'}  - $usedInFullPool;

	$nextUsedPercent=($poolStats{$nextPool}{'used'} + $dataToMove) / $poolStats{$nextPool}{'total'} ;

	for $policy (keys %FASTPolicies) {
		next if $FASTPolicies{$policy} == 0;
		if ($nextUsedPercent <= $nextTargetPercent/100) {
			$retval="NextPoolGood";
			break;
		}
	}
	return $retval;
}

sub getFullPool {
	$fullPool="";
	for $pool (keys %poolStats) {
		if ($poolStats{$pool}{'fullPercent'} ge (100 - getPRC() - 1 )) {
			$fullPool=$pool;
			break;
		}
	}
	die "Unable to identify full pool." if $fullPool eq "";
	print "Pool $fullPool is $poolStats{$fullPool}{'fullPercent'}% full ($poolStats{$fullPool}{'used'} GBs / $poolStats{$fullPool}{'total'} GBs).\n";
	return $fullPool;
}

sub getNextPool {
	$fullPoolTechnology=$_[0];
	$nextPoolTechnology=getNextPoolTechnology($fullPoolTechnology);
	$nextPool="";
	for $pool (keys %pools) {
#########  Need to not pick Exchange pool ##############
		next if $pool =~ /MS/;
		if ($poolTechnology{$pool} eq $nextPoolTechnology) {
			$nextPool=$pool;
			break;
		}
	}
	die "Unable to identify next pool." if $nextPool eq "";
	print "Pool $nextPool is $poolStats{$nextPool}{'fullPercent'}% full ($poolStats{$nextPool}{'used'} GBs / $poolStats{$nextPool}{'total'} GBs).\n";
	return $nextPool;
}

sub getNextPoolTechnology {
	$fullPoolTechnology=$_[0];
	$nextPoolTechnology="";
	if ($fullPoolTechnology eq "FC") {
		$nextPoolTechnology = "EFD";
	} else {
		$nextPoolTechnology = "FC";
	}
	return $nextPoolTechnology;
	
}



sub getPRC {
	$prc="ThinPoolReservedCapacity(%)";
	return $fastParameters{$prc};
}

sub getGroupCompliance {

	############################################################################
	# Storage Group compliance
	############################################################################
	print "----Retreiving storage group compliance information.\n";
	open(API,"\"$symfastexe\" list -sid $sym -association -demand|");
	while ($line=<API>) {
		chomp;
		if ($line =~/^Policy Name/) {
			($label,$policyName)=split (/:/, $line);
			$policyName=~s/\s+//g;
		} elsif ($line=~/^Storage Group/) {
			($label,$storageGroupName)=split (/:/, $line);
			$storageGroupName=~s/\s+//g;
		} elsif ($line =~ /^\s+[^\s]+\s+[^\s]+\s+[^\s]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[^\s]+$/) {
			($blank,$tierName,$type,$raid,$max,$maxDemand, $used, $growth)=split (/\s+/,$line);
			$growth=~s/\+//g;
			$groupCompliance{$storageGroupName}{$tierName}{'used'}=$used;
			$groupCompliance{$storageGroupName}{$tierName}{'maxDemand'}=$maxDemand;
			$groupCompliance{$storageGroupName}{$tierName}{'growth'}=$growth;
			$groupCompliance{$storageGroupName}{$tierName}{'maxPercent'}=$max;
		} 
	}
	close(API);
}
