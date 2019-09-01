#!/bin/bash
#
# Stand-alone GRIDSS-PURPLE-Linx pipeline
#
# Example: ./gridss-purple-linx.sh -n /data/COLO829R_dedup.realigned.bam -t /data/COLO829T_dedup.realigned.bam -v /data/colo829snv.vcf.gz -s colo829 -v /data/COLO829v003T.somatic_caller_post_processed.vcf.gz
# docker run  gridss/gridss-purple-linx

set -o errexit -o pipefail -o noclobber -o nounset
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
	echo '`getopt --test` failed in this environment.'
	exit 1
fi

OPTIONS=v:o:t:n:s:r:b:
LONGOPTS=snvvcf,output_dir:tumour_bam:,normal_bam,sample,threads,jvmheap,ref_dir,reference,repeatmasker,blacklist,bafsnps,gcprofile,gridsspon:
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
	# e.g. return value is 1
	#  then getopt has complained about wrong arguments to stdout
	exit 2
fi
eval set -- "$PARSED"
run_dir="/data"
ref_dir="/refdata"
tumour_bam=""
normal_bam=""
snvindel_vcf=""
threads=$(nproc)
sample=""
cleanup="y"
jvmheap="25g"
ref_genome=$ref_dir/refgenomes/Homo_sapiens.GRCh37.GATK.illumina/Homo_sapiens.GRCh37.GATK.illumina.fasta
viral_ref_genome=$ref_dir/refgenomes/human_virus/human_virus.fa
encode_blacklist=$ref_dir/dbs/encode/ENCFF001TDO.bed
repeatmasker=$ref_dir/dbs/repeatmasker/hg19.fa.out
baf_snps=$ref_dir/dbs/amber/GermlineHetPon.hg19.bed
gc_profile=$ref_dir/dbs/gc/GC_profile.1000bp.cnp
gridss_pon=$ref_dir/dbs/gridss/pon3792v1
while true; do
	case "$1" in
		-v|--snvvcf)
			snvindel_vcf="$2"
			shift 2
			;;
		-b|--blacklist)
			encode_blacklist="$2"
			shift 2
			;;
		--bafsnps)
			baf_snps="$2"
			shift 2
			;;
		--gcprofile)
			gcprofile="$2"
			shift 2
			;;
		--gridsspon)
			gridss_pon="$2"
			shift 2
			;;
		-n|--normal_bam)
			normal_bam="$2"
			shift 2
			;;
		-o|--output_dir)
			run_dir="$2"
			shift 2
			;;
		-r|--reference)
			ref_genome="$2"
			shift 2
			;;
		-t|--tumour_bam)
			tumour_bam="$2"
			shift 2
			;;
		-s|--sample)
			sample="$2"
			shift 2
			;;
		--threads)
			threads=$(printf -v int '%d\n' "$2" 2>/dev/null)
			shift 2
			;;
		--repeatmasker)
			repeatmasker=$2
			shift 2
			;;
		--jvmheap)
			jvmheap="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			echo "Programming error"
			exit 3
			;;
	esac
done
if [[ ! -f "$snvindel_vcf" ]] ; then
	echo "Missing SNV VCF. A SNV VCF with the AD genotype field populated is required."
	echo "Use the script for generating this VCF with strelka if you have not already generated a compatible VCF."
	exit 1
fi
if [[ ! -f "$tumour_bam" ]] ; then
	echo "Missing tumour BAM"
	exit 1
fi
if [[ ! -f "$normal_bam" ]] ; then
	echo "Missing normal BAM"
	exit 1
fi
mkdir -p "$run_dir"
if [[ ! -d "$run_dir" ]] ; then
	echo "Unable to create $run_dir"
	exit 1
fi
if [[ ! -d "$ref_dir" ]] ; then
	echo "Could not find reference data directory $ref_dir"
	exit 1
fi
if [[ ! -f "$ref_genome" ]] ; then
	echo "Missing reference genome $ref_genome - specify with -r "
	exit 1
fi
if [[ -z "$sample" ]] ; then
	sample=$(basename $tumour_bam .bam)
fi
if [[ "$threads" -lt 1 ]] ; then
	echo "Illegal thread count: $threads"
	exit 1
fi

joint_sample_name=$sample
ref_sample=${sample}_N
tumor_sample=${sample}_T

base_path=$(dirname $(readlink $0 || echo $0))
### Find the jars
find_jar() {
	env_name=$1
	if [[ -f "${!env_name:-}" ]] ; then
		echo "${!env_name}"
	#elif ls -1 /jar/$2*-jar-with-dependencies.jar 2>&1 >/dev/null ]] ; then
	#	echo "$(ls -1 /jar/$2*-jar-with-dependencies.jar) 2>/dev/null"
	else
		echo "Unable to find $2 jar. Specify using the environment variant $env_name" 1>&2
		exit 1
	fi
}
gridss_jar=$(find_jar GRIDSS_JAR gridss)
amber_jar=$(find_jar AMBER_JAR amber)
cobalt_jar=$(find_jar COBALT_JAR cobalt)
purple_jar=$(find_jar PURPLE_JAR purple)
linx_jar=$(find_jar LINX_JAR sv-linx)

