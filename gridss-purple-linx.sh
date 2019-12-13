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

run_dir=/data
ref_dir=/refdata
install_dir=/opt/
tumour_bam=""
normal_bam=""
snvvcf=""
threads=$(nproc)
sample=""
normal_sample=""
tumour_sample=""
cleanup="y"
jvmheap="25g"
referencename="hg19"
rlib=rlib/
ref_genome=refgenomes/Homo_sapiens.GRCh37.GATK.illumina/Homo_sapiens.GRCh37.GATK.illumina.fasta
viralreference=refgenomes/human_virus/human_virus.fa
blacklist=dbs/gridss/ENCFF001TDO.bed
repeatmasker=dbs/repeatmasker/hg19.fa.out
bafsnps=dbs/germline_het_pon_hg19/GermlineHetPon.hg19.vcf.gz
gcprofile=dbs/gc/GC_profile.1000bp.cnp
gridsspon=dbs/gridss/pon3792v1
# LINX data files
viral_hosts_csv=dbs/sv/viral_host_ref.csv
fusion_pairs_csv=dbs/knowledgebases/output/knownFusionPairs.csv
promiscuous_five_csv=dbs/knowledgebases/output/knownPromiscuousFive.csv
promiscuous_three_csv=dbs/knowledgebases/output/knownPromiscuousThree.csv
fragile_sites=dbs/sv/fragile_sites_hmf.csv
line_elements=dbs/sv/line_elements.csv
replication_origins=dbs/sv/heli_rep_origins.bed
ensembl_data_dir=dbs/ensembl_data_cache
picardoptions=""
validation_stringency="STRICT"

usage() {
	echo "Usage: gridss-purple-linx.sh" 1>&2
	echo "" 1>&2
	echo "Required command line arguments:" 1>&2
	echo "	--tumour_bam: tumour BAM file" 1>&2
	echo "	--normal_bam: matched normal BAM file" 1>&2
	echo "	--sample: sample name" 1>&2
	echo "Optional parameters:" 1>&2
	echo "	--output_dir: output directory. (default: /data)" 1>&2
	echo "	--install_dir: root directory of gridss-purple-linx release (default: /opt/)" 1>&2
	echo "	--snvvcf: A somatic SNV VCF with the AD genotype field populated." 1>&2
	echo "	--nosnvvcf: Indicates a somatic SNV VCF will not be supplied. This will reduce the accuracy of PURPLE ASCN." 1>&2
	echo "	--threads: number of threads to use. (Default: number of cores available)" 1>&2
	echo "	--normal_sample: sample name of matched normal (Default: \${sample}_N) " 1>&2
	echo "	--tumour_sample: sample name of tumour. Must match the somatic \$snvvcf sample name. (Default: \${sample}_T) " 1>&2
	echo "	--jvmheap: maximum java heap size for high-memory steps (default: 25g)" 1>&2
	echo "	--ref_dir: path to decompressed reference data package. (default: /refdata)" 1>&2
	echo "	--reference: reference genome (default:refgenomes/Homo_sapiens.GRCh37.GATK.illumina/Homo_sapiens.GRCh37.GATK.illumina.fasta)" 1>&2
	echo "	--repeatmasker: repeatmasker .fa.out file for reference genome (default: refgenomes/dbs/repeatmasker/hg19.fa.out)" 1>&2
	echo "	--blacklist: Blacklisted regions (default:dbs/gridss/ENCFF001TDO.bed)" 1>&2
	echo "	--bafsnps: bed file of het SNP locations used by amber. (default: dbs/germline_het_pon_hg19/GermlineHetPon.hg19.bed)" 1>&2
	echo "	--gcprofile: .cnp file of GC in reference genome. 1k bins (default: dbs/gc/GC_profile.1000bp.cnp)." 1>&2
	echo "	--gridsspon: GRIDSS PON (default: dbs/gridss/pon3792v1)" 1>&2
	echo "	--viralreference: viral reference database (fasta format) (default: refgenomes/human_virus/human_virus.fa)" 1>&2
	echo "	--rlib: R library path that include correct BSgenome package (default: rlib)" 1>&2
	echo "	--viral_hosts_csv: viral contig to name lookup (default: dbs/sv/viral_host_ref.csv)" 1>&2
	echo "	--fusion_pairs_csv: known driver gene fusions (default: dbs/knowledgebases/output/knownFusionPairs.csv)" 1>&2
	echo "	--promiscuous_five_csv: known promiscuous gene fusions (default: dbs/knowledgebases/output/knownPromiscuousFive.csv)" 1>&2
	echo "	--promiscuous_three_csv: known promiscuous gene fusions (default: dbs/knowledgebases/output/knownPromiscuousThree.csv)" 1>&2
	echo "	--fragile_sites: known fragile sites (default: dbs/sv/fragile_sites_hmf.csv)" 1>&2
	echo "	--line_elements: known LINE donor sites (default: dbs/sv/line_elements.csv)" 1>&2
	echo "	--replication_origins: replication timing BED file (default: dbs/sv/heli_rep_origins.bed)" 1>&2
	echo "	--ensembl_data_dir: ensemble data cache (default: dbs/ensembl_data_cache)" 1>&2
	echo "	--validation_stringency: htsjdk SAM/BAM validation level (STRICT (default), LENIENT, or SILENT)" 1>&2
	echo "	--help: print this message and exit" 1>&2
	echo "" 1>&2
	exit 1
}

