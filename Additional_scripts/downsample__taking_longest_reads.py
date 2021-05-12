#!/usr/bin/env python3
# coding=utf-8

"""
This script takes a FASTA (not FASTQ) file with reads and downsamples them to a given coverage, taking the longest reads during the downsampling process.


How to use:
python3 downsample__taking_longest_reads.py input_fasta genome_size target_coverage output_fasta
For example:
python3 downsample__taking_longest_reads.py long_reads.fasta 1000000000 30 long_reads_downsampled.fasta
"""

import sys
import os
import re

s_path_to_the_input_fasta_file=sys.argv[1]
n_genome_size=int(sys.argv[2])
n_target_coverage=int(sys.argv[3])
s_path_to_the_output_fasta_file=sys.argv[4]

#сначала загружаю входной FASTA-файл в словарь, в котором ключ - заголовок рида без ">", а значение - последовательность. Заодно составляю словарь, в котором ключ это заголовок рида без ">", а значение - длина рида.
d_fasta_sequence_title_to_sequence={}
d_fasta_sequence_title_to_sequence_length={}
f_input_fasta_file=open(s_path_to_the_input_fasta_file,"r")
s_title_of_the_current_sequence="" #заголовок последовательности, на которую я сейчас смотрю.
for s_line in f_input_fasta_file:
	if re.search(r"^>(.+)",s_line):
		o_regular_expression_results=re.search(r"^>(.+)",s_line)
		s_title_of_the_current_sequence=o_regular_expression_results.group(1)
		#удаляю символ переноса строки
		s_title_of_the_current_sequence.rstrip('\n')
	elif re.search(r"^(.+)",s_line): #если это не строка с заголовком, то считаю, что строка с последовательностью
		o_regular_expression_results=re.search(r"^(.+)",s_line)
		#если для этого рида последовательность ещё не инициализирована, то инициализирую её
		if s_title_of_the_current_sequence not in d_fasta_sequence_title_to_sequence:
			d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence]=""
		if s_title_of_the_current_sequence not in d_fasta_sequence_title_to_sequence_length:
			d_fasta_sequence_title_to_sequence_length[s_title_of_the_current_sequence]=0
			
		d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence]+=o_regular_expression_results.group(1)
		#удаляю всякие пробельные символы, в том числе символ переноса строки.
		d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence]=re.sub(r"\s","",d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence])
		d_fasta_sequence_title_to_sequence_length[s_title_of_the_current_sequence]=len(d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence])

#делаю список заголовков последовательностей в порядке убывания длины. Делаю это как написано на https://stackoverflow.com/questions/20577840/python-dictionary-sorting-in-descending-order-based-on-values/41866830
l_sequence_titles_sorted_in_the_order_of_descending_sequence_length = sorted(d_fasta_sequence_title_to_sequence_length, key=d_fasta_sequence_title_to_sequence_length.get, reverse=True)

#теперь печатаю в выходной файл самые длинные последовательности, обеспечивая заданное покрытие
f_output_fasta_file=open(s_path_to_the_output_fasta_file,"w")
n_total_length_of_sequences_already_printed=0 #сумма длин уже напечатанных последовательностей
for s_sequence_title in l_sequence_titles_sorted_in_the_order_of_descending_sequence_length:
	f_output_fasta_file.write(">"+s_sequence_title+"\n"+d_fasta_sequence_title_to_sequence[s_sequence_title]+"\n")
	n_total_length_of_sequences_already_printed+=d_fasta_sequence_title_to_sequence_length[s_sequence_title]
	if(n_total_length_of_sequences_already_printed>=n_genome_size*n_target_coverage):
		break






