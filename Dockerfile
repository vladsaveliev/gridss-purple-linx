FROM gridss/gridss:2.5.2
LABEL base.image="gridss/gridss:2.5.2"

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y circos pkg-config libgd-dev

# circos perl packages
RUN cpan App::cpanminus
RUN cpanm List::MoreUtils Math::Bezier Math::Round Math::VecStat Params::Validate Readonly Regexp::Common SVG Set::IntSpan Statistics::Basic Text::Format Clone Config::General Font::TTF::Font GD

################## METADATA ######################

LABEL version="1"
LABEL software="GRIDSS PURPLE LINX"
LABEL software.version="1.0.0"
LABEL about.summary="GRIDSS PURPLE LINX"
LABEL about.home="https://github.com/hartwigmedical/gridss-purple-linx"
LABEL about.tags="Genomics"

RUN mkdir /opt/hmftools /opt/gridss-purple-linx
ENV AMBER_VERSION=2.5
ENV COBALT_VERSION=1.7
ENV PURPLE_VERSION=2.33
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

