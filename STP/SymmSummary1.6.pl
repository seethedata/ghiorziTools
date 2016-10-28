#!/usr/bin/perl
#
# SymmDiskSummary.pl
#
# This script pulls out disk info from symmapi_db.bin.
######################################################


#######################################
# Confirm that Solutions Enabler is installed
#######################################
$stpexe="";
$progDirOld='C:\Program Files (x86)\EMC\SYMCLI\bin';
$progDirNew='C:\Program Files\EMC\SYMCLI\bin';
$diskexe="symdisk.exe";
$cfgexe="symcfg.exe";
if ( -e $progDirNew . "\\" . $exe) {
	$symdiskexe=$progDirNew . "\\" . $diskexe;
	$symcfgexe=$progDirNew . "\\" . $cfgexe;
} elsif (-e $progDirOld . "\\" . $exe) {
	$symdiskexe=$progDirOld . "\\" . $diskexe;
	$symcfgexe=$progDirOld . "\\" . $cfgexe;
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

print "-------------Symm--------------\n";
open(API,"\"$symcfgexe\" list |");
while ($line=<API>) {
	chomp($line);
	$line=~s/^\s+//;
	if ($line =~ /(DMX|VMAX)/) {
		($sid,$attach,$model,$mcode,$cache,$devs,$symdevs)=split (/\s+/, $line);
		$sids{$sid}=$model;
	}
	print "$line\n";
}
close(API);


print "-------------Memory--------------\n";
for $sym (keys %sids) {
	print "$sym\n";
	open(API,"\"$symcfgexe\" list -memory -sid $sym|");
	while ($line=<API>) {
		chomp($line);
		next if ($line =~ /^Symmetrix ID/);
		$line=~s/\n//;
		print "$line\n";
	}
	close(API);
}


print "-------------Cabinets--------------\n";
for $sym (keys %sids) {
	print "$sym\n";
	open(API,"\"$symcfgexe\" list -bay_info -sid $sym|");
	while ($line=<API>) {
		chomp($line);
		next if ($line =~ /^Symmetrix ID/);
		$line=~s/^\s+//;
		print "$line\n" if $line =~ /^Bay Location/;
	}
	close(API);
}


print "----------------Disks--------------------\n";

%disks="";

for $sym (keys %sids) {
	$tech="X";
	$speed="X";
	$size="X";
	open(API,"\"$symdiskexe\" list -v -sid $sym|") or die "No!";
	while ($line=<API>) {
		if ($line =~ /Target ID/){ 
			$tech="X";
			$speed="X";
			$size="X";
		} elsif ($line =~ /Technology/) {
			chomp;
			($label,$tech)=split ":",$line;
			$tech=~s/ //g;
			$tech=~s/\n//g;
		} elsif ($line =~ /Speed/) {
			chomp;
			($label,$speed)=split ":",$line;
			$speed=cleanSpeed($speed);
		} elsif ($line =~ /Total Disk Capacity \(MB\)/) {
			($label,$size)=split ":",$line;
			if ($size == 0 ) {
				$size="X";
				$speed="X";
				$tech="X";			
			} else {
				$size=cleanSize($size);
			}
		} 

		if ($tech ne "X" && $speed ne "X" && $size ne "X") {
			$disks{$sym}{$size . " " . $speed . " " . $tech}+=1;
			$size="X";
			$speed="X";
			$tech="X";
		} else {
			#print "No. Sym:$sym  cnt:$cnt  tech:$tech  speed:$speed  size:$size\n";	
		}
	}
	close(API);

	$tech="X";
	$speed="X";
	$size="X";


	open(API,"\"$symdiskexe\" list -hotspares -v -sid $sym|");
	while(defined (my $line=<API>) ) {	
		next if ($line =~ /^Symmetrix ID/);
		
		if ($line =~ /Director/){ 
			$tech="X";
			$speed="X";
			$size="X";
		} elsif ($line =~ /Technology/) {
			chomp;
			($label,$tech)=split ":",$line;
			$tech=~s/ //g;
			$tech=~s/\n//g;
		} elsif ($line =~ /Speed/ ) {
			chomp;	
			($label,$speed)=split ":",$line;
			$speed=cleanSpeed($speed);
		} elsif ($line =~ /Actual Disk Capacity \(MB\)/) {
			chomp;
			($label,$size)=split ":",$line;	
			$size=cleanSize($size);
		}
		if ($tech ne "X" && $speed ne "X" && $size ne "X" ) {
			$hsdisks{$sym}{$size . " " . $speed . " " . $tech}+=1 ;
			$tech="X";
			$speed="X";
			$size="X";
		} 
	}
	close(API);
}
for $sym (sort keys %sids) {
	next if $sym eq "";
	print "Symmetrix: $sym\n";
	for $type (keys %{$disks{$sym}}) {
		$count=$disks{$sym}{$type};
		print "$count $type\n" if $disks{$sym}{$type} > 0;
	}
	print "---------HotSpares----------\n";
	for $type (keys %{$hsdisks{$sym}}) {
		print "$hsdisks{$sym}{$type} $type\n" if $hsdisks{$sym}{$type} > 0;
	}
	print "--------------------------------------\n";
	open(API,"\"$symdiskexe\" list -SID $sym|");
	while ($line=<API>) {
		chomp($line);
		if ($line =~ /^Disks Selected/) {
			($label,$value)=split (/:/,$line);
			$value=~s/ //g;
			print "Total Disks: $value\n\n";
			last;
		}
	}
	close(API);
}

print "-------------Pools--------------\n";
for $sym (keys %sids) {
	print "$sym\n";
	open(API,"\"$symcfgexe\" list -thin -pool -gb -sid $sym|");
	while ($line=<API>) {
		chomp($line);
		next if ($line =~ /^Symmetrix ID/);
		$line=~s/\n//;
		print "$line\n";
	}
	close(API);
}



print "\n----Software (This is experimental and may not be accurate)----\n";
open(API,"\"$symcfgexe\" list -features -enabled|");
while ($line=<API>) {
	chomp($line);
	if ($line =~ /Feature Name/) {
		($label,$name)=split (/:/,$line);
		$name=~s/\n//g;
		print "$name ";
	} elsif ($line =~ /Feature Capacity Type/) {
		($label,$type)=split ":",$line;
		$type=~s/\n//g;
		print "$type ";
	} elsif ($line =~ /Feature Capacity/ ) {
		($label,$capacity)=split ":",$line;
		$capacity=~s/\n//g;
		print ":$capacity TB" if $type =~ "TB of Total Capacity";
		print "\n";
	}
}
close(API);

system("pause");

sub cleanSize {
	
	$size=$_[0];

	if ($size < 36384) {
		$newsize=36;
	} elsif ($size > 36384 and $size < 74752) {
		$newsize=73;
	} elsif ($size > 74752 and $size < 102400) {
		$newsize=100;
	} elsif ($size > 102400 and $size < 149504) {
		$newsize=146;
	} elsif ($size > 149504 and $size < 204800) {
		$newsize=200;
	} elsif ($size > 204800 and $size < 307200) {
		$newsize=300;
	} elsif ($size > 307200 and $size < 409600) {
		$newsize=400;
	} elsif ($size > 409600 and $size < 460800) {
		$newsize=450;
	} elsif ($size > 460800 and $size < 512000) {
		$newsize=500;
	} elsif ($size > 512000 and $size < 614400) {
		$newsize=600;
	} elsif ($size > 611400 and $size < 768000) {
		$newsize=750;
	} elsif ($size > 768000 and $size < 1024000) {
		$newsize=1000;
	} elsif ($size > 1024000 and $size < 2048000) {
		$newsize=2000;
	} elsif ($size > 2048000 and $size < 3072000) {
		$newsize=3000;
	} else {
		$newsize=-1;
	}

	return $newsize;
}

sub cleanMemorySize {
	my $memorysize=$_[0];
	if ($memorysize =~ /16384/) {
		$memorysize=~s/16384/16GB/;
	} elsif ($memorysize =~/28672/) {
		$memorysize=~s/28672/32GB/;
	} elsif ($memorysize =~ /32768/ ) {
		$memorysize=~s/32768/32GB/;
	} elsif ($memorysize =~ /65536/ ) {
		$memorysize=~s/65536/64GB/;
	} elsif ($memorysize =~ /131072/ ) {
		$memorysize=~s/131072/128GB/;
	} 
	
	return $memorysize;
}
sub cleanSpeed {
	my $speed=$_[0];
		
	$speed=~s/ //g;
	$speed=~s/\n//g;
	$speed=~s/15000/15k/;
	$speed=~s/7200/7.2k/;
	$speed=~s/10000/10k/;
	$speed=~s/^0$/EFD/;
	$speed=~s/N\/A//;

	return($speed);
}