for program in bwa sambamba samtools circos Rscript java ; do
	if ! which $program > /dev/null ; then
		echo "Missing required dependency $program. $program must be on PATH"
		exit 1
	fi
done
for rpackage in tidyverse devtools assertthat testthat NMF stringdist stringr argparser R.cache "copynumber" StructuralVariantAnnotation "VariantAnnotation" "rtracklayer" "BSgenome" "org.Hs.eg.db" ; do
	if ! Rscript -e "installed.packages()" | grep $rpackage > /dev/null ; then
		echo "Missing R package $rpackage"
		exit 1
	fi
done

if ! java -Xms$jvmheap -cp $gridss_jar gridss.Echo ; then
	echo "Failure invoking java with --jvmheap parameter of \"$jvmheap\". Specify a JVM heap size (e.g. \"20g\") that is valid for this machine."
	exit 1
fi

mkdir -p $run_dir/logs $run_dir/gridss $run_dir/amber $run_dir/purple
log_prefix=$run_dir/logs/$(date +%Y%m%d_%H%M%S).$HOSTNAME.$$

jvm_args="
	-Dreference_fasta=$ref_genome \
	-Dsamjdk.use_async_io_read_samtools=true \
	-Dsamjdk.use_async_io_write_samtools=true \
	-Dsamjdk.use_async_io_write_tribble=true \
	-Dsamjdk.buffer_size=4194304"

echo ############################################
echo # Running GRIDSS
echo ############################################
gridss_dir=$run_dir/gridss
assembly_bam=$gridss_dir/$joint_sample_name.assembly.bam
gridss_raw_vcf=$gridss_dir/${joint_sample_name}.gridss.vcf.gz
gridss_refann_vcf=$gridss_dir/tmp.refann.${joint_sample_name}.gridss.vcf.gz
gridss_virann_vcf=$gridss_dir/tmp.refvirann.${joint_sample_name}.gridss.vcf.gz
gridss_decompressed_vcf=$gridss_dir/tmp.decompressed.${joint_sample_name}.gridss.vcf
gridss_somatic_full_vcf=$gridss_dir/${tumor_sample}.gridss.full.somatic.vcf.gz
gridss_somatic_vcf=$gridss_dir/${tumor_sample}.gridss.somatic.vcf.gz
if [[ ! -f $gridss_raw_vcf ]] ; then
	/scripts/gridss.sh \
		-b $encode_blacklist \
		-r $ref_genome \
		-o $gridss_raw_vcf \
		-a $assembly_bam \
		-w $gridss_dir \
		-j $gridss_jar \
		-t $threads \
		$normal_bam \
		$tumor_bam 2>&1 | tee $log_prefix/gridss.log
else
	echo "Found $gridss_raw_vcf, skipping GRIDSS" 
fi
if [[ ! -f $gridss_raw_vcf ]] ; then
	echo "Error creating $gridss_raw_vcf. Aborting" 2>&1
	exit 1
fi
if [[ ! -f $gridss_somatic_vcf ]] ; then
	if [[ ! -f $gridss_refann_vcf ]] ; then
	java -Xmx6g $jvm_args \
		-cp $gridss_jar \
		gridss.AnnotateUntemplatedSequence \
		REFERENCE_SEQUENCE=$ref_genome \
		INPUT=$gridss_raw_vcf \
		OUTPUT=$gridss_refann_vcf \
		WORKER_THREADS=$threads \
		2>&1 | tee -a $log_prefix.gridss.AnnotateUntemplatedSequence.human.log
	fi
	if [[ ! -f $gridss_virann_vcf ]] ; then
		# can't use $jvm_args since we're using a different reference
		java -Xmx6g \
			-Dsamjdk.create_index=false \
			-Dsamjdk.use_async_io_read_samtools=false \
			-Dsamjdk.use_async_io_write_samtools=false \
			-Dsamjdk.use_async_io_write_tribble=false \
			-Dsamjdk.buffer_size=4194304 \
			-cp $gridss_jar \
			gridss.AnnotateUntemplatedSequence \
			REFERENCE_SEQUENCE=$viral_ref_genome \
			INPUT=$gridss_refann_vcf \
			OUTPUT=$gridss_virann_vcf \
			WORKER_THREADS=$threads \
			2>&1 | tee -a $log_prefix.gridss.AnnotateUntemplatedSequence.viral.log
	fi
	# workaround for https://github.com/Bioconductor/VariantAnnotation/issues/19
	rm -f $gridss_decompressed_vcf
	gunzip -c $gridss_virann_vcf | awk ' { if (length($0) >= 4000) { gsub(":0.00:", ":0.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000:")} ; print $0  } ' > $gridss_decompressed_vcf
	Rscript /opt/gridss/gridss_somatic_filter.R \
		-p ${gridss_pon} \
		-i $gridss_decompressed_vcf \
		-o ${gridss_somatic_vcf} \
		-f ${gridss_somatic_full_vcf} \
		-s /opt/gridss/ \
		--gc \
		2>&1 | tee -a $log_prefix.gridss.somatic_filter.log
	if [[ $cleanup == "y" ]] ; then
		rm tmp.* 2>/dev/null
	fi
	mv ${gridss_somatic_vcf}.bgz ${gridss_somatic_vcf}.gz
	mv ${gridss_somatic_vcf}.bgz.tbi ${gridss_somatic_vcf}.gz.tbi
	mv ${gridss_somatic_full_vcf}.bgz ${gridss_somatic_full_vcf}.gz
	mv ${gridss_somatic_full_vcf}.bgz.tbi ${gridss_somatic_full_vcf}.gz.tbi
