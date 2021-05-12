#!/usr/bin/env perl
=head
The script calculates the sum of read length in a provided FASTQ or FASTA file. Returns this number to the standard output.

Example:
perl /mnt/lustre/shelkmike/Work/Scripts/calculate_total_read_length.pl reads.fasta
=cut

$reads_filename=$ARGV[0];

open READS, "< $reads_filename";

$total_read_length=0;
if($reads_filename=~/(\.fastq|\.fq)/i) #if this is a FASTQ file.
{
	while(<READS>)
	{
		if($.%4==0)
		{
			$line=$_;
			chomp($line);
			$total_read_length+=length($line);
		}
	}
}
elsif($reads_filename=~/(\.fasta|\.fa|\.fas|\.fna)/i) #if this is a FASTA file.
{
	while(<READS>)
	{
		if($_!~/^>/)
		{
			$line=$_;
			chomp($line);
			$line=~s/\s//g;
			$total_read_length+=length($line);
		}
	}
}
else
{
	die "died because the file $reads_filename has an extension corresponding neither to FASTQ nor to FASTA.";
}

print $total_read_length;