#!/usr/bin/env bash

#Galyp, a pipeline for genome assembly and post-assembly processing. For more details, see https://github.com/shelkmike/Galyp .
galyp_version="1.13"

#######################################
#Step 0. Getting command line arguments and checking whether all required programs are in $PATH.

#The default values.
path_to_short_reads_R1="empty"
path_to_short_reads_R2="empty"
path_to_long_reads="empty"
number_of_cpu_threads_to_use=10
path_to_the_output_folder="Galyp_results"
number_of_the_first_step_in_the_pipeline_to_execute=1
number_of_the_last_step_in_the_pipeline_to_execute=9
error_rate_in_long_reads=0.1										  
strictness_of_the_assembly_process=1
print_help="no" #if a user has entered "--help", the value of this variable changes to "yes".

list_of_unknown_options="" #if a user entered some unknown options, I add them to this variable. If the varible is non-empty, Galyp prints help and stops.

#Parsing the command line arguments. The method is based on a suggestion from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash .
while [[ $# -gt 0 ]] 
do
	key="$1"

	case $key in
		--short_reads_R1)
		path_to_short_reads_R1="$2"
		shift
		shift
		;;
		--short_reads_R2)
		path_to_short_reads_R2="$2"
		shift
		shift
		;;
		--long_reads)
		path_to_long_reads="$2"
		shift
		shift
		;;
		--threads)
		number_of_cpu_threads_to_use="$2"
		shift
		shift
		;;
		--output_folder)
		path_to_the_output_folder="$2"
		shift
		shift
		;;
		--strictness)
		strictness_of_the_assembly_process="$2"
		shift
		shift
		;;
		--number_of_the_first_step_in_the_pipeline_to_execute)
		number_of_the_first_step_in_the_pipeline_to_execute="$2"
		shift
		shift
		;;
		--number_of_the_last_step_in_the_pipeline_to_execute)
		number_of_the_last_step_in_the_pipeline_to_execute="$2"
		shift
		shift
		;;
		--error_rate_in_long_reads)
		error_rate_in_long_reads="$2"
		shift
		shift
		;;
		--help)
		print_help="yes"
		shift
		;;
		--version)
		echo "Galyp "$galyp_version
		exit #If the user needs only the version of Galyp, Galyp prints it and stops.
		shift
		;;
		*)    # unknown option
		list_of_unknown_options+=("$1")
		shift
		;;
	esac
done


#If the user didn't provide paths to some of the required reads, Galyp prints help and stops. Also, it stops if the user has used "--help" key or provided an option which Galyp doesn't know.
if [[ $path_to_short_reads_R1 =~ ^"empty"$ ]] || [[ $path_to_short_reads_R2 =~ ^"empty"$ ]] || [[ $path_to_long_reads =~ ^"empty"$ ]] || [[ $print_help =~ "yes"$ ]] || [[ $list_of_unknown_options =~ .+ ]]; then
	cat << EOF
###########################################
Mandatory options:
1) --short_reads_R1 - path to the file with Illumina reads of the first end. Can be in FASTQ or FASTA, gzipped or not.
2) --short_reads_R2 - path to the file with Illumina reads of the second end. Can be in FASTQ or FASTA, gzipped or not.
3) --long_reads - path to the file with long reads. Can be in FASTQ or FASTA, gzipped or not.

###########################################
Additional options:
4) --threads - how many CPU threads to use. The default value is 10.
5) --output_folder - path to the output folder. The default value is "Galyp_results".
6) --strictness - strictness of the assembly process. The default value is 1. If you want your contigs to have less misassemblies (but, probably, be shorter), try increasing this value to 2, 3, 4...
7) --number_of_the_first_step_in_the_pipeline_to_execute - start Galyp at this step. The list of steps is provided below. The default value is 1. To use values >1, you need a folder with Galyp output produced at previous steps.
8) --number_of_the_last_step_in_the_pipeline_to_execute - finish Galyp at this step. The list of steps is provided below. The default value is 9.
9) --error_rate_in_long_reads - approximate error rate in long reads. The default value is 0.1.

###########################################
Descriptive options:
11) --help - Galyp prints this help and stops.
12) --version - Galyp prints its version and stops.

###########################################
Steps of the pipeline:
1) Preprocessing of reads, estimation of genome size, and some other initial operations.
2) Assembly by Minia.
3) Assembly by DBG2OLC.
4) Polishing by Sparc.
5) Polishing by HyPo.
6) Removal of haplotypic duplication.
7) Another iteration of polishing by HyPo.
8) Removal of short contigs.
9) Renaming of contigs to include information about their lengths and coverages.

###########################################
Example:
bash galyp.sh --short_reads_R1 illumina_reads_R1__adapters_trimmed.fastq --short_reads_R2 illumina_reads_R2__adapters_trimmed.fastq --long_reads long_reads__adapters_trimmed.fastq --threads 20 --output_folder Galyp_results

EOF
exit
fi

#checking if files with reads exist.
list_of_warnings_about_reads_file_absence="" #to this variable I add warnings about the absence of files with reads.
number_of_the_current_problem_with_file_absence=0 #all absent files are enumerated starting with 1.
if [ ! -s $path_to_short_reads_R1 ]
then
	number_of_the_current_problem_with_file_absence=$(expr $number_of_the_current_problem_with_file_absence + 1)
	list_of_warnings_about_reads_file_absence=$list_of_warnings_about_reads_file_absence"\n"$number_of_the_current_problem_with_file_absence") The file "$path_to_short_reads_R1" is absent."
fi

if [ ! -s $path_to_short_reads_R2 ]
then
	number_of_the_current_problem_with_file_absence=$(expr $number_of_the_current_problem_with_file_absence + 1)
	list_of_warnings_about_reads_file_absence=$list_of_warnings_about_reads_file_absence"\n"$number_of_the_current_problem_with_file_absence") The file "$path_to_short_reads_R2" is absent."
fi

if [ ! -s $path_to_long_reads ]
then
	number_of_the_current_problem_with_file_absence=$(expr $number_of_the_current_problem_with_file_absence + 1)
	list_of_warnings_about_reads_file_absence=$list_of_warnings_about_reads_file_absence"\n"$number_of_the_current_problem_with_file_absence") The file "$path_to_long_reads" is absent."
fi

