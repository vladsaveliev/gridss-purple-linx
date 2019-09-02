#!/bin/bash

data_dir=colo829/
normal_bam=$data_dir/COLO829R_dedup.realigned.bam
tumour_bam=$data_dir/COLO829T_dedup.realigned.bam
refdata=refdata/hg19
CMD=$(echo docker run \
	--ulimit nofile=$(ulimit -Hn):$(ulimit -Hn) \
	-v $refdata:/refdata \
	-v $data_dir:/data/ \
	gridss/gridss-purple-linx:latest \
	-n /data/COLO829R_dedup.realigned.bam \
	-t /data/COLO829T_dedup.realigned.bam \
	-v /data/COLO829v003T.somatic_caller_post_processed.vcf.gz \
	-s colo829
)
echo $CMD

docker run --ulimit nofile=100000:100000 -v d:/dev/gridss-purple-linx/refdata/hg19:/refdata -v d:/colo829:/data/ gridss/gridss-purple-linx:latest -n /data/COLO829R_dedup.realigned.bam -t /data/COLO829T_dedup.realigned.bam -v /data/COLO829v003T.somatic_caller_post_processed.vcf.gz -s colo829
docker run -it --entrypoint /bin/bash --ulimit nofile=100000:100000 -v d:/dev/gridss-purple-linx/refdata/hg19:/refdata -v d:/colo829:/data/ gridss/gridss-purple-linx:latest

# from command line
export AMBER_VERSION=2.5
export COBALT_VERSION=1.7
export PURPLE_VERSION=2.33
export LINX_VERSION=1.3
export GRIDSS_JAR=/opt/gridss/gridss-2.5.2-gridss-jar-with-dependencies.jar
export AMBER_JAR=/opt/hmftools/amber-${AMBER_VERSION}-jar-with-dependencies.jar
export COBALT_JAR=/opt/hmftools/count-bam-lines-${COBALT_VERSION}-jar-with-dependencies.jar 
export PURPLE_JAR=/opt/hmftools/purity-ploidy-estimator-${PURPLE_VERSION}-jar-with-dependencies.jar
export LINX_JAR=/opt/hmftools/sv-linx-${LINX_VERSION}-jar-with-dependencies.jar
./gridss-purple-linx.sh -n /data/COLO829R_dedup.realigned.bam -t /data/COLO829T_dedup.realigned.bam -v /data/COLO829v003T.somatic_caller_post_processed.vcf.gz -s colo829
