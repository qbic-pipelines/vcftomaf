# ![qbic-pipelines/vcftomaf](docs/images/qbic-pipelines-vcftomaf-logo.png#gh-light-mode-only) ![qbic-pipelines/vcftomaf](docs/images/qbic-pipelines-vcftomaf-logo-dark.png.png#gh-dark-mode-only)

[![GitHub Actions CI Status](https://github.com/qbic-pipelines/vcftomaf/actions/workflows/ci.yml/badge.svg)](https://github.com/qbic-pipelines/vcftomaf/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/qbic-pipelines/vcftomaf/actions/workflows/linting.yml/badge.svg)](https://github.com/qbic-pipelines/vcftomaf/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/qbic-pipelines/vcftomaf)

## Introduction

**qbic-pipelines/vcftomaf** is a bioinformatics pipeline that converts input Variant Call Format (vcf) files with one or two columns of (paired) samples to tabular Mutation Annotation Format (maf).
The resulting file(s) can be analyzed singly or as an entire cohort in R with [maftools](https://github.com/PoisonAlien/maftools).

1. Filtering VCF files for PASS and optionally with a target bed file ([`BCFtools`](https://github.com/samtools/bcftools))
2. Optional liftover (needs a `chain` file, `--fasta` should refer to target genome version) ([`Picard LiftOverVCF`](https://gatk.broadinstitute.org/hc/en-us/articles/360037060932-LiftoverVcf-Picard))
3. Conversion from vcf to maf format([`vcf2maf`](https://github.com/mskcc/vcf2maf))
4. Collect QC metrics and versions ([`MultiQC`](http://multiqc.info/))

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,normal_id,vcf_normal_id,tumor_id,vcf_tumor_id,vcf,index
mutect2_sample1,SAMPLE123,PATIENT1_SAMPLE123,SAMPLE456,PATIENT1_SAMPLE456,/path/to/vcf,/path/to/tbi
test2,control2,NORMAl,,,/path/to/vcf,/path/to/tbi
```

Each row represents a sample with one or two columns in the VCF file. The `normal_id` and `tumor_id` will be used for naming the columns in the MAF file. The `vcf_normal/tumor_id` refers to the sample name in the VCF file. This differs for each caller. For VCFs obtained from nf-core/sarek, the following is tested:

| Caller   | Normal ID               | Tumor ID                |
| :------- | :---------------------- | :---------------------- |
| Manta    | NORMAL                  | TUMOR                   |
| Mutect2  | {_patient_}_{\_sample_} | {_patient_}_{\_sample_} |
| Strelka2 | NORMAL                  | TUMOR                   |

The values for _patient_ and _sample_ can be obtained from the nf-core/sarek samplesheet.

Now, you can run the pipeline using:

```bash
nextflow run qbic-pipelines/vcftomaf \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [usage documentation](docs/usage.md) and the [parameter documentation](nextflow_schema.json).

For more details about the output files and reports, please refer to the
[output documentation](docs/output.md).

## Credits

qbic-pipelines/vcftomaf was originally written by [SusiJo](https://github.com/SusiJo) and [Friederike Hanssen](https://github.com/FriederikeHanssen)

We thank the following people for their extensive assistance in the development of this pipeline:

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use qbic-pipelines/vcftomaf for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline is based on code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).
The pipeline is currently maintained at QBiC and not an nf-core pipeline since it has not undergone nf-core community review.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
