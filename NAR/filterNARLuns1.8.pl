#!/usr/bin/perl
#
# filterNARLuns.pl
#
# This script dumps performance data for a list of LUNs.
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

if ( ! -e "lunlist.txt") {
	print "The required filter file \"lunlist.txt\" was not found.\n";
	system(pause);
	exit;
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



print "Done.\n";


if (@narfiles > 0)
{
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

	$arrayName=getArrayName();
	$lunDataFile="filteredLUNs.csv";	
	unlink($lunDataFile) if (-e $lunDataFile);
	open(OUTFILE,">>$lunDataFile") or die "Unable to create file $lunDataFile.\n";
	print OUTFILE "Object,Time,Utilization,Queue Length,Response Time,Total Bandwidth,Total Throughput,Read Bandwidth,Write Bandwidth,Read Size,Write Size,Read Throughput,Write Throughput,Forced Flushes/s,Read Cache Hits,Write Cache Hits,FAST Cache Read Hits, FAST Cache Write Hits,FAST Cache Read Hit Ratio, FAST Cache Write Hit Ratio,Service Time,Disk Crossings, Disk Crossing Percent, Implicit Trespass Count,Explicit Trespass Count,Used Prefetches(%),Prefetch Bandwidth(MB/s)\n";

	open (TALUNLIST,">tierAdvisor-lunlist-byLun.txt") or die "Unable to write tierAdvisor-lunlist.txt.\n";

	$command='"' . $naviCLI . '" ';
	$params=' analyzer -archivedump -data ';	
	$objects=" -join -object hl -format on,pt,u,ql,rt,tb,tt,rb,wb,rs,ws,rio,wio,ff,rch,wch,fcrh,fcwh,fcrhr,fcwhr,st,dc,dcp,itc,etc,up,pb -header n";
	for ($i=0 ;$i < @narfiles ; $i++) {
		print "Dumping LUN info from file "; 
		print $i + 1 . " of " . @narfiles . "...";
		open (NAR, $command . $params . $narfiles[$i] .  $objects . "|") or die "Unable to dump data from $_\n";

		while (defined($line=<NAR>)) {
			chomp($line);
			($on,$pt,$u,$ql,$rt,$tb,$tt,$rb,$wb,$rs,$ws,$rio,$wio,$ff)=split (/,/, $line);
			$lunName=$on;
			$on=~s/.*\[//;
			$on=~s/;.*//;
			$on=~s/\]//;

			print OUTFILE "$line\n" if $lunList{$on} > 0;
			if ($lunList{$on} == 1 ) {
				print TALUNLIST $on . "_" . $lunName . ",$arrayName\n" ;
				$lunList{$on}+=1;
			}
		}
		close(NAR);
		print "Done.\n";
	}
	close(TALUNLIST);
	close(OUTFILE);
}

sub getArrayName {
	print "Extracting array name.";
	$params=' analyzer -archivedump -config ';
	$objects=" -object stor";	


	if (@narfiles > 0)
	{
		$command="\"$naviCLI \"" . $params . $narfiles[0] . $objects ;
		open (NAR,$command . "|") or die "Unable to read $narfiles[0].";
		while (<NAR>) {
			chomp;
			next if $_ !~ /^Name/;
			$name=$_;
			$name=~s/^.*\t//g;
		}
		print "..$name\n";
		return $name;
	} else {
		print "No NAR files found to process.\n";
	}
	

}