else
	echo "Found $gridss_somatic_vcf, skipping GRIDSS post-processing" 
fi
if [[ ! -f $gridss_somatic_vcf ]] ; then
	echo "Error creating $gridss_somatic_vcf. Aborting" 2>&1
	exit 1
fi
echo  $gridss_raw_vcf
exit 1
echo ############################################
echo # Running Amber
echo ############################################
mkdir -p $run_dir/amber
amber_pileup_N=$run_dir/amber/$normal_bam.amber.pileup
amber_pileup_T=$run_dir/amber/$tumor_sample.amber.pileup
amber_baf=$run_dir/amber/$joint_sample_name.amber.baf

sambamba mpileup \
	-t $threads \
	--tmpdir=$run_dir/amber \
	-L $baf_snps \
	$normal_bam \
	--samtools "-q 1 -f $ref_genome" > $amber_pileup_N

sambamba mpileup \
	-t $threads \
	--tmpdir=$run_dir/amber \
	-L $baf_snps \
	$tumor_bam \
	--samtools "-q 1 -f $ref_genome" > $amber_pileup_T

java -Xmx10G $jvm_args \
	-jar $amber_jar \
	-sample $joint_sample_name \
	-reference $amber_pileup_N \
	-tumor $amber_pileup_T \
	-output_dir $run_dir/amber

if [[ ! -f $amber_baf ]] ; then
	echo "Error creating $amber_baf. Aborting" 2>&1
	exit 1
fi

if [[ $cleanup == "y" ]] ; then
	rm $amber_pileup_N $amber_pileup_T $run_dir/amber/*.pcf1
fi

echo ############################################
echo # Running Cobalt
echo ############################################
mkdir -p $run_dir/cobalt
java -Xmx10G $jvm_args \
	-jar $cobalt_jar \
	-threads $threads \
	-reference $ref_sample \
	-reference_bam $normal_bam \
	-tumor $joint_sample_name \
	-tumor_bam $tumor_bam \
	-output_dir $run_dir/cobalt \
	-gc_profile $gc_profile \
	2>&1 | tee $log_prefix.cobalt.log

if [[ ! -f #TODO ]] ; then
	echo "Error creating $amber_baf. Aborting" 2>&1
fi

	
if [[ $cleanup == "y" ]] ; then
	rm -f $run_dir/cobalt/*.pcf1 $run_dir/cobalt/*.ratio $run_dir/cobalt/*.ratio.gc $run_dir/cobalt/*.count
fi

echo ############################################
echo # Running PURPLE
echo ############################################
purple_output=${run_dir}/purple

java -Dorg.jooq.no-logo=true $JVM_MEMORY_USAGE_ARGS \
	-jar ${purple_jar} \
	-somatic_vcf $somatic_vcf \
	-structural_vcf $gridss_somatic_vcf.gz \
	-circos circos \
	-run_dir ${run_dir} \
	-ref_genome hg19 \
	-cobalt $run_dir/cobalt \
	-output_dir ${purple_output} \
	-gc_profile ${gc_profile} \
	-sv_recovery_vcf $gridss_somatic_full_vcf.gz
purple_raw_vcf=$purple_output/????TODO????*.purple.sv.vcf.gz

echo ############################################
echo # Running repeatmasker annotation
echo ############################################
purple_annotated_vcf=${purple_raw_vcf/.purple.sv.vcf/.purple.ann.sv.vcf}

Rscript /opt/gridss/gridss_annotate_insertions_repeatmaster.R \
	--input $purple_raw_vcf.gz \
	--output $purple_annotated_vcf \
	--repeatmasker $repeatmasker \
	--scriptdir /opt/gridss/
mv ${purple_annotated_vcf}.bgz ${purple_annotated_vcf}.gz
mv ${purple_annotated_vcf}.bgz.tbi ${purple_annotated_vcf}.gz.tbi

echo ############################################
echo # Running Linx
echo ############################################






































