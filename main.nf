#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    qbic-pipelines/vcftomaf
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/qbic-pipelines/vcftomaf
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { VCFTOMAF  } from './workflows/vcftomaf'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_vcftomaf_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_vcftomaf_pipeline'

include { getGenomeAttribute      } from './subworkflows/local/utils_nfcore_vcftomaf_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.fasta = getGenomeAttribute('fasta')
params.dict = getGenomeAttribute('dict')

// Extra files
intervals = params.intervals    ? Channel.fromPath(params.intervals).collect()      : Channel.value([]) // --> this is fine with class groovyx.gpars.dataflow.DataflowVariable
//chain     = params.chain    ? Channel.fromPath(params.chain).collect()      : Channel.empty() // --> this results in class nextflow.extension.OpCall

// FASTA
fasta        = params.fasta     ? Channel.fromPath(params.fasta).collect()          : Channel.value([])
dict         = params.dict      ? Channel.fromPath(params.dict).collect()           : Channel.empty()

// Genome version
genome        = params.genome   ?: Channel.empty()

// VEP cache
vep_cache          = params.vep_cache ? Channel.fromPath(params.vep_cache).collect() : Channel.value([])
vep_cache_unpacked = Channel.value([])


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
    // WORKFLOW: Run pipeline
    //
    chain        = params.chain    ? Channel.fromPath(params.chain).collect()      : Channel.empty() // this is fine with a class groovyx.gpars.dataflow.DataflowVariable

    VCFTOMAF (
        samplesheet,
        intervals,
        fasta,
        dict,
        chain,
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
        params.help,
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
    // SUBWORKFLOW: Run completion tasks
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
