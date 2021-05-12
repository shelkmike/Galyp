#!/usr/bin/env bash
<<COMMENT
This script was modified by Mikhail Schelkunov. Compared to the original script, it doesn't always use 64 threads, but takes the number of threads as input. Also, it takes as the input parameter the path to the folder with the galyp.sh file.
COMMENT

###
# USAGE: ./split_and_run_sparc.sh [BACKBONE_FASTA] [CONSENSUS_FASTA] [READS_FASTA] [OUTPUT_DIR] [ITERATIONS] [THREADS] [PATH_TO_THE_FOLDER_WITH_GALYP]###

backbone_fasta=$1
consensus_fasta=$2
reads_fasta=$3
split_dir=$4
iterations=$5
number_of_cpu_threads_to_use=$6
path_to_the_folder_with_galyp=$7


#clean the directory first
find ${split_dir} -name "backbone-*" -delete

python2 $path_to_the_folder_with_galyp/Additional_scripts/Sparc_scripts/split_reads_by_backbone_readdict.py -b ${backbone_fasta} -o ${split_dir} -r ${reads_fasta} -c ${consensus_fasta}

for file in $(find ${split_dir} -name "*.reads.fasta"); do
    chunk=`basename $file .reads.fasta`

    cmd=""
    for iter in `seq 1 ${iterations}`; do

        #echo $iter

        cmd+="blasr --nproc $number_of_cpu_threads_to_use ${split_dir}/${chunk}.reads.fasta ${split_dir}/${chunk}.fasta --bestn 1 -m 5 --minMatch 19 --out ${split_dir}/${chunk}.mapped.m5; "

        cmd+="${path_to_the_folder_with_galyp}/Additional_programs/Sparc m ${split_dir}/${chunk}.mapped.m5 b ${split_dir}/${chunk}.fasta k 1 c 2 g 1 HQ_Prefix Contig boost 5 t 0.2 o ${split_dir}/${chunk}; "

        if [[ ${iter} -lt ${iterations} ]]
        then
        #rename
        cmd+="mv ${split_dir}/${chunk}.consensus.fasta ${split_dir}/${chunk}.fasta;"
        fi

    done

    echo $cmd
    eval $cmd


    #to save space
    cmd="rm ${split_dir}/${chunk}.mapped.m5"
    echo $cmd
    eval $cmd
    cmd="rm ${split_dir}/${chunk}.reads.fasta"
    echo $cmd
    eval $cmd

done

for confile in $(find ${split_dir} -name "*.consensus.fasta"); do
	cmd="cat ${confile};"
	eval $cmd
done > ${split_dir}/final_assembly.fasta
