FROM nfcore/base:2.1
LABEL org.opencontainers.image.source=https://github.com/qbic-pipelines/vcftomaf
LABEL org.opencontainers.image.description="Docker image containing umccr::vcf2maf && ensembl-vep"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors="Susanne Jodoin"

# Install the conda environment
COPY environment.yml /
RUN conda install -c conda-forge mamba
RUN mamba env create --file /environment.yml -p /opt/conda/envs/qbic-pipelines-vcftomaf-dev && \
    mamba clean --all --yes
RUN apt-get update -qq 
# Add conda installation dir to PATH
ENV PATH /opt/conda/envs/qbic-pipelines-vcftomaf-dev/bin:$PATH
# Dump the details of the installed packates to a file for posterity
RUN mamba env export --name qbic-pipelines-vcftomaf-dev > qbic-pipelines-vcftomaf-dev.yml

