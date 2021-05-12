=head

The script takes as input a FASTA file with contigs and changes their titles to >NODE_520_length_877_cov_73.02533 . 
The first number is the ordinal number of the contig, starting from 1.
The second number is contig's length.
The third number is contig's average coverage (not k-mer coverage, but real). The coverage is calculated based on the bam-file provided by the user.

How to use: 
perl add_real_coverage_to_contigs_by_a_given_bam_file.pl input_contigs output_contigs number_of_CPU_threads_to_use path_to_the_folder_with_galyp.sh bam-file

Example:
perl /mnt/lustre/shelkmike/Work/Scripts/add_real_coverage_to_contigs_by_a_given_bam_file.pl contigs.fasta contigs_with_real_coverage.fasta 22 /mnt/lustre/shelkmike/Work/Scripts/Galyp/1.7/ mapping.sorted.bam

The bam-file should be sorted and indexed.
=cut

$contigs_file_name=$ARGV[0];
$output_contigs_file_name=$ARGV[1];
$number_of_cpu_threads_to_use=$ARGV[2];
$path_to_the_folder_with_galyp_sh=$ARGV[3];
$path_to_the_bam_file=$ARGV[4];
chomp($path_to_the_bam_file);

#считаю среднее покрытие последовательностей
system("$path_to_the_folder_with_galyp_sh/Additional_programs/mosdepth mosdepth_output --threads $number_of_cpu_threads_to_use --no-per-base $path_to_the_bam_file");

#теперь делаю хэш с настоящими покрытиями вида $hash_contig_ordinal_number_to_contig_coverage{7}=покрытие седьмого по порядку контига и хэш с длинами контигов вида hash_contig_ordinal_number_to_contig_length{7}=длина седьмого по порядку контига
#важно, что номера контигов идут по порядку

%hash_contig_ordinal_number_to_contig_coverage=();
%hash_contig_ordinal_number_to_contig_length=();

open MOSDEPTH_OUTPUT, "< mosdepth_output.mosdepth.summary.txt";
=head
chrom	length	bases	mean	min	max
Backbone_6694	85445	5251005	61.45	5	171
Backbone_5022	157344	15986979	101.61	4	618
Backbone_5814	107553	10700544	99.49	2	636
Backbone_354	64577	2862524	44.33	0	124
Backbone_7660	43130	3007903	69.74	4	426
=cut

$current_contig_ordinal_number=0;
while(<MOSDEPTH_OUTPUT>)
{
	@array_string_split=split(/[ \t]+/,$_);
	if($array_string_split[2]=~/^[\d\.]+$/) #если это не строка с заголовком
	{
		$current_contig_ordinal_number++;
		$hash_contig_ordinal_number_to_contig_length{$current_contig_ordinal_number}=$array_string_split[1];
		$hash_contig_ordinal_number_to_contig_coverage{$current_contig_ordinal_number}=$array_string_split[3];
	}

}
close(MOSDEPTH_OUTPUT);


close(CONTIG_LENGTH_INFORMATION);

#теперь бежим по файлу с контигами и делаем его полную копию, за исключением того, что переписываем все названия

open INFILE, "< $contigs_file_name";
open OUTFILE, "> $output_contigs_file_name";

$current_contig_ordinal_number=0;
while(<INFILE>)
{
	if($_=~/^>/)
	{
		$current_contig_ordinal_number++;
		#>NODE_520_length_877_cov_1.02533
		print OUTFILE ">NODE_".$current_contig_ordinal_number."_length_".$hash_contig_ordinal_number_to_contig_length{$current_contig_ordinal_number}."_cov_".$hash_contig_ordinal_number_to_contig_coverage{$current_contig_ordinal_number}."\n";
	}
	else
	{
		print OUTFILE "$_";
	}
	
}
