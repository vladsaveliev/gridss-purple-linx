#!/bin/bash

# Local system locations
install_dir=~/gridss-purple-linx
ref_data=~/refdata
data_dir=~/smoke_test

GRIDSS_VERSION=2.6.2
AMBER_VERSION=2.5
COBALT_VERSION=1.7
PURPLE_VERSION=2.34
LINX_VERSION=1.4

export GRIDSS_JAR=$install_dir/gridss/gridss-${GRIDSS_VERSION}-gridss-jar-with-dependencies.jar
export AMBER_JAR=$install_dir/hmftools/amber-${AMBER_VERSION}.jar
export COBALT_JAR=$install_dir/hmftools/cobalt-${COBALT_VERSION}.jar 
export PURPLE_JAR=$install_dir/hmftools/purple-${PURPLE_VERSION}.jar
export LINX_JAR=$install_dir/hmftools/sv-linx_${LINX_VERSION}.jar

$install_dir/gridss-purple-linx/gridss-purple-linx.sh \
	-o $data_dir \
	-n $data_dir/CPCT12345678R.bam \
	-t $data_dir/CPCT12345678T.bam  \
	-v $data_dir/CPCT12345678T.somatic_caller_post_processed.vcf.gz \
	--snvvcf $data_dir/CPCT12345678T.somatic_caller_post_processed.vcf.gz \
	-s CPCT12345678 \
	--normal_sample CPCT12345678R \
	--tumour_sample CPCT12345678T \
	--ref_dir $ref_data \
	--install_dir $install_dir \
	
