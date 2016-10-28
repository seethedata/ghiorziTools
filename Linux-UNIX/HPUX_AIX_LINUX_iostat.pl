#!/usr/bin/perl
# 
# HPUX_AIX_LINUX_SOLARIS_iostat.pl
#
# This script creates a CSV file from HPUX, AIX, and LINUX iostat data.
#
###############################################################################################################################################


$summaryOnly="N";

$i=0;
opendir(DIR, '.' ) or die "Unable to open local directory\n";
while (readdir DIR) {
	if ($_ =~/.*\.iostat$/) {
		$files[$i]=$_;
		$i++;
	}
}

closedir(DIR);

for ($i=0; $i < @files ; $i++) {
	$file=$files[$i];
	open (IOSTATFILE,"<$file") or die "Unable to open file \"$file\"";

	while(<IOSTATFILE>) {
        	chomp;
		if ($_ =~ /interval=/) {	
				($os,$iostat,$host,$interval)=split /\s+/;
				$host =~ s/system=//;
				$interval =~ s/interval=//;
				print "$os $host $interval\n";
		} else {
			
			($os,$version,$host,$startDate)=split /\s+/;
			($startMonth,$startDay,$startYear)=split /\//, $startDate;
			$interval="calculate";
		}
		last;
	}

	close(IOSTATFILE);
	
	if (@ARGV == 2) {
		$commandLineInterval=$ARGV[1];
		$interval=$commandLineInterval;
	}
	
	if ($os ne "HPUX" && $os ne "AIX" && $os ne "Linux" && $os ne "Solaris") {
		open (IOSTATFILE,"<$file") or die "Unable to open file \"$file\"";
		while(<IOSTATFILE>) {
			last if $. == 3;
			if ($_ =~ /device/) { 
				$os="Solaris";
				last;
			} elsif ($_ =~ /Disks/) {
				$os="AIX";
				last;
			} elsif ($_ =~ /Device:/) {
				$os="Linux";
				last;
			} else {
				$os="Not Found";
			}
		}
		close(IOSTATFILE);
	}

	die "Unable to determine source OS for iostat file $file.\n" if ($os eq "Not Found");

	if ($os eq "HP-UX") {
		processHPUX($file, $host, $interval);
	} elsif ($os eq "AIX") {
		processAIX($file,$host,$interval);
	} elsif ($os eq "Linux") {
		processLinux($file,$host,$interval);
	} elsif ($os eq "Solaris") {
		processSolaris($file,$host,$interval);
	}

}

sub processHPUX 
{
	my $file=$_[0];
	my $host=$_[1];
	my $interval=$_[2];
	die "File $file not found." if (! -f $file);
	print "$file is HP-UX\n";
	$devfile="$file-stats";

        open (DEVFILE,">$devfile.csv") or die "Can not create file $devfile";
        print DEVFILE "Date,Device,MB/s,Seeks/s,Milliseconds/seek\n";

	open (IOSTATFILE,"<$file") or die "Unable to open file \"$file\"";
	while(<IOSTATFILE>) {
		chomp;
		s/
//g;
		if ($. == 1) {
			next;
		}
		if ($. == 2) {
			$startDateTime=$_;
			$startDateTime=~s/January/-01-/;
			$startDateTime=~s/Februrary/-02-/;
			$startDateTime=~s/March/-03-/;
			$startDateTime=~s/April/-04-/;
			$startDateTime=~s/May/-05-/;
			$startDateTime=~s/June/-06-/;
			$startDateTime=~s/July/-07-/;
			$startDateTime=~s/August/-08-/;
			$startDateTime=~s/September/-09-/;
			$startDateTime=~s/October/-10-/;
			$startDateTime=~s/November/-11-/;
			$startDateTime=~s/December/-12-/;
			
			($startDay,$startMonth,$startYear)=split /-/, $startDateTime;
			($startYear,$startTime)= split / /, $startYear;
			($startHour,$startMinute,$startSecond)=split /:/, $startTime;
			print "$startYear-$startMonth-$startDay $startHour:$startMinute:$startSecond\n";
		}  elsif ($_ =~ /^\s*[A-z].*[0-9]\.[0-9]/) {
                	($space,$device,$bps,$sps,$msps)= split /\s+/;
	                if($devices{$device} < 1) {
       		                 $devices{$device}=1;
               		 }

               		$records=$records + 1;

                	$bps=$bps /  1024;
			print DEVFILE "$startYear-$startMonth-$startDay $startHour:$startMinute:$startSecond,$device,$bps,$sps,$msps\n";

		} elsif ($_ =~ /^$/) {
			$startSecond+=$interval;
			while ($startSecond > 59) {
				$startMinute+=1;
				$startSecond-=60;
			}
			while ($startMinute > 59) {
				$startHour+=1;
				$startMinute-=60;
			}
			while ($startHour > 23) {
				$startDay+=1;
				$startHour-=24;
			}
			if ($startMonth == "04" || $startMonth == "06" || $startMonth == "08" || $startMonth == "11") {
				$monthMaxDays=30;
			} elsif ($startMonth == "02") {
				$monthMaxDays=28;
			} else {
				$monthMaxDays=31;
			}
			
			while ($startDay > $monthMaxDays) {
				$startMonth+=1;
				$startDay-= $monthMaxDays;
				if ($startMonth == "04" || $startMonth == "06" || $startMonth == "08" || $startMonth == "11") {
					$monthMaxDays=30;
				} elsif ($startMonth == "02") {
					$monthMaxDays=28;
				} else {
					$monthMaxDays=31;
				}
			}

			while ($startMonth > 12) {
				$startYear+=1;
				$startMonth-=12;
			}
		}
		
	}
	print "Number of devices: " . keys(%devices)  ."\n";
	close(DEVFILE);
	close(IOSTATFLE);
}

