#!/bin/bash
docker run --ulimit nofile=100000:100000 \
	-v s:/refdata/hg19:/refdata \
	-v d:/dev/gridss-purple-linx/colo829_smoke:/data/ \
	gridss/gridss-purple-linx:latest \
	-n /data/COLO829R_smoke.bam \
	-t /data/COLO829T_smoke.bam \
	-v /data/smoketest.vcf \
	--normal_sample colo829_R \
	--tumour_sample colo829_T \
	--snvvcf /data/COLO829v003T.somatic_caller_post_processed.vcf.gz \
	--jvmheap 15g \