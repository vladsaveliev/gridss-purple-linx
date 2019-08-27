################## BASE IMAGE ######################

FROM ubuntu:18.04

################## METADATA ######################
LABEL base.image="ubuntu:18.04"
LABEL version="1"
LABEL software="GRIDSS PURPLE LINX"
LABEL software.version="1.0.0"
LABEL about.summary="GRIDSS PURPLE LINX somatic genomic rearrangement toolkit"
LABEL about.home="https://github.com/PapenfussLab/gridss"
LABEL about.tags="Genomics"

RUN echo "deb http://mirror.aarnet.edu.au/ubuntu/ bionic main restricted" > /etc/apt/sources.list
RUN echo "deb http://mirror.aarnet.edu.au/ubuntu/ bionic-security main restricted" >> /etc/apt/sources.list
RUN echo "deb http://mirror.aarnet.edu.au/ubuntu/ bionic-updates main restricted" >> /etc/apt/sources.list
RUN echo "deb http://mirror.aarnet.edu.au/ubuntu/ bionic universe multiverse" >> /etc/apt/sources.list
RUN echo "deb http://mirror.aarnet.edu.au/ubuntu/ bionic-security universe multiverse" >> /etc/apt/sources.list
RUN echo "deb http://mirror.aarnet.edu.au/ubuntu/ bionic-updates universe multiverse" >> /etc/apt/sources.list

# CRAN ubuntu package repository for the latest version of R
RUN apt-get install apt-transport-https software-properties-common
RUN gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN gpg -a --export E298A3A825C0D65DFD57CBB651716619E084DAB9 | apt-key add -
RUN add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/'

RUN apt-get update
RUN apt-get install openjdk-8-jre-headless samtools sambamba bwa build-essential make r-base libssl-dev libcurl4-openssl-dev libxml2-dev circos pkg-config libgd-dev

# circos perl packages
RUN cpan App::cpanminus
RUN cpanm List::MoreUtils Math::Bezier Math::Round Math::VecStat Params::Validate Readonly Regexp::Common SVG Set::IntSpan Statistics::Basic Text::Format Clone Config::General Font::TTF::Font GD

# R packages used by GRIDSS and PURPLE
RUN Rscript -e 'options(Ncpus=16L, repos="https://cloud.r-project.org/");install.packages(c("tidyverse", "devtools", "assertthat", "testthat", "NMF", "randomForest", "stringdist", "stringr", "argparser", "R.cache", "BiocManager", "Rcpp", "blob", "RSQLite"));BiocManager::install(ask=FALSE, pkgs=c("copynumber", "StructuralVariantAnnotation", "VariantAnnotation", "rtracklayer", "BSgenome", "Rsamtools", "biomaRt", "org.Hs.eg.db", "TxDb.Hsapiens.UCSC.hg19.knownGene", "TxDb.Hsapiens.UCSC.hg38.knownGene", "BSgenome.Hsapiens.UCSC.hg19", "BSgenome.Hsapiens.UCSC.hg38"))'

RUN mkdir /jar /scripts /data
COPY external/gridss/target/gridss-2.5.1-gridss-jar-with-dependencies.jar /jar/
COPY external/hmftools/amber/target/amber-2.5-jar-with-dependencies.jar /jar/
COPY external/hmftools/bachelor/target/bachelor-1.7-jar-with-dependencies.jar /jar/
COPY external/hmftools/purity-ploidy-estimator/target/purity-ploidy-estimator-2.33-jar-with-dependencies.jar /jar/
COPY external/hmftools/strelka-post-process/target/strelka-post-process-1.6-jar-with-dependencies.jar /jar/
COPY external/hmftools/sv-linx/target/sv-linx-1.3-jar-with-dependencies.jar /jar/
COPY external/gridss/scripts/gridss.sh /scripts/
COPY gridss-purple-linx.sh /scripts/

