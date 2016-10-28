#!/usr/bin/perl
#
# This script extract some CPU and memory stats
# and database transaction stats from the perfCollect 
# CSV files.
#################################################
require Excel::Writer::XLSX;

$relog='C:\Windows\System32\relog.exe';
$cpuStats=qr/(.*Processor\([0-9]+\).*% Processor Time)/;
$memoryStats=qr/(Target Server Memory|Total Server Memory|Buffer cache hit ratio|Page life expectancy)/;
$databaseStats=qr/(\\Transactions\/sec|Lock Timeouts\/sec|.*:Locks\(.*\)\\Average Wait Time \(ms\)|.*:Locks(.*)\\Lock Waits\/sec)|.*:Locks\(.*\)\\Number of Deadlocks/;

# Check to see if there are *.blg files to relog

opendir(BLGDIR, ".");
while (readdir BLGDIR) {
	if ($_ =~/.*.blg$/) {
		$file=$_;
		$csvfile=$_ . ".csv";
		print "Relogging $_ to CSV...\n";
		$result=system('"' . $relog . '" ' . $_ . " -f csv -o $csvfile");
	}
}
close(BLGDIR);

opendir(CSVDIR, ".");

while (readdir CSVDIR) {
	if ($_ =~/.*\.csv$/ && $_ !~ /-cpu-memory/ &&  $_ !~ /-database/ && $_ !~ /ET_BCSD/) {
		$file=$_;
		my $excelWorkbook=Excel::Writer::XLSX->new( $file . "-perfmon.xlsx");
		my $cpuSheet=$excelWorkbook->add_worksheet('CPU');
		my $memorySheet=$excelWorkbook->add_worksheet('Memory');
		my $databaseSheet=$excelWorkbook->add_worksheet('Database');

		$numberFormat=$excelWorkbook->add_format();
		$dateFormat=$excelWorkbook->add_format();
		$dateFormat->set_num_format("mm/dd/yyyy hh:mm");

		$cpuSheet->write_string(0,0,"Time");
		$memorySheet->write_string(0,0,"Time");
		$databaseSheet->write_string(0,0,"Time");

		open (FILE, "<$file") or die "Unable to read from file $file.";
		while(<FILE>) {
			if ($. == 1) {
				@header=split /,/;
				for ($i=0; $i< @header; $i++) {
					if ($header[$i] =~  $cpuStats) {
						$cpuFields{$i}=$header[$i];
					} elsif ( $header[$i] =~$memoryStats ) {
						$memoryFields{$i}=$header[$i];
					} elsif ($header[$i] =~ /$databaseStats/) {
						$databaseFields{$i}=$header[$i] ;
					}
				}
				$columnNumber=1;
				for $fieldNumber(sort keys %cpuFields) {
					($blank1,$blank2,$server,$processor,$stat)=split(/\\/,$cpuFields{$fieldNumber});
					$stat=~s/\"$//;
					$stat=~s/^ //;
					$cpuSheet->write_string(0,$columnNumber,$processor);
					$columnNumber++;
				}
				
				$columnNumber=1;
				for $fieldNumber(sort keys %memoryFields) {
					($blank1,$blank2,$server,$object,$stat)=split (/\\/,$memoryFields{$fieldNumber});
					$stat=~s/\"$//;
					$stat=~s/^ //;
					$memorySheet->write_string(0,$columnNumber,$stat);
					$columnNumber++;
				}

				$columnNumber=1;
				for $fieldNumber(sort keys %databaseFields) {
					($blank1,$blank2,$server,$object,$stat)=split (/\\/,$databaseFields{$fieldNumber});
					$stat=~s/\"$//;
					$stat=~s/^ //;
					$databaseSheet->write_string(0,$columnNumber,$object . " " . $stat);
					$columnNumber++;
				}

			} else {
				@data=split /,/;
				$rowNumber=$. - 1;
				$columnNumber=1;
				$timestamp=$data[0];
				$timestamp=~s/\"//g;
				($month,$day,$yeartime)=split (/\//,$timestamp);
				($year,$time)=split(/ /,$yeartime);
				($hour,$minute,$second)=split(/:/,$time);
				$second=~s/\..*//;

				$dateValue=sprintf("%4d-%02d-%02dT%02d:%02d:%02d",$year,$month,$day,$hour,$minute,$second);

				for $fieldNumber(sort keys %cpuFields) {
					$cpuSheet->write_date_time($rowNumber,0,$dateValue,$dateFormat);
					$value=$data[$fieldNumber];
					$value=~s/\"//g;
					$value=~s/^ +//g;
					$value=0 if $value !~ /[0-9]/;
					$cpuSheet->write_number($rowNumber,$columnNumber,$value);
					$columnNumber++;
				}
				$columnNumber=1;
				for $fieldNumber(sort keys %memoryFields) {
					$memorySheet->write_date_time($rowNumber,0,$dateValue,$dateFormat);
					$value=$data[$fieldNumber];
					$value=~s/\"//g;
					$value=~s/^ +//g;
					$value=0 if $value !~ /[0-9]/;
					$memorySheet->write_number($rowNumber,$columnNumber,$value);
					$columnNumber++;
				}
				$columnNumber=1;
				for $fieldNumber(sort keys %databaseFields) {
					$databaseSheet->write_date_time($rowNumber,0,$dateValue,$dateFormat);
					$value=$data[$fieldNumber];
					$value=~s/\"//g;
					$value=~s/^ +//g;
					$value=0 if $value !~ /[0-9]/;
					$databaseSheet->write_number($rowNumber,$columnNumber,$value);
					$columnNumber++;
				}
			}
		}
		close(FILE);
	}
		
}

closedir(CSVDIR);