sub processAIX
{
	my $file=$_[0];
	my $host=$_[1];
	my $interval=$_[2];
	die "File $file not found." if (! -f $file);
	print "$file is AIX\n";
	$devfile="$file-stats";

        open (DEVFILE,">$devfile.csv") or die "Can not create file $devfile";
        print DEVFILE "Date,Device,Active Time %,MB/s,Transactions/s,MB Read, MB Written\n";

	open (IOSTATFILE,"<$file") or die "Unable to open file \"$file\"";
	while(<IOSTATFILE>) {
		chomp;
		s/
//g;

		if ($. == 1) {
			next;
		}
		if ($. == 2) {
			$startDateTime=$_;
			$startDateTime=~s/January/-01-/;
			$startDateTime=~s/Februrary/-02-/;
			$startDateTime=~s/March/-03-/;
			$startDateTime=~s/April/-04-/;
			$startDateTime=~s/May/-05-/;
			$startDateTime=~s/June/-06-/;
			$startDateTime=~s/July/-07-/;
			$startDateTime=~s/August/-08-/;
			$startDateTime=~s/September/-09-/;
			$startDateTime=~s/October/-10-/;
			$startDateTime=~s/November/-11-/;
			$startDateTime=~s/December/-12-/;
			
			($startDay,$startMonth,$startYear)=split /-/, $startDateTime;
			($startYear,$startTime)= split / /, $startYear;
			($startHour,$startMinute,$startSecond)=split /:/, $startTime;
			print "$startYear-$startMonth-$startDay $startHour:$startMinute:$startSecond\n";
		}  elsif ($_ =~ /^[A-z].*[0-9]\.[0-9]/ && $_ !~ /System Configuration:/) {
                	($device,$tmact,$kbps,$tps,$kbread,$kbwrite)= split /\s+/;
	                if($devices{$device} < 1) {
       		                 $devices{$device}=1;
               		 }

               		$records=$records + 1;

                	$kbps=$kbps /  1024;
                	$kbread=$kbread /  1024;
                	$kbwrite=$kbwrite /  1024;
			print DEVFILE "$startYear-$startMonth-$startDay $startHour:$startMinute:$startSecond,$device,$tmact,$kbps,$tps,$kbread,$kbwrite\n";

		} elsif ($_ =~ /^Disks:/) {
			$startSecond+=$interval;
			while ($startSecond > 59) {
				$startMinute+=1;
				$startSecond-=60;
			}
			while ($startMinute > 59) {
				$startHour+=1;
				$startMinute-=60;
			}
			while ($startHour > 23) {
				$startDay+=1;
				$startHour-=24;
			}
			if ($startMonth == "04" || $startMonth == "06" || $startMonth == "08" || $startMonth == "11") {
				$monthMaxDays=30;
			} elsif ($startMonth == "02") {
				$monthMaxDays=28;
			} else {
				$monthMaxDays=31;
			}
			
			while ($startDay > $monthMaxDays) {
				$startMonth+=1;
				$startDay-= $monthMaxDays;
				if ($startMonth == "04" || $startMonth == "06" || $startMonth == "08" || $startMonth == "11") {
					$monthMaxDays=30;
				} elsif ($startMonth == "02") {
					$monthMaxDays=28;
				} else {
					$monthMaxDays=31;
				}
			}

			while ($startMonth > 12) {
				$startYear+=1;
				$startMonth-=12;
			}
		}
		
	}
	print "Number of devices: " . keys(%devices)  ."\n";
	close(DEVFILE);
	close(IOSTATFLE);
}


