#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.timestamp = '$(date +%Y%m%d_%H%M%S%Z)'

process parallel {
    cpus "$params.cpusPerSample"
    queue 'default'
    container "$params.azureRegistryServer/default/cipa:latest"
  
    input:
        val sample

    output:
        stdout

    script:
        """
        cd /CiPA/hERG_fitting/

        Rscript generate_bootstrap_samples.R -d $params.drugName >\
            "results/${params.drugName}/generate_bootstrap_samples.R.log"

        Rscript hERG_fitting.R -d $params.drugName -c $task.cpus -i $sample -l $params.population -t $params.accuracy >\
            "results/${params.drugName}/hERG_fitting.R.log"

        mkdir -p "${params.azureFileShare}/${params.runId}/${params.drugName}/${sample}"
        cp -rv "results/${params.drugName}"/* "${params.azureFileShare}/${params.runId}/${params.drugName}/${sample}"/
        """
}

workflow {
    Channel.from(0..(params.numberOfSamples-1)) | parallel | view
}

