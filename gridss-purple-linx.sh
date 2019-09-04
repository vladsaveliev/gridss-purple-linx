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

run_dir="/data"
ref_dir="/refdata"
tumour_bam=""
normal_bam=""
snvvcf=""
threads=$(nproc)
sample=""
cleanup="y"
jvmheap="25g"
referencename="hg19"
rlib=$ref_dir/rlib/
ref_genome=$ref_dir/refgenomes/Homo_sapiens.GRCh37.GATK.illumina/Homo_sapiens.GRCh37.GATK.illumina.fasta
viralreference=$ref_dir/refgenomes/human_virus/human_virus.fa
blacklist=$ref_dir/dbs/gridss/ENCFF001TDO.bed
repeatmasker=$ref_dir/dbs/repeatmasker/hg19.fa.out
bafsnps=$ref_dir/dbs/germline_het_pon_hg19/GermlineHetPon.hg19.bed
gcprofile=$ref_dir/dbs/gc/GC_profile.1000bp.cnp
gridsspon=$ref_dir/dbs/gridss/pon3792v1
# LINX data files
viral_hosts_csv=$ref_dir/dbs/sv/viral_host_ref.csv
fusion_pairs_csv=$ref_dir/dbs/knowledgebases/output/knownFusionPairs.csv
promiscuous_five_csv=$ref_dir/dbs/knowledgebases/output/knownPromiscuousFive.csv
promiscuous_three_csv=$ref_dir/dbs/knowledgebases/output/knownPromiscuousThree.csv
fragile_sites=$ref_dir/dbs/sv/fragile_sites_hmf.csv
line_elements=$ref_dir/dbs/sv/line_elements.csv
replication_origins=$ref_dir/dbs/sv/heli_rep_origins.bed
ensembl_data_dir=$ref_dir/dbs/ensembl_data_cache

OPTIONS=v:o:t:n:s:r:b:
LONGOPTS=snvvcf,output_dir:tumour_bam:,normal_bam:,sample:,threads:,jvmheap:,ref_dir:,reference:,repeatmasker:,blacklist:,bafsnps:,gcprofile:,gridsspon:,viralreference:,referencename:,rundir:,viral_hosts_csv:,fusion_pairs_csv:,promiscuous_five_csv:,promiscuous_three_csv:,fragile_sites:,line_elements:,replication_origins:,ensembl_data_dir:
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
	# e.g. return value is 1
	#  then getopt has complained about wrong arguments to stdout
	exit 2
