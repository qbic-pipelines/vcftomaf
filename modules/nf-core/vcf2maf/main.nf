process VCF2MAF {

    tag "$meta.id"
    label 'process_low'

    // WARN: Version information not provided by tool on CLI. Please update version string below when bumping container versions.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-b1882a8fe50273c1485ae9ededaf10b625862cc1:2e14951bfa86df1bc30bb0dc1a0a3ec5fbaa5fd2-0':
        'biocontainers/mulled-v2-b1882a8fe50273c1485ae9ededaf10b625862cc1:2e14951bfa86df1bc30bb0dc1a0a3ec5fbaa5fd2-0' }"

    input:
    tuple val(meta), path(vcf) // Use an uncompressed VCF file!
    path fasta                 // Required
    val genome                 // Required
    path vep_cache             // Required for VEP running. A default of /.vep is supplied.

    output:
    tuple val(meta), path("*.maf"), emit: maf
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args          = task.ext.args   ?: ''
    def prefix        = task.ext.prefix ?: "${meta.id}"
    def vep_cache_cmd = vep_cache       ? "--vep-data $vep_cache" : ""
    def genome_build  = genome          ? "--ncbi-build $genome"  : ""

    // If VEP is present, it will find it and add it to commands.
    // If VEP is not present they will be blank
    def VERSION = '1.6.21.20230511' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    if command -v vep &> /dev/null
    then
        VEP_CMD="--vep-path \$(dirname \$(type -p vep))"
        VEP_VERSION=\$(echo -e "\\n    ensemblvep: \$( echo \$(vep --help 2>&1) | sed 's/^.*Versions:.*ensembl-vep : //;s/ .*\$//')")
    else
        VEP_CMD=""
        VEP_VERSION=""
    fi

    vcf2maf.pl \\
        $args \\
        \$VEP_CMD \\
        $vep_cache_cmd \\
        $genome_build \\
        --ref-fasta $fasta \\
        --input-vcf $vcf \\
        --output-maf ${prefix}.maf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vcf2maf: $VERSION\$VEP_VERSION
    END_VERSIONS
    """
}
