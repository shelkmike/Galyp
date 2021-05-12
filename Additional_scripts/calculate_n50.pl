#! /usr/bin/perl
=head
This scripts calculates N50 in a FASTA file and prints it to the standard output.

Example:
perl calculate_n50.pl input.fasta

=cut

my $infile_name=$ARGV[0];
chomp($infile_name);
open INFILE, "< $infile_name";

@sequence_length_array=();
$total_number_of_sequences=0;
$sum_of_lengths_of_all_sequences=0;

while(<INFILE>)
{
	if($_=~/^>/)
	{
		$total_number_of_sequences++;
	}
	if($_=~/^([A-Za-z\s\*\-]+)$/)
	{
		$sequence_in_this_string=$1;
		$sequence_in_this_string=~s/[\s\-]//g;
		$sequence_length_array[$total_number_of_sequences]+=length($sequence_in_this_string);
	}
}

foreach $i(1..$total_number_of_sequences)
{

	$sum_of_lengths_of_all_sequences+=$sequence_length_array[$i];
}

#the array of sequence lengths sorted backwards.
@sorted_backwards_sequence_length_array=sort {$b <=> $a} @sequence_length_array;

$current_sum_of_lengths=0;
foreach $sequence_length(@sorted_backwards_sequence_length_array)
{
	#print "$sequence_length-";
	$current_sum_of_lengths+=$sequence_length;
	if($current_sum_of_lengths>=$sum_of_lengths_of_all_sequences/2)
	{
		$N50=$sequence_length;
		goto we_have_calculated_n50;
	}
}
we_have_calculated_n50:
print $N50;