fi
eval set -- "$PARSED"
while true; do
	case "$1" in
		--viral_hosts_csv)
			viral_hosts_csv="$2"
			shift 2
			;;
		--fusion_pairs_csv)
			fusion_pairs_csv="$2"
			shift 2
			;;
		--promiscuous_five_csv)
			promiscuous_five_csv="$2"
			shift 2
			;;
		--promiscuous_three_csv)
			promiscuous_three_csv="$2"
			shift 2
			;;
		--fragile_sites)
			fragile_sites="$2"
			shift 2
			;;
		--line_elements)
			line_elements="$2"
			shift 2
			;;
		--replication_origins)
			replication_origins="$2"
			shift 2
			;;
		--ensembl_data_dir)
			ensembl_data_dir="$2"
			shift 2
			;;
		--rundir)
			run_dir="$2"
			shift 2
			;;
		-v|--snvvcf)
			snvvcf="$2"
			shift 2
			;;
		--viralreference)
			viralreference="$2"
			shift 2
			;;
		--referencename)
			referencename="$2"
			shift 2
			;;
		-b|--blacklist)
			blacklist="$2"
			shift 2
			;;
		--bafsnps)
			bafsnps="$2"
			shift 2
			;;
		--gcprofile)
			gcprofile="$2"
			shift 2
			;;
		--gridsspon)
			gridsspon="$2"
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
usage() {
	echo "Usage: gridss-purple-linx.sh" 1>&2
	echo "" 1>&2
	echo "Required command line arguments:" 1>&2
	echo "	--output_dir: output directory." 1>&2
	echo "	--tumour_bam: tumour BAM file" 1>&2
	echo "	--normal_bam: matched normal BAM file" 1>&2
	echo "	--sample: sample name" 1>&2
	echo "Optional parameters:" 1>&2
	echo "	--rundir: (default: /data)" 1>&2
	echo "	--snvvcf: A somatic SNV VCF with the AD genotype field populated." 1>&2
	echo "	--threads: number of threads to use. Defaults to the number of cores available." 1>&2
	echo "	--jvmheap: maximum java heap size for high-memory steps" 1>&2
	echo "	--ref_dir: path to decompressed reference data package. (default: /refdata)" 1>&2
	echo "	--reference: reference genome (default: /refdata/refgenomes/Homo_sapiens.GRCh37.GATK.illumina/Homo_sapiens.GRCh37.GATK.illumina.fasta)" 1>&2
	echo "	--repeatmasker: repeatmasker .fa.out file for reference genome (default: /refdata/refgenomes/dbs/repeatmasker/hg19.fa.out)" 1>&2
	echo "	--blacklist: Blacklisted regions (default: /refdata/dbs/gridss/ENCFF001TDO.bed)" 1>&2
	echo "	--bafsnps: bed file of het SNP locations used by amber. (default: /refdata/dbs/germline_het_pon_hg19/GermlineHetPon.hg19.bed)" 1>&2
	echo "	--gcprofile: .cnp file of GC in reference genome. 1k bins (default: /refdata/dbs/gc/GC_profile.1000bp.cnp)." 1>&2
	echo "	--gridsspon: GRIDSS PON (default: /refdata/dbs/gridss/pon3792v1)" 1>&2
	echo "	--viralreference: viral reference database (fasta format) (default: /refdata/refgenomes/human_virus/human_virus.fa)" 1>&2
	echo "	--rlib: R library path that include correct BSgenome package (default: /refdata/rlib)" 1>&2
	echo "	--viral_hosts_csv: viral contig to name lookup (default: /refdata/dbs/sv/viral_host_ref.csv)" 1>&2
	echo "	--fusion_pairs_csv: known driver gene fusions (default: /refdata/dbs/knowledgebases/output/knownFusionPairs.csv)" 1>&2
	echo "	--promiscuous_five_csv: known promiscuous gene fusions (default: /refdata/dbs/knowledgebases/output/knownPromiscuousFive.csv)" 1>&2
	echo "	--promiscuous_three_csv: known promiscuous gene fusions (default: /refdata/dbs/knowledgebases/output/knownPromiscuousThree.csv)" 1>&2
	echo "	--fragile_sites: known fragile sites (default: /refdata/dbs/sv/fragile_sites_hmf.csv)" 1>&2
	echo "	--line_elements: known LINE donor sites (default: /refdata/dbs/sv/line_elements.csv)" 1>&2
	echo "	--replication_origins: replication timing BED file (default: /refdata/dbs/sv/heli_rep_origins.bed)" 1>&2
	echo "	--ensembl_data_dir: ensemble data cache (default: /refdata/dbs/ensembl_data_cache)" 1>&2
	echo "" 1>&2
	exit 1
}

# $1: variable containing filename
# $2: command line argument name
assert_file_exists() {
	if [[ ! -f "$1" ]] ; then
		echo "File $1 not found. Specify using the environment variant --$2" 1>&2
		exit 1
	fi
}
assert_directory_exists() {
	if [[ ! -d "$1" ]] ; then
		echo "Directory $1 not found. Specify using the environment variant --$2" 1>&2
		echo "${!env_name}"
		exit 1
	fi
}
if [[ ! -z "$snvvcf" ]] ; then
	assert_file_exists $snvvcf "snvvcf"
fi
assert_file_exists $ref_genome "reference"
assert_file_exists $repeatmasker "repeatmasker"
assert_file_exists $gcprofile "gcprofile"
assert_file_exists $blacklist "blacklist"
assert_file_exists $viralreference "viralreference"
assert_directory_exists $gridsspon "gridsspon"


if [[ ! -f "$snvvcf" ]] ; then
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
export R_LIBS="$rlib:${R_LIBS:-}"

joint_sample_name=$sample
normal_sample=${sample}_N
tumour_sample=${sample}_T