OPTIONS=v:o:t:n:s:r:b:h
LONGOPTS=snvvcf:,nosnvvcf,output_dir:,tumour_bam:,normal_bam:,sample:,threads:,jvmheap:,ref_dir:,reference:,repeatmasker:,blacklist:,bafsnps:,gcprofile:,gridsspon:,viralreference:,referencename:,viral_hosts_csv:,fusion_pairs_csv:,promiscuous_five_csv:,promiscuous_three_csv:,fragile_sites:,line_elements:,replication_origins:,ensembl_data_dir:,normal_sample:,tumour_sample:,install_dir:,picardoptions:,validation_stringency:,help
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
		--nosnvvcf)
			snvvcf="nosnvvcf"
			shift 1
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
		--normal_sample)
			normal_sample="$2"
			shift 2
			;;
		--tumour_sample)
			tumour_sample="$2"
			shift 2
			;;
		--threads)
			printf -v threads '%d\n' "$2" 2>/dev/null
			printf -v threads '%d' "$2" 2>/dev/null
			shift 2
			;;
		--repeatmasker)
			repeatmasker="$2"
			shift 2
			;;
		--jvmheap)
			jvmheap="$2"
			shift 2
			;;
		--install_dir)
			install_dir="$2"
			shift 2
			;;
		--ref_dir)
			ref_dir="$2"
			shift 2
			;;
		--picardoptions)
			# pass-through to gridss.sh argument of the same name
			picardoptions="$2"
			shift 2
			;;
		--validation_stringency)
			validation_stringency="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 1
			;;
		--)
			shift
			break
			;;
		*)
			echo "Command line parsing error ($1)"
			echo "$@"
			exit 3
			;;
	esac
done
# $1: variable containing filename
# $2: command line argument name
assert_file_exists() {
	if [[ ! -f "$1" ]] ; then
		echo "File $1 not found. Specify using the command line argument --$2" 1>&2
		exit 1
	fi
}
assert_directory_exists() {
	if [[ ! -d "$1" ]] ; then
		echo "Directory $1 not found. Specify using the command line argument --$2" 1>&2
		exit 1
	fi
}
assert_directory_exists $install_dir/gridss "install_dir"
assert_file_exists $install_dir/gridss/gridss.sh "install_dir"
assert_file_exists $install_dir/gridss/gridss_somatic_filter.R "install_dir"
assert_file_exists $install_dir/gridss/gridss_annotate_insertions_repeatmaster.R "install_dir"
assert_file_exists $install_dir/gridss/libgridss.R "install_dir"

rlib=$ref_dir/$rlib
ref_genome=$ref_dir/$ref_genome
viralreference=$ref_dir/$viralreference
blacklist=$ref_dir/$blacklist
repeatmasker=$ref_dir/$repeatmasker
bafsnps=$ref_dir/$bafsnps
gcprofile=$ref_dir/$gcprofile
gridsspon=$ref_dir/$gridsspon
# LINX data files
viral_hosts_csv=$ref_dir/$viral_hosts_csv
fusion_pairs_csv=$ref_dir/$fusion_pairs_csv
promiscuous_five_csv=$ref_dir/$promiscuous_five_csv
promiscuous_three_csv=$ref_dir/$promiscuous_three_csv
fragile_sites=$ref_dir/$fragile_sites
line_elements=$ref_dir/$line_elements
replication_origins=$ref_dir/$replication_origins
ensembl_data_dir=$ref_dir/$ensembl_data_dir

