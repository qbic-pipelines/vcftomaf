/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { BCFTOOLS_VIEW               } from '../../modules/nf-core/bcftools/view/main'
include { GUNZIP                      } from '../../modules/nf-core/gunzip/main'
include { MULTIQC                     } from '../../modules/nf-core/multiqc/main'
include { PICARD_LIFTOVERVCF          } from '../../modules/nf-core/picard/liftovervcf/main'
include { TABIX_TABIX                 } from '../../modules/nf-core/tabix/tabix/main'
include { UNTAR                       } from '../../modules/nf-core/untar/main'
include { VCF2MAF                     } from '../../modules/nf-core/vcf2maf/main'
include { paramsSummaryMap            } from 'plugin/nf-schema'
include { paramsSummaryMultiqc        } from '../../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML      } from '../../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText      } from '../../subworkflows/local/utils_nfcore_vcftomaf_pipeline'
include { VCF_ANNOTATE_ENSEMBLVEP     } from '../../subworkflows/nf-core/vcf_annotate_ensemblvep/main'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow VCFTOMAF {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    intervals
    fasta
    dict
    liftover_chain
    genome
    vep_cache
    vep_cache_unpacked
    vep_cache_version
    vep_genome
    vep_species

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //

    // BRANCH CHANNEL
    ch_samplesheet.branch{
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

    // VEP annotation is currently not supported from within vcf2maf : https://github.com/mskcc/vcf2maf/issues/335
    // Therefore we use the vcf_annotate_ensemblvep subworkflow here

    if (params.vep_cache){
        ch_vep_cache = vep_cache.map{
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

    VCF_ANNOTATE_ENSEMBLVEP(
        ch_vcf,
        fasta,
        vep_genome,
        vep_species,// species
        vep_cache_version,  // cache_version
        vep_cache_unpacked, // ch_cache
        [] // ch_extra_files
    )

    //
    // MODULE: Run PASS + BED filtering
    //
    BCFTOOLS_VIEW (
        ch_vcf,
        intervals,
        [],  // targets
        []   // samples
    )

    ch_versions = ch_versions.mix(BCFTOOLS_VIEW.out.versions.first())

    ch_gunzip = BCFTOOLS_VIEW.out.vcf

    if(params.liftover_chain){

        PICARD_LIFTOVERVCF(BCFTOOLS_VIEW.out.vcf,
                            dict.map{ it -> [ [ id:it.baseName ], it ] },
                            fasta.map{ it -> [ [ id:it.baseName ], it ] },
                            liftover_chain.map{ it -> [ [ id:it.baseName ], it ] })
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
        vep_cache_unpacked
    )

    ch_versions = ch_versions.mix(VCF2MAF.out.versions.first())

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