if [[ $list_of_warnings_about_reads_file_absence =~ .+ ]];then
	echo -e "\nUnfortunately, some files with reads are absent:"
	echo -e $list_of_warnings_about_reads_file_absence"\n"
	exit
fi

#If the user has provided relative paths, I convert them to absolute paths (as suggested at https://stackoverflow.com/questions/4175264/how-to-retrieve-absolute-path-given-relative)
path_to_short_reads_R1="$(cd "$(dirname "$path_to_short_reads_R1")"; pwd)/$(basename "$path_to_short_reads_R1")"
path_to_short_reads_R2="$(cd "$(dirname "$path_to_short_reads_R2")"; pwd)/$(basename "$path_to_short_reads_R2")"
path_to_long_reads="$(cd "$(dirname "$path_to_long_reads")"; pwd)/$(basename "$path_to_long_reads")"
path_to_the_output_folder="$(cd "$(dirname "$path_to_the_output_folder")"; pwd)/$(basename "$path_to_the_output_folder")"

#I also determine the path to the current folder. It will help me later because there are several cases when I'll have to go to output folders of some programs and then return.
path_to_the_folder_from_which_Galyp_was_run=$PWD

#Path to the folder where galyp.sh is located. It is necessary to locate its supporting scripts.
path_to_the_folder_with_galyp="$(cd "$(dirname "$0")"; pwd)"

#Checking whether all programs required by Galyp are available.
list_of_warnings_about_unavailability_of_dependencies="" #to this list I will add information about unavailable programs. If there are any, I will print the list to the user.
number_of_the_current_problem_with_unavailability=0 #all problems with unavailability of dependencies are enumerated starting with 1.

