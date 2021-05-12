#!/usr/bin/env python3
# coding=utf-8

"""
The script make a file with contig titles and contig lengths separated by semicolons

Пример запуска:
python3 /mnt/lustre/shelkmike/Work/Scripts/make_a_list_of_contig_lengths.py input.fasta list_of_contigs_with_their_lengths.csv
"""

import sys
import os
import re

f_infile=open(sys.argv[1],"r")
f_outfile=open(sys.argv[2],"w")

#сначала загружаю входной FASTA-файл в словарь, в котором ключ - заголовок контига без ">", а значение - последовательность.
d_fasta_sequence_title_to_sequence={}
s_title_of_the_current_sequence="" #заголовок последовательности, на которую я сейчас смотрю.
for s_line in f_infile:
	if re.search(r"^>(.+)",s_line):
		o_regular_expression_results=re.search(r"^>(.+)",s_line)
		s_title_of_the_current_sequence=o_regular_expression_results.group(1)
		#удаляю символ переноса строки
		s_title_of_the_current_sequence.rstrip('\n')
	elif re.search(r"^(.+)",s_line): #если это не строка с заголовком, то считаю, что строка с последовательностью
		o_regular_expression_results=re.search(r"^(.+)",s_line)
		#если для этого контига последовательность ещё не инициализирована, то инициализирую её
		if s_title_of_the_current_sequence not in d_fasta_sequence_title_to_sequence:
			d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence]=""
		d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence]+=o_regular_expression_results.group(1)
		#удаляю всякие пробельные символы, в том числе символ переноса строки.
		d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence]=re.sub(r"\s","",d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence])
        
#иду по всем контигам и считаю их длины
for s_title_of_the_current_sequence in d_fasta_sequence_title_to_sequence:
    f_outfile.write(s_title_of_the_current_sequence+";"+str(len(d_fasta_sequence_title_to_sequence[s_title_of_the_current_sequence]))+"\n")