base_path=$(dirname $(readlink $0 || echo $0))
### Find the jars
find_jar() {
	env_name=$1
	if [[ -f "${!env_name:-}" ]] ; then
		echo "${!env_name}"
	#elif find /opt/ -naame "$2*-jar-with-dependencies.jar" 2>&1 >/dev/null ]] ; then
	#	echo "find /opt/ -naame "$2*-jar-with-dependencies.jar"
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
gridss_decompressed_rmann_vcf=$gridss_dir/tmp.rmann.${joint_sample_name}.gridss.vcf
gridss_somatic_full_vcf=$gridss_dir/${tumour_sample}.gridss.full.somatic.vcf.gz
gridss_somatic_vcf=$gridss_dir/${tumour_sample}.gridss.somatic.vcf.gz
if [[ ! -f $gridss_raw_vcf ]] ; then
	/opt/gridss/gridss.sh \
		-b $blacklist \
		-r $ref_genome \
		-o $gridss_raw_vcf \
		-a $assembly_bam \
		-w $gridss_dir \
		-j $gridss_jar \
		-t $threads \
		$normal_bam \
		$tumour_bam 2>&1 | tee $log_prefix/gridss.log
else
	echo "Found $gridss_raw_vcf, skipping GRIDSS" 
fi
if [[ ! -f $gridss_raw_vcf ]] ; then
	echo "Error creating $gridss_raw_vcf. Aborting" 1>&2
	exit 1
fi
if [[ ! -f $gridss_somatic_vcf ]] ; then
	if [[ ! -f $gridss_decompressed_rmann_vcf ]] ; then
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
				REFERENCE_SEQUENCE=$viralreference \
				INPUT=$gridss_refann_vcf \
				OUTPUT=$gridss_virann_vcf \
				WORKER_THREADS=$threads \
				2>&1 | tee -a $log_prefix.gridss.AnnotateUntemplatedSequence.viral.log
		fi
		# workaround for https://github.com/Bioconductor/VariantAnnotation/issues/19
		rm -f $gridss_decompressed_vcf
		gunzip -c $gridss_virann_vcf | awk ' { if (length($0) >= 4000) { gsub(":0.00:", ":0.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000:")} ; print $0  } ' > $gridss_decompressed_vcf
		Rscript /opt/gridss/gridss_annotate_insertions_repeatmaster.R \
			--input $gridss_decompressed_vcf \
			--output $gridss_decompressed_rmann_vcf \
			--repeatmasker $repeatmasker \
			--scriptdir /opt/gridss/  \
			2>&1 | tee -a $log_prefix.gridss.repeatannotate.log
		if [[ -f $gridss_decompressed_rmann_vcf.bgz ]] ; then
			gunzip -c $gridss_decompressed_rmann_vcf.bgz  | awk ' { if (length($0) >= 4000) { gsub(":0.00:", ":0.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000:")} ; print $0  } ' > $gridss_decompressed_rmann_vcf
		fi
	fi
	Rscript /opt/gridss/gridss_somatic_filter.R \
		-p ${gridsspon} \
		-i $gridss_decompressed_rmann_vcf \
		-o ${gridss_somatic_vcf} \
		-f ${gridss_somatic_full_vcf} \
		-r BSgenome.Hsapiens.UCSC.$referencename \
		-s /opt/gridss/ \
		--gc \
		2>&1 | tee -a $log_prefix.gridss.somatic_filter.log
	if [[ $cleanup == "y" ]] ; then
		rm $gridss_dir/tmp.* 2>/dev/null
	fi
	mv ${gridss_somatic_vcf/.gz/.bgz} ${gridss_somatic_vcf}
	mv ${gridss_somatic_vcf/.gz/.bgz}.tbi ${gridss_somatic_vcf}.tbi
	mv ${gridss_somatic_full_vcf/.gz/.bgz} ${gridss_somatic_full_vcf}
	mv ${gridss_somatic_full_vcf/.gz/.bgz}.tbi ${gridss_somatic_full_vcf}.tbi
else
	echo "Found $gridss_somatic_vcf, skipping GRIDSS post-processing" 
fi
if [[ ! -f $gridss_somatic_vcf ]] ; then
	echo "Error creating $gridss_somatic_vcf. Aborting" 1>&2
	exit 1
fi
echo ############################################
echo # Running Amber
echo ############################################
mkdir -p $run_dir/amber
if [[ ! -f $run_dir/amber/$tumour_sample.amber.baf.vcf.gz ]] ; then
	java -Xmx10G $jvm_args \
		-jar $amber_jar \
		-threads $threads \
		-tumor $tumour_sample \
		-reference $normal_sample \
		-tumor_bam $tumour_bam \
		-reference_bam $normal_bam \
		-bed $bafsnps \
		-ref_genome $ref_genome \
		-output_dir $run_dir/amber 2>&1 | tee $log_prefix.amber.log
else
	echo "Found $run_dir/amber/$tumour_sample.amber.baf.vcf.gz. Skipping amber." 1>&2
fi
if [[ ! -f $run_dir/amber/$tumour_sample.amber.baf.vcf.gz ]] ; then
	echo "Error running amber. Aborting" 2>&1
	exit 1
fi

echo ############################################
echo # Running Cobalt
echo ############################################
mkdir -p $run_dir/cobalt
if [[ ! -f $run_dir/cobalt/$tumour_sample.cobalt.ratio.pcf ]] ; then
	java -Xmx10G $jvm_args \
		-cp $cobalt_jar \
		com.hartwig.hmftools.cobalt.CountBamLinesApplication \
		-threads $threads \
		-reference $normal_sample \
		-reference_bam $normal_bam \
		-tumor $tumour_sample \
		-tumor_bam $tumour_bam \
		-output_dir $run_dir/cobalt \
		-gc_profile $gcprofile \
		2>&1 | tee $log_prefix.cobalt.log
else
	echo "Found $run_dir/cobalt/$tumour_sample.cobalt.ratio.pcf. Skipping cobalt." 1>&2
fi
if [[ ! -f $run_dir/cobalt/$tumour_sample.cobalt.ratio.pcf ]] ; then
	echo "Error running cobalt. Aborting" 2>&1
	exit 1
fi
	
#if [[ $cleanup == "y" ]] ; then
#	rm -f $run_dir/cobalt/*.pcf1 $run_dir/cobalt/*.ratio $run_dir/cobalt/*.ratio.gc $run_dir/cobalt/*.count
#fi

echo ############################################
echo # Running PURPLE
echo ############################################
mkdir -p $run_dir/purple

# circos requires /home/$LOGNAME to exist
if [[ -z "${LOGNAME:-}" ]] ; then
	export LOGNAME=$(whoami)
	mkdir -p /home/$LOGNAME
fi

if [[ ! -f $run_dir/purple/$tumour_sample.purple.sv.vcf.gz ]] ; then
	if [[ -f "$snvvcf" ]] ; then
		java -Dorg.jooq.no-logo=true -Xmx10G $jvm_args \
			-jar ${purple_jar} \
			-output_dir $run_dir/purple \
			-reference $normal_sample \
			-tumor $tumour_sample \
			-amber $run_dir/amber \
			-cobalt $run_dir/cobalt \
			-gc_profile $gcprofile \
			-ref_genome $ref_genome \
			-structural_vcf $gridss_somatic_vcf \
			-sv_recovery_vcf $gridss_somatic_full_vcf \
			-circos circos \
			-somatic_vcf $snvvcf
	else
		java -Dorg.jooq.no-logo=true -Xmx10G $jvm_args \
			-jar ${purple_jar} \
			-output_dir $run_dir/purple \
			-reference $normal_sample \
			-tumor $tumour_sample \
			-amber $run_dir/amber \
			-cobalt $run_dir/cobalt \
			-gc_profile $gcprofile \
			-ref_genome $ref_genome \
			-structural_vcf $gridss_somatic_vcf \
			-sv_recovery_vcf $gridss_somatic_full_vcf \
			-circos circos
	fi
else
	echo "Found $run_dir/purple/$tumour_sample.purple.sv.vcf.gz. Skipping purple." 1>&2
fi

echo ############################################
echo # Running Linx
echo ############################################
mkdir -p $run_dir/linx
java -Xmx8G -Xms4G -jar $LINX_JAR \
	-sample $joint_sample_name \
	-purple_dir $run_dir/purple \
	-output_dir $run_dir/linx \
	-fragile_site_file ${fragile_sites} \
	-line_element_file ${line_elements} \
	-replication_origins_file ${replication_origins} \
	-viral_hosts_file ${viral_hosts_csv} \
	-gene_transcripts_dir ${ensembl_data_dir} \
	-check_fusions \
	-fusion_pairs_csv ${fusion_pairs_csv} \
	-promiscuous_five_csv ${promiscuous_five_csv} \
	-promiscuous_three_csv ${promiscuous_three_csv} \
	-write_vis_data \
	-proximity_distance 5000 \
	-chaining_sv_limit 0

































