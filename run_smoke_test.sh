#!/bin/bash

ln -s $PWD/package/gridss /opt/gridss
./gridss-purple-linx.sh

docker run --ulimit nofile=100000:100000 \
	-v d:/refdata/hg19:/refdata \
	-v d:/hartwig/smoke:/data/ \
	gridss/gridss-purple-linx:latest \
	-n /data/CPCT12345678/CPCT12345678R/aligner/CPCT12345678R.bam \
	-t /data/CPCT12345678/CPCT12345678T/aligner/CPCT12345678T.bam \
	-v /data/smoketest.vcf \
	-s smoketest \
	--snvvcf /data/COLO829v003T.somatic_caller_post_processed.vcf.gz \
	--jvmheap 15g \
	