sub processSolaris
{
	my $file=$_[0];
	my $host=$_[1];
	my $interval=$_[2];
	die "File $file not found." if (! -f $file);
	print "$file is Solaris\n";
	$devfile="$file-stats";

        open (DEVFILE,">$devfile.csv") or die "Can not create file $devfile";

        print DEVFILE "Date,Device,Read IOPS,Write IOPS, Read MB/s, Write MB/s,Average Service Time,Percent Wait,Percent Busy\n";
	$startDaySet="false";
	print "Interval is: $interval seconds\n";
	open (IOSTATFILE,"<$file") or die "Unable to open file \"$file\"";
	while(<IOSTATFILE>) {
		chomp;
		s/
//g;
		next if ($_ =~ /extended device statistics/);
		if ($_ =~ /[MTWFS][ouehrau][neduit].*:.*:.*/) {
			if ($startDaySet eq "false") {
				($dow,$startMonth,$startDay,$time,$startYear)=split / /;
				$startMonth=~s/Jan/01/;
				$startMonth=~s/Feb/02/;
				$startMonth=~s/Mar/03/;
				$startMonth=~s/Apr/04/;
				$startMonth=~s/May/05/;
				$startMonth=~s/Jun/06/;
				$startMonth=~s/Jul/07/;
				$startMonth=~s/Aug/08/;
				$startMonth=~s/Sep/09/;
				$startMonth=~s/Oct/10/;
				$startMonth=~s/Nov/11/;
				$startMonth=~s/Dec/12/;
			
				($startHour,$startMinute,$startSecond)=split /:/, $time;
			
				print "Start Time: $startYear-$startMonth-$startDay $startHour:$startMinute:$startSecond\n";
				$startDaySet="true";
			} elsif ($startDaySet eq "true") {
				$startSecond+=$interval;

				while ($startSecond > 59) {
					$startMinute+=1;
					$startSecond-=60;
				}
				while ($startMinute > 59) {
					$startHour+=1;
					$startMinute-=60;
				}
				while ($startHour > 23) {
					$startDay+=1;
					$startHour-=24;
				}
				if ($startMonth == "04" || $startMonth == "06" || $startMonth == "08" || $startMonth == "11") {
					$monthMaxDays=30;
				} elsif ($startMonth == "02") {
					$monthMaxDays=28;
				} else {
					$monthMaxDays=31;
				}
				
				while ($startDay > $monthMaxDays) {
					$startMonth+=1;
					$startDay-= $monthMaxDays;
					if ($startMonth == "04" || $startMonth == "06" || $startMonth == "08" || $startMonth == "11") {
						$monthMaxDays=30;
					} elsif ($startMonth == "02") {
						$monthMaxDays=28;
					} else {
						$monthMaxDays=31;
					}
				}
	
				while ($startMonth > 12) {
					$startYear+=1;
					$startMonth-=12;
				}
			}
		}  elsif ($_ =~ /^[0-9]\.[0-9].*[A-z].*/) {
                	($rs,$ws,$rkbs,$wkbs,$await,$actv,$wsvc_t,$asvc_t,$percentWait,$percentBusy,$device)= split /,/;
	                if($devices{$device} < 1) {
       		                 $devices{$device}=1;
               		 }

               		$records=$records + 1;
                	$rkbs=$rkbs /  1024;
                	$wkbs=$wkbs /  1024;
			print DEVFILE "$startYear-$startMonth-$startDay $startHour:$startMinute:$startSecond,$device,$rs,$ws,$rkbs,$wkbs,$asvc_t,$percentWait,$percentBusy\n";
		}
		
	}
	print "Number of devices: " . keys(%devices)  ."\n";
	close(DEVFILE);
	close(IOSTATFLE);
}

