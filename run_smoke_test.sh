#!/bin/bash

# Local system locations
install_dir=~/dev/gridss-purple-linx/package
ref_data=~/refdata/hg19
data_dir=$install_dir/../smoke_test

rm -r $data_dir/amber $data_dir/cobalt $data_dir/gridss $data_dir/logs $data_dir/purple

GRIDSS_VERSION=$(grep "GRIDSS_VERSION=" ../gridss/Dockerfile | cut -d "=" -f 2)
AMBER_VERSION=$(grep "AMBER_VERSION=" Dockerfile | cut -d "=" -f 2)
COBALT_VERSION=$(grep "COBALT_VERSION=" Dockerfile | cut -d "=" -f 2)
PURPLE_VERSION=$(grep "PURPLE_VERSION=" Dockerfile | cut -d "=" -f 2)
LINX_VERSION=$(grep "LINX_VERSION=" Dockerfile | cut -d "=" -f 2)

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
	