assert_file_exists $ref_genome "reference"
assert_file_exists $repeatmasker "repeatmasker"
assert_file_exists $gcprofile "gcprofile"
assert_file_exists $blacklist "blacklist"
assert_file_exists $viralreference "viralreference"
assert_directory_exists $gridsspon "gridsspon"

if [[ "$snvvcf" == "nosnvvcf" ]] ; then
	echo "No somatic SNV VCF supplied."
elif [[ ! -f "$snvvcf" ]] ; then
	echo "Missing somatic SNV VCF. A SNV VCF with the AD genotype field populated is required." 1>&2
	echo "Use the script for generating this VCF with strelka if you have not already generated a compatible VCF." 1>&2
	exit 1
fi
if [[ ! -f "$tumour_bam" ]] ; then
	echo "Missing tumour BAM" 1>&2
	exit 1
fi
if [[ ! -f "$normal_bam" ]] ; then
	echo "Missing normal BAM" 1>&2
	exit 1
fi
mkdir -p "$run_dir"
if [[ ! -d "$run_dir" ]] ; then
	echo "Unable to create $run_dir" 1>&2
	exit 1
fi
if [[ ! -d "$ref_dir" ]] ; then
	echo "Could not find reference data directory $ref_dir" 1>&2
	exit 1
fi
if [[ ! -f "$ref_genome" ]] ; then
	echo "Missing reference genome $ref_genome - specify with -r " 1>&2
	exit 1
fi
if [[ -z "$sample" ]] ; then
	sample=$(basename $tumour_bam .bam)
fi
if [[ "$threads" -lt 1 ]] ; then
	echo "Illegal thread count: $threads" 1>&2
	exit 1
fi
joint_sample_name=$sample
if [[ -z "$normal_sample" ]] ; then
	normal_sample=${sample}_N
fi
if [[ -z "$tumour_sample" ]] ; then
	tumour_sample=${sample}_T
