![Logo of Galyp](https://gcf.fbb.msu.ru/shelkmike/Galyp_logo/galyp_logo.jpeg)

Galyp is a pipeline for *hybrid genome assembly*, which means an assembly that uses both short (Illumina) and long (Nanopore or PacBio) reads. Galyp was designed specifically to create relatively good assemblies when the *coverage by long reads is low*, like 10x-30x. Here are some assemblies made by Galyp:
<p align="center"><img src="https://gcf.fbb.msu.ru/shelkmike/Galyp_logo/table.png"></p>
</TABLE>

### The pipeline
Galyp takes as input *trimmed reads* and, after a series of operations, creates in the output folder a file *contigs.fasta*. Another file which may be of interest to a user is *logfile.txt*, which contains different information, for example the estimated genome size and read coverage.<br />
<p align="center"><img src="https://gcf.fbb.msu.ru/shelkmike/Galyp_logo/scheme.jpeg" width="50%"></p>

### Requirements
These programs should be available through $PATH:<br />
Python 3<br />
Python 2<br />
Perl<br />
[ABySS](https://github.com/bcgsc/abyss) (must be installed with Open MPI support turned on)<br />
[BLASR](https://github.com/PacificBiosciences/blasr)<br />
[Samtools](https://github.com/samtools/samtools)<br />
[Runner](https://github.com/dfguan/runner)<br />
[Purge_dups](https://github.com/dfguan/purge_dups)<br />
[Kmergenie](http://kmergenie.bx.psu.edu/)<br />
[Minimap2](https://github.com/lh3/minimap2)<br />
[HyPo](https://github.com/kensung-lab/hypo)<br />
The programs need to be installed with their dependencies. For example, the installation instructions for HyPo state that it requires KMC3.<br />

To check that all programs are correctly installed, you can assemble a *small dataset* provided with Galyp in the folder Test_dataset. Its assembly will take several minutes and should produce a file contigs.fasta which contains an approximately 30 kbp-long genome. If you don't see this file after the assembly, take a look into logfile.txt.<br /><br />

### How to run

Only *three* input parameters are mandatory:<br />
1\) --short_reads_R1 - the path to Illumina reads of the first end.<br />
2\) --short_reads_R2 - the path to Illumina reads of the second end.<br />
3\) --long_reads - the path to long reads.<br />

An exemplary command:<br />
`bash galyp.sh --short_reads_R1 illumina_R1_trimmed.fastq --short_reads_R2 illumina_R2_trimmed.fastq --long_reads nanopore_reads_trimmed.fastq`

To see a full list of parameters, run<br />
`bash galyp.sh --help`<br />
Other parameters include, for example, --threads (how many CPU threads to use) and --strictness (increase it if you want your assembly to be more fragmented but have less misassemblies).<br /><br />

### Frequently asked questions:
1\) How to *install* Galyp?<br />
Galyp does not require any installation. Just download the latest release from the [Releases](https://github.com/shelkmike/Galyp/releases) page on GitHub.<br />
2\) How much *RAM* does Galyp need?<br />
I recommend to use 500*genome_size. For example, for a 1 Gbp genome 500 Gb RAM are recommended. However, if you provide less RAM this doesn't necessarily mean that Galyp will crash.<br />
3\) Can Galyp be used when the coverage by long reads is *<10*?<br />
You can try it, but the assembly quality probably won't be awesome. However, it may be enough, depending on the purpose of your scientific study.<br />
4\) Galyp was designed to make relatively good assemblies when the coverage by long reads is low. But can it be used when the coverage is *high*?<br />
Yes. However, if the coverage by long reads is >30, I recommend to try also some long-read assemblers like [Flye](https://github.com/fenderglass/Flye).<br />
5\) How to *cite* Galyp?<br />
The paper about the nuclear genome of Fagopyrum esculentum subsp. ancestrale, for which Galyp was developed, is to be published soon.