sub processLinux
{
	my $file=$_[0];
	my $host=$_[1];
	my $interval=$_[2];

	
	$pattern="^Device:";
print "$interval\n";
	if ($interval eq "calculate") {
		$intervalSwitch="calculate";
		$interval=calculateInterval($file);
		$pattern="^Device:";
		$startTime=getStartTime($file);
		if ($startTime eq "::") {
			$interval=$commandLineInterval;
			$startTime="00:00:00";
			print "No times listed in file. Using $startTime as start time and $interval for interval.\n";
		}
		if ($interval eq "") {
			die "Unable to calculate interval. Please specify on command line.\n"
		}
		($startHour,$startMinute,$startSecond)=split /:/, $startTime;
		($startSecond,$ampm)=split / /, $startSecond;
		if ($ampm =~ /PM/i && $startHour < 12) {
			$startHour+=12;
		}
	}
	die "File $file not found." if (! -f $file);
	print "$file is Linux\n";
	$devfile="$file-stats";

        open (DEVFILE,">$devfile.csv") or die "Can not create file $devfile";
        print DEVFILE "Date,Device,Read Queue/s,Write Queue/s,Read IOPS,Write IOPS, Read MB/s, Write MB/s,Average Queue size in sectors, Average Queue size, Average Wait Time, Average Service Time, %Util\n";

	open (IOSTATFILE,"<$file") or die "Unable to open file \"$file\"";
	while(<IOSTATFILE>) {
		chomp;
		s/
//g;
		if ($. == 1) {
			next;
		} elsif ($. == 2 && $intervalSwitch ne "calculate") {
			$startDateTime=$_ ;
			$startDateTime=~s/January/-01-/;
			$startDateTime=~s/Februrary/-02-/;
			$startDateTime=~s/March/-03-/;
			$startDateTime=~s/April/-04-/;
			$startDateTime=~s/May/-05-/;
			$startDateTime=~s/June/-06-/;
			$startDateTime=~s/July/-07-/;
			$startDateTime=~s/August/-08-/;
			$startDateTime=~s/September/-09-/;
			$startDateTime=~s/October/-10-/;
			$startDateTime=~s/November/-11-/;
			$startDateTime=~s/December/-12-/;
				
			($startDay,$startMonth,$startYear)=split /-/, $startDateTime;
			($startYear,$startTime)= split / /, $startYear;
			($startHour,$startMinute,$startSecond)=split /:/, $startTime;
			print "$startYear-$startMonth-$startDay $startHour:$startMinute:$startSecond\n";
		} elsif ($_ =~ /$pattern/ && keys(%devices) > 0) {
			$startSecond+=$interval;
			while ($startSecond > 59) {
				$startMinute+=1;
				$startSecond-=60;
			}
			while ($startMinute > 59) {
				$startHour+=1;
				$startMinute-=60;
			}
			while ($startHour > 23) {
				$startDay+=1;
				$startHour-=24;
			}
			if ($startMonth == "04" || $startMonth == "06" || $startMonth == "08" || $startMonth == "11") {
				$monthMaxDays=30;
			} elsif ($startMonth == "02") {
				$monthMaxDays=28;
			} else {
				$monthMaxDays=31;
			}
			
			while ($startDay > $monthMaxDays) {
				$startMonth+=1;
				$startDay-= $monthMaxDays;
				if ($startMonth == "04" || $startMonth == "06" || $startMonth == "08" || $startMonth == "11") {
					$monthMaxDays=30;
				} elsif ($startMonth == "02") {
					$monthMaxDays=28;
				} else {
					$monthMaxDays=31;
				}
			}

			while ($startMonth > 12) {
				$startYear+=1;
				$startMonth-=12;
			}
		}  elsif ($_ =~ /^[A-z].*[0-9]\.[0-9]/ && $_ !~ /^Linux/) {
                	($device,$rrqms,$wrqms,$rs,$ws,$rkbs,$wkbs,$avgrqsz,$avgqusz,$await,$svctm,$util)= split /\s+/;
	                if($devices{$device} < 1) {
       		                 $devices{$device}=1;
               		 }

               		$records=$records + 1;

                	$rkbs=$rkbs /  1024;
                	$wkbs=$wkbs /  1024;
                	$kbwrite=$kbwrite /  1024;
			print DEVFILE "$startYear-$startMonth-$startDay $startHour:$startMinute:$startSecond,$device,$rrqms,$wrqms,$rs,$ws,$rkbs,$wkbs,$avgrqsz,$avgqusz,$await,$svctm,$util\n";
		}

	}
	print "Number of devices: " . keys(%devices)  ."\n";
	close(DEVFILE);
	close(IOSTATFLE);
}

sub calculateInterval {
	my $file=$_[0];
	open (IOSTATFILE,"<$file") or die "Unable to open file \"$file\"";
	while(<IOSTATFILE>) {
        	chomp;
        	if ($_ =~ /^Time:/ ) {
               		$time="$_";
                	($label,$hour,$minute,$second)=split(/:/,$time);
                	$hour =~ s/ //g;
                	($second,$ampm)=split(/ /,$second);
                	if($timeCount == 0) {
                       		 $secondsOfDay=$hour*3600 + $minute*60 + $second;
                	} elsif($timeCount == 1) {
                       		 $interval=$hour*3600 + $minute*60 + $second - $secondsOfDay;
                        	die "Unable to calculate sampling interval. Value: $interval\n" if ($interval <= 0);
                        	print "Sampling interval = $interval seconds.\n";
                        	last;
                	}

                	$timeCount+=1;
        	}

	}
	close(IOSTATFILE);
	if ($interval eq "") {
		$interval="::";
	}
	return $interval;
}

sub getStartTime {
	my $file=$_[0];
	open (IOSTATFILE,"<$file") or die "Unable to open file \"$file\"";
	while(<IOSTATFILE>) {
        	chomp;
		if ($_ =~ /^Time:/ ) {
                	($label,$hour,$minute,$second)=split/:/;
			last;
		}
	}	
	$second=~s/
//g;
	close(IOSTATFILE);
	return "$hour:$minute:$second";
}
