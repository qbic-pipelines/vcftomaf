#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    qbic-pipelines/vcftomaf
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/qbic-pipelines/vcftomaf
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { VCFTOMAF                } from './workflows/vcftomaf'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_vcftomaf_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_vcftomaf_pipeline'
include { getGenomeAttribute      } from './subworkflows/local/utils_nfcore_vcftomaf_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow QBICPIPELINES_VCFTOMAF {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    //
    // SET PARAMETERS
    //
    params.fasta = getGenomeAttribute('fasta')
    params.dict = getGenomeAttribute('dict')

    // Extra files
    intervals      = params.intervals      ? Channel.fromPath(params.intervals).collect()      : Channel.value([])
    liftover_chain = params.liftover_chain ? Channel.fromPath(params.liftover_chain).collect() : Channel.value([])

    // FASTA
    fasta        = params.fasta     ? Channel.fromPath(params.fasta).collect()          : Channel.value([])
    dict         = params.dict      ? Channel.fromPath(params.dict).collect()           : Channel.empty()

    // Genome version
    genome        = params.genome   ?: Channel.empty()

    // VEP cache
    vep_cache          = params.vep_cache ? Channel.fromPath(params.vep_cache).collect() : Channel.value([])
    vep_cache_unpacked = Channel.value([])


    //
    // WORKFLOW: Run pipeline
    //

    VCFTOMAF (
        samplesheet,
        intervals,
        fasta,
        dict,
        liftover_chain,
        genome,
        vep_cache,
        vep_cache_unpacked
    )

    emit:
    multiqc_report = VCFTOMAF.out.multiqc_report // channel: /path/to/multiqc_report.html
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    //
    // WORKFLOW: Run main workflow
    //
    QBICPIPELINES_VCFTOMAF (
        PIPELINE_INITIALISATION.out.samplesheet
    )

    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        QBICPIPELINES_VCFTOMAF.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