if ! [ -d $path_to_the_folder_with_galyp/Additional_scripts ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find the folder /Additional_scripts . It should be located in the same folder where galyp.sh is located. Please, download the full release from https://github.com/shelkmike/Galyp/releases."
fi

if ! [ -d $path_to_the_folder_with_galyp/Additional_programs ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find the folder /Additional_programs . It should be located in the same folder where galyp.sh is located. Please, download the full release from https://github.com/shelkmike/Galyp/releases."
fi

if ! [ $(type -P python3 2>/dev/null) ] #I use "type -P" instead of "which", because different versions of "which" produce different output.
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'python3' in \$PATH."
fi

if ! [ $(type -P python2 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'python2' in \$PATH."
fi

if ! [ $(type -P perl 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'perl' in \$PATH."
fi

if ! [ $(type -P blasr 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'blasr' in \$PATH."
fi

if ! [ $(type -P samtools 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'samtools' in \$PATH."
fi

if ! [ $(type -P run_purge_dups.py 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'run_purge_dups.py' in \$PATH. Please, add the folder with Purge_dups scripts to \$PATH. It is named like .../purge_dups/scripts."
fi

if ! [ $(type -P purge_dups 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'purge_dups' in \$PATH."
fi

if ! [ $(type -P kmergenie 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'kmergenie' in \$PATH."
fi

if ! [ $(type -P kmc 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'kmc' in \$PATH. KMC3 is a prerequisite of HyPo."
fi

if ! [ $(type -P minimap2 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'minimap2' in \$PATH."
fi

if ! [ $(type -P hypo 2>/dev/null) ] 
then
	number_of_the_current_problem_with_unavailability=$(expr $number_of_the_current_problem_with_unavailability + 1)
	list_of_warnings_about_unavailability_of_dependencies=$list_of_warnings_about_unavailability_of_dependencies"\n\n"$number_of_the_current_problem_with_unavailability") Cannot find 'hypo' in \$PATH."
fi

#if there are unavailable programs or scripts, Galyp writes this and exits.
if [[ $list_of_warnings_about_unavailability_of_dependencies =~ .+ ]];then
	echo -e "\n###########################################"
	echo -e "Unfortunately, Galyp cannot find some programs: "$list_of_warnings_about_unavailability_of_dependencies
	exit
fi

#Creating the output folder.
mkdir --parents $path_to_the_output_folder

#I move to the output folder, because some of the programs that I use, like DBG2OLC, always write their output to the folder from where they were run.
cd $path_to_the_output_folder

#Printing the user-provided parameters to the logfile.
current_date_and_time=`date`
echo "At "$current_date_and_time" Galyp was run with the following options:" >$path_to_the_output_folder/logfile.txt
echo "1) Path to first end short reads: "$path_to_short_reads_R1 >>$path_to_the_output_folder/logfile.txt
echo "2) Path to second end short reads: "$path_to_short_reads_R2 >>$path_to_the_output_folder/logfile.txt
echo "3) Path to long reads: "$path_to_long_reads >>$path_to_the_output_folder/logfile.txt
echo "4) Number of CPU threads to use: "$number_of_cpu_threads_to_use >>$path_to_the_output_folder/logfile.txt
echo "5) Path to the output folder: "$path_to_the_output_folder >>$path_to_the_output_folder/logfile.txt
echo "6) Number of the first step in the pipeline to execute: "$number_of_the_first_step_in_the_pipeline_to_execute >>$path_to_the_output_folder/logfile.txt
echo "7) Number of the last step in the pipeline to execute: "$number_of_the_last_step_in_the_pipeline_to_execute >>$path_to_the_output_folder/logfile.txt
echo "8) Approximate error rate in long reads: "$error_rate_in_long_reads >>$path_to_the_output_folder/logfile.txt
echo "9) Strictness of the assembly: "$strictness_of_the_assembly_process >>$path_to_the_output_folder/logfile.txt

#Now I'll check whether all required programs are available in $PATH.


#######################################
#Step 1. Estimate the k-mer size optimal for the assembly and also estimate the genome size. This is performed by Kmergenie. Also, this step performs read decompression (if they were gzipped) and conversion of long reads into FASTA (I'll need them in FASTA later).

#Printing to the logfile.
current_date_and_time=`date`
echo "" >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt
echo "Step 1. Galyp started to preprocess reads, estimate genome size and perform other initial operations. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt

#Checking if the input files with reads are gzipped. If so, I unpack the files, and change the values of the variables $path_to_short_reads_R1, $path_to_short_reads_R2 and $path_to_long_reads so now they point to the unpacked files.

#If short reads of the first end are in fasta.gz
if [[ $path_to_short_reads_R1 =~ ".fasta.gz"$ ]] || [[ $path_to_short_reads_R1 =~ ".fa.gz"$ ]] || [[ $path_to_short_reads_R1 =~ ".fas.gz"$ ]] || [[ $path_to_short_reads_R1 =~ ".FASTA.gz"$ ]] || [[ $path_to_short_reads_R1 =~ ".FA.gz"$ ]] || [[ $path_to_short_reads_R1 =~ ".FAS.gz"$ ]]; then
	if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
	then
		gzip --decompress --stdout $path_to_short_reads_R1 >$path_to_the_output_folder/short_reads_R1.fasta
	fi	
	path_to_short_reads_R1=$path_to_the_output_folder/short_reads_R1.fasta
fi

#If short reads of the first end are in fastq.gz
if [[ $path_to_short_reads_R1 =~ ".fastq.gz"$ ]] || [[ $path_to_short_reads_R1 =~ ".fq.gz"$ ]] || [[ $path_to_short_reads_R1 =~ ".FASTQ.gz"$ ]] || [[ $path_to_short_reads_R1 =~ ".FQ.gz"$ ]]; then
	if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
	then
		gzip --decompress --stdout $path_to_short_reads_R1 >$path_to_the_output_folder/short_reads_R1.fastq
	fi	
	path_to_short_reads_R1=$path_to_the_output_folder/short_reads_R1.fastq
fi

#If short reads of the second end are in fasta.gz
if [[ $path_to_short_reads_R2 =~ ".fasta.gz"$ ]] || [[ $path_to_short_reads_R2 =~ ".fa.gz"$ ]] || [[ $path_to_short_reads_R2 =~ ".fas.gz"$ ]] || [[ $path_to_short_reads_R2 =~ ".FASTA.gz"$ ]] || [[ $path_to_short_reads_R2 =~ ".FA.gz"$ ]] || [[ $path_to_short_reads_R2 =~ ".FAS.gz"$ ]]; then
	if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
	then
		gzip --decompress --stdout $path_to_short_reads_R2 >$path_to_the_output_folder/short_reads_R2.fasta
	fi	
	path_to_short_reads_R2=$path_to_the_output_folder/short_reads_R2.fasta
fi

#If short reads of the first end are in fastq.gz
if [[ $path_to_short_reads_R2 =~ ".fastq.gz"$ ]] || [[ $path_to_short_reads_R2 =~ ".fq.gz"$ ]] || [[ $path_to_short_reads_R2 =~ ".FASTQ.gz"$ ]] || [[ $path_to_short_reads_R2 =~ ".FQ.gz"$ ]]; then
	if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
	then
		gzip --decompress --stdout $path_to_short_reads_R2 >$path_to_the_output_folder/short_reads_R2.fastq
	fi	
	path_to_short_reads_R2=$path_to_the_output_folder/short_reads_R2.fastq
fi

#If long reads are in fasta.gz
if [[ $path_to_long_reads =~ ".fasta.gz"$ ]] || [[ $path_to_long_reads =~ ".fa.gz"$ ]] || [[ $path_to_long_reads =~ ".fas.gz"$ ]] || [[ $path_to_long_reads =~ ".FASTA.gz"$ ]] || [[ $path_to_long_reads =~ ".FA.gz"$ ]] || [[ $path_to_long_reads =~ ".FAS.gz"$ ]]; then
	if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
	then
		gzip --decompress --stdout $path_to_long_reads >$path_to_the_output_folder/long_reads.fasta
	fi	
	path_to_long_reads=$path_to_the_output_folder/long_reads.fasta
fi

#If long reads are in fastq.gz
if [[ $path_to_long_reads =~ ".fastq.gz"$ ]] || [[ $path_to_long_reads =~ ".fq.gz"$ ]] || [[ $path_to_long_reads =~ ".FASTQ.gz"$ ]] || [[ $path_to_long_reads =~ ".FQ.gz"$ ]]; then
	if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
	then
		gzip --decompress --stdout $path_to_long_reads >$path_to_the_output_folder/long_reads.fastq
	fi	
	path_to_long_reads=$path_to_the_output_folder/long_reads.fastq
fi

#if long reads are in FASTQ then I convert them to FASTA. I'll store the path to the long reads in the FASTA format in the variable $path_to_long_reads_in_fasta . The FASTA file with long reads will be needed in the future for Sparc.
if [[ $path_to_long_reads =~ (\.fastq|\.fq|\.FASTQ|\.FQ)$ ]] 
then
	if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
	then
		awk 'BEGIN{P=1}{if(P==1||P==2){gsub(/^[@]/,">");print}; if(P==4)P=0; P++}' $path_to_long_reads >$path_to_the_output_folder"/long_reads.fasta"
	fi		
	path_to_long_reads_in_fasta=$path_to_the_output_folder"/long_reads.fasta"
fi
if [[ $path_to_long_reads =~ (\.fasta|\.fa|\.fas|\.fna|\.FASTA|\.FA|\.FAS|\.FNA)$ ]] 
then
	path_to_long_reads_in_fasta=$path_to_long_reads
fi


#Kmergenie requires pathes to short reads to be contained in a special file.
echo $path_to_short_reads_R1 >$path_to_the_output_folder/list_of_paths_to_files_with_short_reads.txt
echo $path_to_short_reads_R2 >>$path_to_the_output_folder/list_of_paths_to_files_with_short_reads.txt
if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	kmergenie $path_to_the_output_folder/list_of_paths_to_files_with_short_reads.txt -t $number_of_cpu_threads_to_use -o $path_to_the_output_folder/kmergenie_results --diploid -l 21 -k 121 >$path_to_the_output_folder/kmergenie_logs.txt #I restrict the largest k-mer size by 121, because I never saw an assembly for which larger k-mers are optimal.
fi	

#In the html file produced by Kmergenie there are two lines for which I'll parse the file:
#<p><h2>Predicted best k: 69</h2></p>
#<p><h4>Predicted assembly size: 918727408 bp</h4></p>

optimal_kmer_length=`perl -ne 'if($_=~/Predicted best k: (\d+)/){print "$1";}' $path_to_the_output_folder/kmergenie_results_report.html`
genome_size_estimate=`perl -ne 'if($_=~/Predicted assembly size: (\d+)/){print "$1";}' $path_to_the_output_folder/kmergenie_results_report.html`

echo "Before the assembly, the genome size is preliminary estimated as "$genome_size_estimate" bp" >>$path_to_the_output_folder/logfile.txt
#echo "The optimal k-mer size for the assembly from short reads is "$optimal_kmer_length" bp" >>$path_to_the_output_folder/logfile.txt

#First, I need to estimate different parameters required for the assembly.

#calculating the total length of short reads.
total_length_of_short_reads_R1=`perl $path_to_the_folder_with_galyp/Additional_scripts/calculate_total_read_length.pl $path_to_short_reads_R1`
total_length_of_short_reads_R2=`perl $path_to_the_folder_with_galyp/Additional_scripts/calculate_total_read_length.pl $path_to_short_reads_R2`
total_length_of_short_reads=`perl -e "print ($total_length_of_short_reads_R1+$total_length_of_short_reads_R2);"`

coverage_by_short_reads=`perl -e "print int((10*$total_length_of_short_reads/$genome_size_estimate)+0.5)/10;"` #coverage of the genome by long reads. Rounded to the first number after the dot.
echo "The estimated coverage by short reads is "$coverage_by_short_reads >>$path_to_the_output_folder/logfile.txt


#Calculating the total length of long reads.
echo "Executing perl $path_to_the_folder_with_galyp/Additional_scripts/calculate_total_read_length.pl $path_to_long_reads"
total_length_of_long_reads=`perl $path_to_the_folder_with_galyp/Additional_scripts/calculate_total_read_length.pl $path_to_long_reads`
echo "Total length of long reads is "$total_length_of_long_reads

coverage_by_long_reads=`perl -e "print int((10*$total_length_of_long_reads/$genome_size_estimate)+0.5)/10;"` #coverage of the genome by short reads. Rounded to the first number after the dot.
echo "The estimated coverage by long reads is "$coverage_by_long_reads >>$path_to_the_output_folder/logfile.txt


if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute == 1" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder/kmergenie_results_report.html ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 1 of Galyp. Check that all input parameters of Galyp are correct. Also, you might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi
fi

if (( $(echo "$number_of_the_last_step_in_the_pipeline_to_execute == 1" | bc -l) ))
then
	echo "" >>$path_to_the_output_folder/logfile.txt
	echo "Galyp executed step "$number_of_the_last_step_in_the_pipeline_to_execute" and finished, as directed by the user." >>$path_to_the_output_folder/logfile.txt
	exit
fi



#######################################
#Step 2. Assemble the genome from short reads using Minia.

#Printing to the logfile.
echo "" >>$path_to_the_output_folder/logfile.txt
current_date_and_time=`date`
echo "Step 2. Galyp started to assemble the genome using short reads. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt


if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 2" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	#The amount of gigabytes of RAM that I give Minia is max(40*$genome_size_estimate,40). Based on its manual, I suppose it will be enough.
	amount_of_RAM_to_be_used_by_minia_in_megabytes=`perl -e "if($genome_size_estimate>1000000000){print(int(40*$genome_size_estimate/1000000));}else{print '40000';}"`
	
	/usr/bin/time -v $path_to_the_folder_with_galyp/Additional_programs/minia -in $path_to_the_output_folder/list_of_paths_to_files_with_short_reads.txt -traversal contig -kmer-size $optimal_kmer_length -abundance-min 2 -max-memory $amount_of_RAM_to_be_used_by_minia_in_megabytes -out-tmp $path_to_the_output_folder -out $path_to_the_output_folder/minia -nb-cores $number_of_cpu_threads_to_use
fi	


if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 2" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder"/minia.contigs.fa" ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 2 of Galyp. You might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi
fi

if (( $(echo "$number_of_the_last_step_in_the_pipeline_to_execute == 2" | bc -l) ))
then
	echo "" >>$path_to_the_output_folder/logfile.txt
	echo "Galyp executed step "$number_of_the_last_step_in_the_pipeline_to_execute" and finished, as directed by the user." >>$path_to_the_output_folder/logfile.txt
	exit
fi



#######################################
#Step 3. Assemble the genome by DBG2OLC using the genome assembly created by Minia and long reads.

#Printing to the logfile.
echo "" >>$path_to_the_output_folder/logfile.txt
current_date_and_time=`date`
echo "Step 3. Galyp started to assemble the genome using both long and short reads. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt

#if the coverage by long reads is larger then 30, I downsample the long reads to make coverage 30 , taking the longest among the long reads during downsampling.
if (( $(echo "$coverage_by_long_reads > 30" | bc -l) ))
then
	echo "The estimated coverage by long reads is larger than 30, hence Galyp downsamples reads, taking the longest reads that provide coverage 30. The downsampled reads are used only for DBG2OLC assembly. In all other steps that require long reads, like polishing, all long reads will be utilized. Long reads are downsampled at this step because, in my experience, too high coverage by long reads may be detrimental for DBG2OLC assembly." >>$path_to_the_output_folder/logfile.txt
	if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 3" | bc -l) )) #To save time, I do this only if the user didn't indicate that this step should be skipped
	then
		python3 $path_to_the_folder_with_galyp/Additional_scripts/downsample__taking_longest_reads.py $path_to_long_reads_in_fasta $genome_size_estimate 30 $path_to_the_output_folder/long_reads_to_be_used_by_DBG2OLC.fasta
	fi
	coverage_by_long_reads_used_for_DBG2OLC_assembly=30
else #if the total coverage by long reads is smaller than 30, DBG2OLC will use all long reads.
	ln -s $path_to_long_reads_in_fasta $path_to_the_output_folder/long_reads_to_be_used_by_DBG2OLC.fasta
	coverage_by_long_reads_used_for_DBG2OLC_assembly=$coverage_by_long_reads
fi


#calculating the total length of Minia contigs.
total_length_of_minia_contigs=`perl $path_to_the_folder_with_galyp/Additional_scripts/calculate_total_read_length.pl $path_to_the_output_folder"/minia.contigs.fa"`
echo "The total length of Minia contigs is "$total_length_of_minia_contigs" bp" >>$path_to_the_output_folder/logfile.txt

#calculating N50 of Minia contigs. I don't consider Minia contigs shorter than 1000 bp, because they may originate from contamination, misassemblies and, probably, some other problematic sources.
n50_of_minia_contigs=`perl $path_to_the_folder_with_galyp/Additional_scripts/calculate_n50_for_sequences_longer_than_or_equal_to_1kbp.pl $path_to_the_output_folder"/minia.contigs.fa"`
echo "N50 of Minia contigs (counting only contigs longer than or equal 1000 bp) is "$n50_of_minia_contigs" bp" >>$path_to_the_output_folder/logfile.txt

#calculating N50 of those long reads that Galyp will use for assembly.
n50_of_long_reads_that_will_be_used_by_DBG2OLC=`perl $path_to_the_folder_with_galyp/Additional_scripts/calculate_n50.pl $path_to_the_output_folder/long_reads_to_be_used_by_DBG2OLC.fasta`
#echo "N50 of long reads is "$n50_of_long_reads" bp" >>$path_to_the_output_folder/logfile.txt

#Now calculating parameters for DBG2OLC, optimal for the assembly. I do this approximately in accordance with the manual of DBG2OLC.
if (( $(echo "$coverage_by_long_reads_used_for_DBG2OLC_assembly < 10" | bc -l) )) #If the coverage by long reads is less than 10, I set the minimum values from the manual of DBG2OLC. Comparing numbers as suggested in https://stackoverflow.com/questions/11237794/how-to-compare-two-decimal-numbers-in-bash-awk
then
	KmerCovTh=2
	MinOverlap=10
	AdaptiveTh=0.001
	RemoveChimera=0
	ChimeraTh=1
	ContigCovTh=1
elif (( $(echo "$coverage_by_long_reads_used_for_DBG2OLC_assembly > 100" | bc -l) )) #If the coverage by long reads is more than 100, I set the maximum values from the manual of DBG2OLC, except for ChimeraTh and ContigCovTh - they will grow linearly with the long read coverage. Since I downsample to 30, this condition is currently useless - but, possibly, in the future I'll allow users to change the coverage of downsampling, or to turn the downsampling off.
then
	KmerCovTh=10
	MinOverlap=150
	AdaptiveTh=0.02
	RemoveChimera=1
	ChimeraTh=`perl -e "print (1+int($coverage_by_long_reads_used_for_DBG2OLC_assembly/100));"`
	ContigCovTh=`perl -e "print (1+int($coverage_by_long_reads_used_for_DBG2OLC_assembly/100));"`
else #if the coverage by long reads is between 10 and 100, I use intermediate values for the parameters.
	KmerCovTh=`perl -e "print int((8*$coverage_by_long_reads_used_for_DBG2OLC_assembly/90)+(10/9)+0.5);"`
	MinOverlap=`perl -e "print int((14*$coverage_by_long_reads_used_for_DBG2OLC_assembly/9)-(50/9)+0.5);"`
	AdaptiveTh=`perl -e "print int(10000*((0.019*$coverage_by_long_reads_used_for_DBG2OLC_assembly/90)-(0.01/9)))/10000;"`
	RemoveChimera=1
	ChimeraTh=1
	ContigCovTh=1
fi

#Now, if $n50_of_minia_contigs is larger than $n50_of_long_reads_that_will_be_used_by_DBG2OLC, I divide AdaptiveTh by ($n50_of_minia_contigs/$n50_of_long_reads_that_will_be_used_by_DBG2OLC). This is because if the Minia contigs are very long, it would be hard for long reads to cover them entirely and, hence, AdaptiveTh should be adjusted.
if (( $(echo "$n50_of_minia_contigs > $n50_of_long_reads_that_will_be_used_by_DBG2OLC" | bc -l) ))
then
	AdaptiveTh=`perl -e "print ($AdaptiveTh/($n50_of_minia_contigs/$n50_of_long_reads_that_will_be_used_by_DBG2OLC));"`
fi

#Adjusting KmerCovTh, MinOverlap and AdaptiveTh for error rate and strictness. Probability of existence of an error-free 17-mer is (1-error_rate)**17. I assume that the parameters of DBG2OLC recommended by its author suit for an error rate of 0.1 (10%). 
coefficient_for_parameter_correction_by_error_rate=`perl -e "print (((1-$error_rate_in_long_reads)**17)/((1-0.1)**17));"`
KmerCovTh=`perl -e "print int($strictness_of_the_assembly_process*$coefficient_for_parameter_correction_by_error_rate*$KmerCovTh+0.5);"`
MinOverlap=`perl -e "print int($strictness_of_the_assembly_process*$coefficient_for_parameter_correction_by_error_rate*$MinOverlap+0.5);"`
AdaptiveTh=`perl -e "print ($strictness_of_the_assembly_process*$coefficient_for_parameter_correction_by_error_rate*$AdaptiveTh);"`
#Adjusting ChimeraTh and ContigCovTh for strictness.
ChimeraTh=`perl -e "print int($strictness_of_the_assembly_process*$ChimeraTh+0.5);"`
ContigCovTh=`perl -e "print int($strictness_of_the_assembly_process*$ContigCovTh+0.5);"`

#I prevent KmerCovTh from becoming smaller than 2 and MinOverlap from becoming smaller than 10.
KmerCovTh=`perl -e "if($KmerCovTh>=2){print $KmerCovTh;}else{print '2';};"`
MinOverlap=`perl -e "if($MinOverlap>=10){print $MinOverlap;}else{print '10';};"`

echo "Running DBG2OLC assembly with options k 17 AdaptiveTh "$AdaptiveTh" KmerCovTh "$KmerCovTh" MinOverlap "$MinOverlap" RemoveChimera "$RemoveChimera" ChimeraTh "$ChimeraTh" ContigCovTh "$ContigCovTh" Contigs "$path_to_the_output_folder"/minia.contigs.fa f " >>$path_to_the_output_folder/logfile.txt

if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 3" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	cd $path_to_the_output_folder
	/usr/bin/time -v $path_to_the_folder_with_galyp/Additional_programs/DBG2OLC k 17 AdaptiveTh $AdaptiveTh KmerCovTh $KmerCovTh MinOverlap $MinOverlap RemoveChimera $RemoveChimera ChimeraTh $ChimeraTh ContigCovTh $ContigCovTh Contigs $path_to_the_output_folder/minia.contigs.fa f $path_to_the_output_folder/long_reads_to_be_used_by_DBG2OLC.fasta
	cd $path_to_the_folder_from_which_Galyp_was_run
	
	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder"/backbone_raw.fasta" ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 3 of Galyp. You might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi
fi	

if (( $(echo "$number_of_the_last_step_in_the_pipeline_to_execute == 3" | bc -l) ))
then
	echo "" >>$path_to_the_output_folder/logfile.txt
	echo "Galyp executed step "$number_of_the_last_step_in_the_pipeline_to_execute" and finished, as directed by the user." >>$path_to_the_output_folder/logfile.txt
	exit
fi



#######################################
#Step 4. Polishing by Sparc.

#Printing to the logfile.
echo "" >>$path_to_the_output_folder/logfile.txt
current_date_and_time=`date`
echo "Step 4. Galyp started to polish contigs with Sparc. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt

if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 4" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	cd $path_to_the_output_folder #Sparc writes its logs to the folder from where it has been run, so I temporarily go into the folder $path_to_the_output_folder
	
	#removing the previous folder of Sparc results, if it exists.
	if [ -d "./Sparc_folder_for_consensus_calculation" ]
	then
		rm -rf ./Sparc_folder_for_consensus_calculation
	fi
	
	#concatenating Minia contigs and long reads in one file.
	cat $path_to_the_output_folder/minia.contigs.fa $path_to_the_output_folder/long_reads_to_be_used_by_DBG2OLC.fasta > $path_to_the_output_folder/minia_contigs_and_long_reads_together.fasta
	mkdir $path_to_the_output_folder/Sparc_folder_for_consensus_calculation
	bash $path_to_the_folder_with_galyp/Additional_scripts/Sparc_scripts/split_and_run_sparc__modified.sh $path_to_the_output_folder/backbone_raw.fasta $path_to_the_output_folder/DBG2OLC_Consensus_info.txt $path_to_the_output_folder/minia_contigs_and_long_reads_together.fasta $path_to_the_output_folder/Sparc_folder_for_consensus_calculation 2 $number_of_cpu_threads_to_use $path_to_the_folder_with_galyp >cns_log.txt
	
	cd $path_to_the_folder_from_which_Galyp_was_run
	
	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder"/Sparc_folder_for_consensus_calculation/final_assembly.fasta" ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 4 of Galyp. You might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi
fi

if (( $(echo "$number_of_the_last_step_in_the_pipeline_to_execute == 4" | bc -l) ))
then
	echo "" >>$path_to_the_output_folder/logfile.txt
	echo "Galyp executed step "$number_of_the_last_step_in_the_pipeline_to_execute" and finished, as directed by the user." >>$path_to_the_output_folder/logfile.txt
	exit
fi



#######################################
#Step 5. Polishing by HyPo.

#Printing to the logfile.
echo "" >>$path_to_the_output_folder/logfile.txt
current_date_and_time=`date`
echo "Step 5. Galyp started to polish contigs with HyPo. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt

if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 5" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	
	cd $path_to_the_output_folder
	#removing the previous $path_to_the_output_folder/aux folder created by KMC. I'm not sure, but probably it can affect KMC results at this step.
	if [ -d "./aux" ]
	then
		rm -rf ./aux
	fi
	
	#mapping short reads to contigs
	minimap2 -ax sr -t $number_of_cpu_threads_to_use $path_to_the_output_folder/Sparc_folder_for_consensus_calculation/final_assembly.fasta $path_to_short_reads_R1 $path_to_short_reads_R2 > $path_to_the_output_folder/illumina_reads_mapping__step_5.sam

	samtools view --threads $number_of_cpu_threads_to_use -Sbh $path_to_the_output_folder/illumina_reads_mapping__step_5.sam >$path_to_the_output_folder/illumina_reads_mapping__step_5.bam
	samtools sort --threads $number_of_cpu_threads_to_use -T $path_to_the_output_folder $path_to_the_output_folder/illumina_reads_mapping__step_5.bam >$path_to_the_output_folder/illumina_reads_mapping__step_5.sorted.bam
	samtools index $path_to_the_output_folder/illumina_reads_mapping__step_5.sorted.bam

	#mapping long reads with the parameters provided at the GitHub page of HyPo.
	minimap2 -x map-ont -a --MD --sam-hit-only -o $path_to_the_output_folder/long_reads_mapping__step_5.sam -t $number_of_cpu_threads_to_use $path_to_the_output_folder/Sparc_folder_for_consensus_calculation/final_assembly.fasta $path_to_long_reads
	samtools view --threads $number_of_cpu_threads_to_use -Sbh $path_to_the_output_folder/long_reads_mapping__step_5.sam >$path_to_the_output_folder/long_reads_mapping__step_5.bam
	samtools sort --threads $number_of_cpu_threads_to_use -T $path_to_the_output_folder $path_to_the_output_folder/long_reads_mapping__step_5.bam >$path_to_the_output_folder/long_reads_mapping__step_5.sorted.bam
	samtools index $path_to_the_output_folder/long_reads_mapping__step_5.sorted.bam

	/usr/bin/time -v hypo --reads-short @$path_to_the_output_folder/list_of_paths_to_files_with_short_reads.txt --draft $path_to_the_output_folder/Sparc_folder_for_consensus_calculation/final_assembly.fasta --bam-sr $path_to_the_output_folder/illumina_reads_mapping__step_5.sorted.bam --coverage-short $coverage_by_short_reads --size-ref $genome_size_estimate --bam-lr $path_to_the_output_folder/long_reads_mapping__step_5.sorted.bam --threads $number_of_cpu_threads_to_use --output $path_to_the_output_folder/polished_contigs__step_5.fasta --kind-sr sr --processing-size 120

	cd $path_to_the_folder_from_which_Galyp_was_run
	
	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder"/polished_contigs__step_5.fasta" ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 5 of Galyp. You might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi
	
	#to save space on disk, I remove sam- and bam- files
	rm -rf $path_to_the_output_folder/*.sam
	rm -rf $path_to_the_output_folder/*.bam
	rm -rf $path_to_the_output_folder/*.bam.bai
fi

if (( $(echo "$number_of_the_last_step_in_the_pipeline_to_execute == 5" | bc -l) ))
then
	echo "" >>$path_to_the_output_folder/logfile.txt
	echo "Galyp executed step "$number_of_the_last_step_in_the_pipeline_to_execute" and finished, as directed by the user." >>$path_to_the_output_folder/logfile.txt
	exit
fi

#########################################
#Step 6. Removal of haplotypic duplication.

#Printing to the logfile.
echo "" >>$path_to_the_output_folder/logfile.txt
current_date_and_time=`date`
echo "Step 6. Galyp started to remove haplotypic duplication. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt

if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 6" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	#making a config file
	#I use only long reads because the author of purge_dups indicates in the manual of purge_dups that he didn't test it with short reads.
	echo $path_to_long_reads >$path_to_the_output_folder/file_with_the_path_to_long_reads.txt
	
	cd $path_to_the_output_folder
	#removing the previous $path_to_the_output_folder/aux folder created by KMC. I'm not sure, but probably it can affect KMC results at this step.
	if [ -d "./aux" ]
	then
		rm -rf ./aux
	fi

	#removing the previous folder of purge_dups, if it exists.
	if [ -d "./Purge_dups__output_folder" ]
	then
		rm -rf ./Purge_dups__output_folder
	fi

	#removing the previous soft link "contigs_after_removal_of_haplotypic_duplication__step6.fa", if it exists.
	if [ -L "./contigs_after_removal_of_haplotypic_duplication__step6.fa" ]
	then
		rm ./contigs_after_removal_of_haplotypic_duplication__step6.fa
	fi
	
	pd_config.py $path_to_the_output_folder/polished_contigs__step_5.fasta $path_to_the_output_folder/file_with_the_path_to_long_reads.txt

	#I remove the config file created by purge_dups and make my own file, based on the prototype file $path_to_the_folder_with_galyp/Additional_scripts/purge_dups_config_prototype.json.
	#Purge_dups will always use 40 Gb of RAM.
	#I don't change the taxon name because it doesn't matter for what I do.
	rm -f $path_to_the_output_folder/config.json
	cp $path_to_the_folder_with_galyp/Additional_scripts/purge_dups_config_prototype.json $path_to_the_output_folder/config.json
	#replacing the number of threads to be used
	find $path_to_the_output_folder/config.json -type f -print0 | xargs -0 sed -i "s/HERE_INSERT_THE_NUMBER_OF_CPU_THREADS/$number_of_cpu_threads_to_use/g"
	
	path_to_purge_dups_binaries=`type -P purge_dups | perl -ne '$_=~s/purge_dups$//; print $_;'` #path to the "bin" folder of purge_dups
	
	/usr/bin/time -v run_purge_dups.py --platform bash config.json $path_to_purge_dups_binaries Some_title
	cd $path_to_the_folder_from_which_Galyp_was_run

	ln -s $path_to_the_output_folder/Purge_dups__output_folder/seqs/*.purged.fa $path_to_the_output_folder/contigs_after_removal_of_haplotypic_duplication__step6.fa
	
	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder"/contigs_after_removal_of_haplotypic_duplication__step6.fa" ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 6 of Galyp. You might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi
	
	#to save space on disk, I remove sam- and bam- files
	rm -rf $path_to_the_output_folder/*.sam
	rm -rf $path_to_the_output_folder/*.bam
	rm -rf $path_to_the_output_folder/*.bam.bai
fi

if (( $(echo "$number_of_the_last_step_in_the_pipeline_to_execute == 6" | bc -l) ))
then
	echo "" >>$path_to_the_output_folder/logfile.txt
	echo "Galyp executed step "$number_of_the_last_step_in_the_pipeline_to_execute" and finished, as directed by the user." >>$path_to_the_output_folder/logfile.txt
	exit
fi



#########################################
#Step 7. Polishing after removal of haplotypic duplication.

#Printing to the logfile.
echo "" >>$path_to_the_output_folder/logfile.txt
current_date_and_time=`date`
echo "Step 7. Galyp started to polish contigs with HyPo after removal of haplotypic duplication. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt

if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 8" | bc -l) )) #if the user didn't indicate that this step should be skipped
then

	cd $path_to_the_output_folder
	#removing the previous $path_to_the_output_folder/aux folder created by KMC. I'm not sure, but probably it can affect KMC results at this step.
	if [ -d "./aux" ]
	then
		rm -rf ./aux
	fi
	
	#mapping short reads to contigs
	minimap2 -ax sr -t $number_of_cpu_threads_to_use $path_to_the_output_folder/contigs_after_removal_of_haplotypic_duplication__step6.fa $path_to_short_reads_R1 $path_to_short_reads_R2 > $path_to_the_output_folder/illumina_reads_mapping__step_7.sam

	samtools view --threads $number_of_cpu_threads_to_use -Sbh $path_to_the_output_folder/illumina_reads_mapping__step_7.sam >$path_to_the_output_folder/illumina_reads_mapping__step_7.bam
	samtools sort --threads $number_of_cpu_threads_to_use -T $path_to_the_output_folder $path_to_the_output_folder/illumina_reads_mapping__step_7.bam >$path_to_the_output_folder/illumina_reads_mapping__step_7.sorted.bam
	samtools index $path_to_the_output_folder/illumina_reads_mapping__step_7.sorted.bam

	#mapping long reads with the parameters provided at the GitHub page of HyPo.
	minimap2 -x map-ont -a --MD --sam-hit-only -o $path_to_the_output_folder/long_reads_mapping__step_7.sam -t $number_of_cpu_threads_to_use $path_to_the_output_folder/contigs_after_removal_of_haplotypic_duplication__step6.fa $path_to_long_reads
	samtools view --threads $number_of_cpu_threads_to_use -Sbh $path_to_the_output_folder/long_reads_mapping__step_7.sam >$path_to_the_output_folder/long_reads_mapping__step_7.bam
	samtools sort --threads $number_of_cpu_threads_to_use -T $path_to_the_output_folder $path_to_the_output_folder/long_reads_mapping__step_7.bam >$path_to_the_output_folder/long_reads_mapping__step_7.sorted.bam
	samtools index $path_to_the_output_folder/long_reads_mapping__step_7.sorted.bam

	/usr/bin/time -v hypo --reads-short @$path_to_the_output_folder/list_of_paths_to_files_with_short_reads.txt --draft $path_to_the_output_folder/contigs_after_removal_of_haplotypic_duplication__step6.fa --bam-sr $path_to_the_output_folder/illumina_reads_mapping__step_7.sorted.bam --coverage-short $coverage_by_short_reads --size-ref $genome_size_estimate --bam-lr $path_to_the_output_folder/long_reads_mapping__step_7.sorted.bam --threads $number_of_cpu_threads_to_use --output $path_to_the_output_folder/polished_contigs__step_7.fasta --kind-sr sr --processing-size 120
	
	cd $path_to_the_folder_from_which_Galyp_was_run
	
	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder"/polished_contigs__step_7.fasta" ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 7 of Galyp. You might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi

	#to save space on disk, I remove sam- and bam- files
	rm -rf $path_to_the_output_folder/*.sam
	rm -rf $path_to_the_output_folder/*.bam
	rm -rf $path_to_the_output_folder/*.bam.bai
fi



if (( $(echo "$number_of_the_last_step_in_the_pipeline_to_execute == 8" | bc -l) ))
then
	echo "" >>$path_to_the_output_folder/logfile.txt
	echo "Galyp executed step "$number_of_the_last_step_in_the_pipeline_to_execute" and finished, as directed by the user." >>$path_to_the_output_folder/logfile.txt
	exit
fi




#########################################
#Step 8. Removal of contigs shorter than 1000 bp.

#Printing to the logfile.
echo "" >>$path_to_the_output_folder/logfile.txt
current_date_and_time=`date`
echo "Step 8. Galyp started to remove short contigs. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt

if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 8" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	perl $path_to_the_folder_with_galyp/Additional_scripts/extract_contigs_longer_than_or_equal_to.pl $path_to_the_output_folder/polished_contigs__step_7.fasta 1000 >$path_to_the_output_folder/polished_contigs__minlen_1000bp__step_8.fasta

	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder"/polished_contigs__minlen_1000bp__step_8.fasta" ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 8 of Galyp. You might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi
fi

if (( $(echo "$number_of_the_last_step_in_the_pipeline_to_execute == 8" | bc -l) ))
then
	echo "" >>$path_to_the_output_folder/logfile.txt
	echo "Galyp executed step "$number_of_the_last_step_in_the_pipeline_to_execute" and finished, as directed by the user." >>$path_to_the_output_folder/logfile.txt
	exit
fi



#########################################
#Step 9. Making contig titles more informative

#Printing to the logfile.
echo "" >>$path_to_the_output_folder/logfile.txt
current_date_and_time=`date`
echo "Step 9. Galyp started to change contig titles. "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
echo "" >>$path_to_the_output_folder/logfile.txt

if (( $(echo "$number_of_the_first_step_in_the_pipeline_to_execute <= 9" | bc -l) )) #if the user didn't indicate that this step should be skipped
then
	
	cd $path_to_the_output_folder
	
	#mapping short reads
	minimap2 -ax sr -t $number_of_cpu_threads_to_use $path_to_the_output_folder/polished_contigs__minlen_1000bp__step_8.fasta $path_to_short_reads_R1 $path_to_short_reads_R2 > $path_to_the_output_folder/illumina_reads_mapping__step_9.sam
	samtools view --threads $number_of_cpu_threads_to_use -Sbh $path_to_the_output_folder/illumina_reads_mapping__step_9.sam >$path_to_the_output_folder/illumina_reads_mapping__step_9.bam
	samtools sort --threads $number_of_cpu_threads_to_use -T $path_to_the_output_folder $path_to_the_output_folder/illumina_reads_mapping__step_9.bam >$path_to_the_output_folder/illumina_reads_mapping__step_9.sorted.bam
	samtools index $path_to_the_output_folder/illumina_reads_mapping__step_9.sorted.bam

	#mapping long reads
	minimap2 -x map-ont -a --MD --sam-hit-only -o $path_to_the_output_folder/long_reads_mapping__step_9.sam -t $number_of_cpu_threads_to_use $path_to_the_output_folder/polished_contigs__minlen_1000bp__step_8.fasta $path_to_long_reads
	samtools view --threads $number_of_cpu_threads_to_use -Sbh $path_to_the_output_folder/long_reads_mapping__step_9.sam >$path_to_the_output_folder/long_reads_mapping__step_9.bam
	samtools sort --threads $number_of_cpu_threads_to_use -T $path_to_the_output_folder $path_to_the_output_folder/long_reads_mapping__step_9.bam >$path_to_the_output_folder/long_reads_mapping__step_9.sorted.bam
	samtools index $path_to_the_output_folder/long_reads_mapping__step_9.sorted.bam

	#merging two bam files
	samtools merge --threads $number_of_cpu_threads_to_use $path_to_the_output_folder/merged_mappings_of_illumina_and_long_reads__step_9.bam $path_to_the_output_folder/illumina_reads_mapping__step_9.sorted.bam $path_to_the_output_folder/long_reads_mapping__step_9.sorted.bam
	samtools sort --threads $number_of_cpu_threads_to_use -T $path_to_the_output_folder  $path_to_the_output_folder/merged_mappings_of_illumina_and_long_reads__step_9.bam >$path_to_the_output_folder/merged_mappings_of_illumina_and_long_reads__step_9.sorted.bam
	samtools index $path_to_the_output_folder/merged_mappings_of_illumina_and_long_reads__step_9.sorted.bam

	/usr/bin/time -v perl $path_to_the_folder_with_galyp/Additional_scripts/add_real_coverage_to_contigs_by_a_given_bam_file.pl $path_to_the_output_folder/polished_contigs__minlen_1000bp__step_8.fasta $path_to_the_output_folder/contigs.fasta $number_of_cpu_threads_to_use $path_to_the_folder_with_galyp $path_to_the_output_folder/merged_mappings_of_illumina_and_long_reads__step_9.sorted.bam
	
	cd $path_to_the_folder_from_which_Galyp_was_run
	
	#checking if this step finished successfully. "-s" means that file exists and has a non-zero size.
	if [ ! -s $path_to_the_output_folder"/contigs.fasta" ]
	then
		echo "" >>$path_to_the_output_folder/logfile.txt
		echo "There was a problem at Step 9 of Galyp. You might want to examine the standard output and the standard error output of Galyp to identify the source of the problem." >>$path_to_the_output_folder/logfile.txt
		exit
	fi
fi

#to save space on disk, I remove sam- and bam- files
rm -rf $path_to_the_output_folder/*.sam
rm -rf $path_to_the_output_folder/*.bam
rm -rf $path_to_the_output_folder/*.bam.bai

echo "" >>$path_to_the_output_folder/logfile.txt
echo "Galyp finished. See contigs.fasta in "$path_to_the_output_folder" . "$current_date_and_time >>$path_to_the_output_folder/logfile.txt
