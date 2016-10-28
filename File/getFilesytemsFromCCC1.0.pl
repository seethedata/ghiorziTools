#!/usr/bin/perl
#
# getFilesytemsFromCCC.pl
#
# This script lists the filesystems that are contained
# in a CCC XML file from Celerra/VNX
######################################################
use XML::Parser;
use XML::SimpleObject;

opendir(XMLDIR,'.') or die "Unable to open local directory\n";
	
	
	$numberOfXMLFiles=0;
	while (readdir XMLDIR) {
		if ($_ =~ /CCC.*\.xml$/) {
			$xmlfiles[$numberOfXMLFiles]=$_ ;
			$numberOfXMLFiles+=1;
		}
	}	
	closedir(XMLDIR);	
	print "Done.\n\n";


if (@xmlfiles > 0)
{
	print "$xmlfile\n";
	for ($i=0; $i < @xmlfiles ; $i++) {
		$xmlfile=$xmlfiles[$i];
		print "$xmlfile\n";
		$parser = XML::Parser->new(Style => 'Tree');
		$xso=XML::SimpleObject->new( $parser->parsefile($xmlfile) );

		open(OUTFILE,">$xmlfile" .".csv") or die "Unable to create file $xmlfile.csv";
		print OUTFILE "Name,Size_Allocated,Size_Used,Size_Qualifier,Slice Volumes,Auto Extend, Virtual Provisioning, High Watermark\n";
	
		$storageArray=$xso->child('CCC_Document')->child('CELERRA:Celerra');

		foreach my $fs ($storageArray->child('CELERRA:File_Systems')->children('CELERRA:File_System')) {
	    		next if $fs->child('CELERRA:Name')->value =~ /HTTP connection refused/;
			print OUTFILE $fs->child('CELERRA:Name')->value .",";
			print OUTFILE $fs->child('CELERRA:Size_Allocated')->value .",";
			print OUTFILE $fs->child('CELERRA:Size_Used')->value .",";
			print OUTFILE $fs->child('CELERRA:Size_Qualifier')->value .",";
			print OUTFILE $fs->child('CELERRA:Slice_Volumes')->value .",";
			print OUTFILE $fs->child('CELERRA:Auto_Extend')->value .",";
			print OUTFILE $fs->child('CELERRA:Virtual_Provisioning')->value .",";
			print OUTFILE $fs->child('CELERRA:High_Watermark')->value ."\n";
		}
	}
	print "Done.\n";

} else {
	print "No CCC files found to process.\n";
}




