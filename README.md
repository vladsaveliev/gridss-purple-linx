
# GRIDSS/PURPLE/LINX toolkit

The GRIDSS/PURPLE/LINX toolkit takes a pair of match tumour/normal BAM files, and performs somatic genomic rearrangement detection and classificatiion.

- GRIDSS: performs structural variant calling
- PURPLE: performs allele specific copy number calling
- LINX: performs event classification, and visualisation

The simplest way to run the toolkit is through the docker image

# Prerequisites (local installation)

The prerequities for running the toolkit depend on whether it is run directly, or through the docker image.
If you are using to docker image, only docker is required.
If not, the following external software is required to run to toolkit:

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
- BSgenome.Hsapiens.UCSC.hg38

#### GRIDSS

GRIDSS can be downloaded from https://github.com/PapenfussLab/gridss/releases. All release files (except the source code) are required:

- gridss-`GRIDSS_VERSION`-gridss-jar-with-dependencies.jar
- gridss.sh
- gridss.config.R
- gridss_annotate_insertions_repeatmaster.R
- gridss_somatic_filter.R
- libgridss.R

#### PUPRLE/LINX

PURPLE and LINX can be downloaded from https://github.com/hartwigmedical/hmftools/releases. The following release artefacts are required:

- amber-`AMBER_VERSION`.jar
- cobalt-`COBALT_VERSION`.jar
- purple-`PURPLE_VERSION`.jar
- sv-linx_`LINX_VERSION`.jar


# Docker image

This simplest way to run the pipeline is through the docker image.

# Command line arguments
