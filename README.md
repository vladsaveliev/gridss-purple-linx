
# GRIDSS PURPLE LINX

The GRIDSS/PURPLE/LINX toolkit takes a pair of match tumour/normal BAM files, and performs somatic genomic rearrangement detection and classificatiion.

- GRIDSS: performs structural variant calling
- PURPLE: performs allele specific copy number calling
- LINX: performs event classification, and visualisation

The simplest way to run the toolkit is through the docker image

# Prerequisites

The prerequities for running the toolkit depend on whether it is run directly, or through the docker image.
If you are using to docker image, only the reference data is required.

### Reference data

The toolkit requires multiple reference data sets. These have been packaged into a single download.

|reference genome | download location |
|---|---|
|hg19|https://resources.hartwigmedicalfoundation.nl/HMFTools-Resources%2FGRIDSS-Purple-Linx-Docker/gridss-purple-linx-docker-image-refdata-hg19.tar.gz|

### External software (local installation)

The following software is required to run to toolkit if installing locally:

- GRIDSS PURPLE LINX toolkit
  - A combined package is downloadable from https://github.com/hartwigmedical/gridss-purple-linx/releases
- java 8
- R 3.6.1
- bwa
- samtools
- sambamba
- circos (including all dependencies and Perl packages)

#### R CRAN packages
- tidyverse
- assertthat
- testthat
- NMF
- randomForest
- stringdist
- stringr
- argparser
- R.cache
- BiocManager
- Rcpp
- blob
- RSQLite
- cowplot
- magick

#### R BioConductor packages

- copynumber
- StructuralVariantAnnotation
- VariantAnnotation
- rtracklayer
- BSgenome
- Rsamtools
- biomaRt
- Gviz
- org.Hs.eg.db

Also required are the `TxDb` and `BSGenome` package for your reference genome

- TxDb.Hsapiens.UCSC.hg19.knownGene
- TxDb.Hsapiens.UCSC.hg38.knownGene
- BSgenome.Hsapiens.UCSC.hg19
  - This package is included in the hg19 reference data package
- BSgenome.Hsapiens.UCSC.hg38

# Command line arguments

The driver script can be found in the `gridss-purple-linx/gridss-purple-linx.sh` directory of the release package.
When running from docker, this is the docker image entry point.

## Required arguments

The following command-line arguments are required:

|Argument|Description|
|---|---|
|--tumour_bam|tumour BAM file|
|--normal_bam|matched normal BAM file|
|--sample|sample name|
|--snvvcf|A somatic SNV VCF with the AD genotype field populated. |
|--nosnvvcf|Indicates a somatic SNV VCF will not be supplied.|

Note that only one of Only one of `--snvvcf` or `--nosnvvcf` should be specified. As not supplying a somatic SNV VCF results reduces PURPLE performance, this file must be explicitly omitted via `--nosnvvcf`.

## Optional arguments

The driver script has many optional arguments.
The default values match those required to run the Docker image using the hg19 reference data.
The docker image assumes the output directory is `/data`, and the reference data package is located in `/refdata`

|Argument|Description|Default|
|---|---|---|
|--output_dir|output directory|/data/|
|--threads|number of threads to use.|number of cores available|
|--normal_sample|sample name of matched normal| ${sample}_N|
|--tumour_sample|sample name of tumour. Must match the somatic --snvvcf sample name.|${sample}_T |
|--jvmheap|maximum java heap size for high-memory steps|25g|
|--ref_dir|path to decompressed reference data package.|/refdata|

#### Reference data paths

These reference data paths are all relative to `--ref_dir`.
The default values match those required of the hg19 reference data.

|Argument|Description|Default|
|--reference|reference genome|refgenomes/Homo_sapiens.GRCh37.GATK.illumina/Homo_sapiens.GRCh37.GATK.illumina.fasta|
|--repeatmasker|repeatmasker .fa.out file for reference genome|refgenomes/dbs/repeatmasker/hg19.fa.out|
|--blacklist|Blacklisted regions|dbs/gridss/ENCFF001TDO.bed|
|--bafsnps|bed file of het SNP locations used by amber.|dbs/germline_het_pon_hg19/GermlineHetPon.hg19.bed|
|--gcprofile|.cnp file of GC in reference genome. 1k bins|dbs/gc/GC_profile.1000bp.cnp|
|--gridsspon|GRIDSS PON|dbs/gridss/pon3792v1|
|--viralreference|viral reference database (fasta format)|refgenomes/human_virus/human_virus.fa|
|--rlib|R library path that include correct BSgenome package|rli)|
|--viral_hosts_csv|viral contig to name lookup|dbs/sv/viral_host_ref.csv|
|--fusion_pairs_csv|known driver gene fusions|dbs/knowledgebases/output/knownFusionPairs.csv|
|--promiscuous_five_csv|known promiscuous gene fusions |dbs/knowledgebases/output/knownPromiscuousFive.csv|
|--promiscuous_three_csv|known promiscuous gene fusions|dbs/knowledgebases/output/knownPromiscuousThree.csv|
|--fragile_sites|known fragile sites|dbs/sv/fragile_sites_hmf.csv|
|--line_elements|known LINE donor sites|dbs/sv/line_elements.csv|
|--replication_origins|replication timing BED file|dbs/sv/heli_rep_origins.bed|
|--ensembl_data_dir|ensemble data cache|dbs/ensembl_data_cache|
|--install_dir|root directory of gridss-purple-linx release package|/opt/|


## Docker image
Docker image

This simplest way to run the pipeline is through the docker image.

# 