fi
export R_LIBS="$rlib:${R_LIBS:-}"
base_path=$(dirname $(readlink $0 || echo $0))
### Find the jars
find_jar() {
	env_name=$1
	if [[ -f "${!env_name:-}" ]] ; then
		echo "${!env_name}"
	else
		echo "Unable to find $2 jar. Specify using the environment variable $env_name" 1>&2
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
		echo "Missing required dependency $program. $program must be on PATH" 1>&2
		exit 1
	fi
done
for rpackage in tidyverse devtools assertthat testthat NMF stringdist stringr argparser R.cache "copynumber" StructuralVariantAnnotation "VariantAnnotation" "rtracklayer" "BSgenome" "org.Hs.eg.db" ; do
	if ! Rscript -e "installed.packages()" | grep $rpackage > /dev/null ; then
		echo "Missing R package $rpackage" 1>&2
		exit 1
	fi
done

if ! java -Xms$jvmheap -cp $gridss_jar gridss.Echo ; then
	echo "Failure invoking java with --jvmheap parameter of \"$jvmheap\". Specify a JVM heap size (e.g. \"20g\") that is valid for this machine." 1>&2
	exit 1
fi

if [[ ! -s $ref_genome.bwt ]] ; then
	echo "Missing bwa index for $ref_genome. Creating (this is a once-off initialisation step)" 1>&2
	bwa index $ref_genome
fi

if [[ ! -s $ref_genome.bwt ]] ; then
	echo "bwa index for $ref_genome not found." 1>&2
	echo "If you are running in a docker container, make sure refdata has been mounted read-write." 1>&2
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

timestamp=$(date +%Y%m%d_%H%M%S)
echo [$timestamp] run_dir=$run_dir
echo [$timestamp] ref_dir=$ref_dir
echo [$timestamp] install_dir=$install_dir
echo [$timestamp] tumour_bam=$tumour_bam
echo [$timestamp] normal_bam=$normal_bam
echo [$timestamp] snvvcf=$snvvcf
echo [$timestamp] threads=$threads
echo [$timestamp] sample=$sample
echo [$timestamp] normal_sample=$normal_sample
echo [$timestamp] tumour_sample=$tumour_sample
echo [$timestamp] jvmheap=$jvmheap
echo [$timestamp] referencename=$referencename
echo [$timestamp] rlib=$rlib
echo [$timestamp] ref_genome=$ref_genome
echo [$timestamp] viralreference=$viralreference
echo [$timestamp] blacklist=$blacklist
echo [$timestamp] repeatmasker=$repeatmasker
echo [$timestamp] bafsnps=$bafsnps
echo [$timestamp] gcprofile=$gcprofile
echo [$timestamp] gridsspon=$gridsspon
echo [$timestamp] viral_hosts_csv=$viral_hosts_csv
echo [$timestamp] fusion_pairs_csv=$fusion_pairs_csv
echo [$timestamp] promiscuous_five_csv=$promiscuous_five_csv
echo [$timestamp] promiscuous_three_csv=$promiscuous_three_csv
echo [$timestamp] fragile_sites=$fragile_sites
echo [$timestamp] line_elements=$line_elements
echo [$timestamp] replication_origins=$replication_origins
echo [$timestamp] ensembl_data_dir=$ensembl_data_dir
echo [$timestamp] picardoptions=$picardoptions
echo [$timestamp] validation_stringency=$validation_stringency

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
	$install_dir/gridss/gridss.sh \
		-b $blacklist \
		-r $ref_genome \
		-o $gridss_raw_vcf \
		-a $assembly_bam \
		-w $gridss_dir \
		-j $gridss_jar \
		-t $threads \
		--jvmheap $jvmheap \
		--labels "$normal_sample,$tumour_sample" \
		$normal_bam \
		$tumour_bam \
		--picardoptions "VALIDATION_STRINGENCY=$validation_stringency $picardoptions" \
		2>&1 | tee $log_prefix.gridss.log
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
		Rscript $install_dir/gridss/gridss_annotate_insertions_repeatmaster.R \
			--input $gridss_decompressed_vcf \
			--output $gridss_decompressed_rmann_vcf \
			--repeatmasker $repeatmasker \
			--scriptdir $install_dir/gridss/  \
			2>&1 | tee -a $log_prefix.gridss.repeatannotate.log
		if [[ -f $gridss_decompressed_rmann_vcf.bgz ]] ; then
			gunzip -c $gridss_decompressed_rmann_vcf.bgz  | awk ' { if (length($0) >= 4000) { gsub(":0.00:", ":0.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000:")} ; print $0  } ' > $gridss_decompressed_rmann_vcf
		fi
	fi
	Rscript $install_dir/gridss/gridss_somatic_filter.R \
		-p ${gridsspon} \
		-i $gridss_decompressed_rmann_vcf \
		-o ${gridss_somatic_vcf} \
		-f ${gridss_somatic_full_vcf} \
		-r BSgenome.Hsapiens.UCSC.$referencename \
		-s $install_dir/gridss/ \
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
		-loci $bafsnps \
		-ref_genome $ref_genome \
		-validation_stringency $validation_stringency \
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
		-validation_stringency $validation_stringency \
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
	-ref_genome $ref_genome \
	-sample $tumour_sample \
	-purple_dir $run_dir/purple \
	-sv_vcf $run_dir/purple/$tumour_sample.purple.sv.vcf.gz \
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
	-check_drivers

java -cp $LINX_JAR com.hartwig.hmftools.linx.visualiser.SvVisualiser \
	-sample $tumour_sample \
	-plot_out $run_dir/linx/plot/ \
	-data_out $run_dir/linx/circos/ \
	-segment $run_dir/linx/$tumour_sample.linx.vis_segments.tsv \
	-link $run_dir/linx/$tumour_sample.linx.vis_sv_data.tsv \
	-exon $run_dir/linx/$tumour_sample.linx.vis_gene_exon.tsv \
	-cna $run_dir/linx/$tumour_sample.linx.vis_copy_number.tsv \
	-protein_domain $run_dir/linx/$tumour_sample.linx.vis_protein_domain.tsv \
	-fusion $run_dir/linx/$tumour_sample.linx.fusions_detailed.csv \
	-circos circos \
	-threads $threads


































