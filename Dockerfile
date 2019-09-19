FROM gridss/gridss:2.6.0
LABEL base.image="gridss/gridss:2.6.0"

# circos installation
# not using the ubuntu circos package as it places the conf files in /etc/circos which breaks << include etc/*.conf >> as CIRCOS_PATH/etc/circos is not on the circos search path
RUN apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y wget pkg-config libgd-dev
ENV CIRCOS_VERSION=0.69-9
RUN mkdir /opt/circos && \
	cd /opt/circos && \
	wget http://circos.ca/distribution/circos-${CIRCOS_VERSION}.tgz && \
	tar zxvf circos-${CIRCOS_VERSION}.tgz && \
	rm circos-${CIRCOS_VERSION}.tgz
ENV CIRCOS_HOME=/opt/circos/circos-${CIRCOS_VERSION}
ENV PATH=${CIRCOS_HOME}/bin:${PATH}
RUN cpan App::cpanminus
RUN cpanm List::MoreUtils Math::Bezier Math::Round Math::VecStat Params::Validate Readonly Regexp::Common SVG Set::IntSpan Statistics::Basic Text::Format Clone Config::General Font::TTF::Font GD

# LINX visualisation libraries
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libmagick++-dev
RUN Rscript -e 'options(Ncpus=16L, repos="https://cloud.r-project.org/");install.packages(c("tidyverse", "cowplot", "magick"))'
RUN Rscript -e 'options(Ncpus=16L, repos="https://cloud.r-project.org/");BiocManager::install(ask=FALSE, pkgs=c("Gviz"))'

################## METADATA ######################

LABEL version="1"
LABEL software="GRIDSS PURPLE LINX"
LABEL software.version="0.0.1"
LABEL about.summary="Somatic GRIDSS/PURPLE/LINX SV/CNV detection and interpretation pipeline"
LABEL about.home="https://github.com/hartwigmedical/gridss-purple-linx"
LABEL about.tags="Genomics"

RUN mkdir /opt/hmftools /opt/gridss-purple-linx
ENV AMBER_VERSION=2.5
ENV COBALT_VERSION=1.7
ENV PURPLE_VERSION=2.34
ENV LINX_VERSION=1.3

ENV AMBER_JAR=/opt/hmftools/amber-${AMBER_VERSION}-jar-with-dependencies.jar
ENV COBALT_JAR=/opt/hmftools/count-bam-lines-${COBALT_VERSION}-jar-with-dependencies.jar 
ENV PURPLE_JAR=/opt/hmftools/purity-ploidy-estimator-${PURPLE_VERSION}-jar-with-dependencies.jar
ENV LINX_JAR=/opt/hmftools/sv-linx-${LINX_VERSION}-jar-with-dependencies.jar

COPY external/hmftools/amber/target/amber-${AMBER_VERSION}-jar-with-dependencies.jar /opt/hmftools
COPY external/hmftools/count-bam-lines/target/count-bam-lines-${COBALT_VERSION}-jar-with-dependencies.jar /opt/hmftools
COPY external/hmftools/purity-ploidy-estimator/target/purity-ploidy-estimator-${PURPLE_VERSION}-jar-with-dependencies.jar /opt/hmftools
COPY external/hmftools/sv-linx/target/sv-linx-${LINX_VERSION}-jar-with-dependencies.jar /opt/hmftools
COPY gridss-purple-linx.sh /opt/gridss-purple-linx/

ENTRYPOINT ["/opt/gridss-purple-linx/gridss-purple-linx.sh"]

