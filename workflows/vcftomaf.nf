/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap; fromSamplesheet } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowVcftomaf.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { BCFTOOLS_VIEW               } from '../modules/nf-core/bcftools/view/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { GUNZIP                      } from '../modules/nf-core/gunzip/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { PICARD_LIFTOVERVCF          } from '../modules/nf-core/picard/liftovervcf/main'
include { TABIX_TABIX                 } from '../modules/nf-core/tabix/tabix/main'
include { UNTAR                       } from '../modules/nf-core/untar/main'
include { VCF2MAF                     } from '../modules/nf-core/vcf2maf/main'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow VCFTOMAF {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //

    // Initialize input file channels based on params

    // INPUT
    input = Channel.fromSamplesheet("input")
        .map{ meta, normal_id, tumor_id, vcf_normal_id, vcf_tumor_id, vcf, index ->
            meta.index           = index     ? true      : false
            if (normal_id) {
                meta.normal_id       = normal_id
                meta.vcf_normal_id   = vcf_normal_id
            }
            if (tumor_id) {
                meta.tumor_id        = tumor_id
                meta.vcf_tumor_id    = vcf_tumor_id
            }
            return [meta, vcf, index] // it[0], it[1], it[2]
        }

    // INTERVALS
    ch_intervals = params.intervals ? Channel.fromPath(params.intervals).collect()          : Channel.value([])

    // FASTA
    fasta        = params.fasta     ? Channel.fromPath(params.fasta).collect()              : Channel.value([])
    dict         = params.dict      ? Channel.fromPath(params.dict).collect()               : Channel.empty()
    chain        = params.chain     ? Channel.fromPath(params.chain).collect()              : Channel.empty()

    // Genome version
    genome        = params.genome   ?: Channel.empty()

    // VEP cache
    ch_vep_cache          = params.vep_cache ? Channel.fromPath(params.vep_cache).collect()  : Channel.value([])
    vep_cache_unpacked    = Channel.value([])

    if (params.vep_cache){
        ch_vep_cache = ch_vep_cache.map{
            it -> def new_id = ""
                if(it) {
                    new_id = it[0].simpleName.toString()
                }
            [[id:new_id], it]
        }
        // UNTAR if available
        vep_cache_unpacked  = UNTAR(ch_vep_cache).untar.map { it[1] }
        ch_versions         = ch_versions.mix(UNTAR.out.versions)
    }


    // BRANCH CHANNEL
    input.branch{
        is_indexed:  it[0].index == true
        to_index:    it[0].index == false
    }.set{ch_input}

    // Remove empty index [] from channel = it[2]
    input_to_index = ch_input.to_index.map{ it -> [it[0], it[1]] }

    // Create tbi index only if not provided
    TABIX_TABIX(input_to_index)
    ch_versions = ch_versions.mix(TABIX_TABIX.out.versions.first())

    // Join tbi index back to input
    ch_indexed_to_index = input_to_index.join(TABIX_TABIX.out.tbi)

    // Join both channels back together
    ch_vcf = ch_input.is_indexed.mix(ch_indexed_to_index)

    //
    // MODULE: Run PASS + BED filtering
    //
    BCFTOOLS_VIEW (
        ch_vcf,
        ch_intervals,
        [],  // targets
        []   // samples
    )

    ch_versions = ch_versions.mix(BCFTOOLS_VIEW.out.versions.first())

    ch_gunzip = BCFTOOLS_VIEW.out.vcf
    if(params.chain){
        PICARD_LIFTOVERVCF(BCFTOOLS_VIEW.out.vcf,
                            dict.map{ it -> [ [ id:it.baseName ], it ] },
                            fasta.map{ it -> [ [ id:it.baseName ], it ] },
                            chain.map{ it -> [ [ id:it.baseName ], it ] })
        ch_gunzip = PICARD_LIFTOVERVCF.out.vcf_lifted
        ch_versions = ch_versions.mix(PICARD_LIFTOVERVCF.out.versions.first())
    }

    //
    // MODULE: Extract the gzipped VCF files
    //
    GUNZIP(ch_gunzip)
    ch_versions = ch_versions.mix(GUNZIP.out.versions.first())

    // Convert to MAF
    VCF2MAF(
        GUNZIP.out.gunzip,
        fasta,
        genome,
        vep_cache_unpacked
    )

    ch_versions = ch_versions.mix(VCF2MAF.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowVcftomaf.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowVcftomaf.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
