#!/usr/bin/env perl
=head
This script takes a FASTA file and produces another FASTA file where contigs shorter than a given length were removed.

Usage:
extract_contigs_longer_than_or_equal_to.pl input_file minimum_contig_length >output_file
������:
extract_contigs_longer_than_or_equal_to.pl input.fasta 1000 >output.fasta

=cut

$infile_name=$ARGV[0];
$minimum_length=$ARGV[1];

open INFILE, "< $infile_name";

@infile=<INFILE>;
$ns=0;
while($infile[$ns])
{
	if($infile[$ns]=~/^(>.+)$/)
	{
		$new_contig_title=$1;
		if(($new_contig_title!~/^$/)&&(length($string)>=$minimum_length)) #���� ��� �� ������ ������, � ����� ����������� ������� ������ ����������, �� ������� ���������� ������
		{
			print "$contig_title\n$string\n";
		}
		$string="";
		$contig_title=$new_contig_title;
	}
	if($infile[$ns]=~/^([A-Za-z \t\-\*]+)$/) #���� � ���� ������ ������ �����, �������, ���������, ���� � * (������ ����-������), �� ������ ��� ������ ������� � �������������������
	{
		$string.=$1;
	}
	
	$ns++;
}
#������� ��������� ������������������
if(length($string)>=$minimum_length)
{
	print "$contig_title\n$string\n";
}

close(INFILE);