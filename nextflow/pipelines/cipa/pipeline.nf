#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.timestamp = '$(date +%Y%m%d_%H%M%S%Z)'

process prereq {
    queue 'default'
    container "$params.azureRegistryServer/default/cipa:latest"

    output:
        val "${params.azureFileShare}/${params.runId}/${params.drugName}"

    script:
        """
        cd /CiPA/hERG_fitting/

        rm -r "results/${params.drugName}"

        Rscript generate_bootstrap_samples.R -d $params.drugName >\
            "results/${params.drugName}/generate_bootstrap_samples.R.log"

        Rscript hERG_fitting.R -d $params.drugName -c $task.cpus -i 0 -l $params.population -t $params.accuracy >\
            "results/${params.drugName}/hERG_fitting.R_0.log" 

        mkdir -p "${params.azureFileShare}/${params.runId}/${params.drugName}"
        cp -rv "results/${params.drugName}"/* "${params.azureFileShare}/${params.runId}/${params.drugName}"/
        """    
}

process parallel {
    cpus "$params.cpusPerSample"
    queue 'default'
    container "$params.azureRegistryServer/default/cipa:latest"
  
    input:
        val baseDir
        val sample

    output:
        stdout

    script:
        """
        cd /CiPA/hERG_fitting/

        rm -r "results/${params.drugName}"
        mkdir -p "results/${params.drugName}"
        cp -v "${baseDir}"/* "results/${params.drugName}"/

        Rscript hERG_fitting.R -d $params.drugName -c $task.cpus -i $sample -l $params.population -t $params.accuracy >\
            "results/${params.drugName}/hERG_fitting.R_${sample}.log"

        mkdir -p "${params.azureFileShare}/${params.runId}/${params.drugName}/boot"
        cp -rv "results/${params.drugName}"/boot/* "${params.azureFileShare}/${params.runId}/${params.drugName}/boot"/
        """
}

workflow {
    if (params.startSampleNumber > 0) {
        if (params.startSampleNumber <= params.endSampleNumber) {
            if (params.startSampleNumber < 2000) {
                def dir = prereq()
                Channel.from(dir, (params.startSampleNumber)..(params.endSampleNumber)) | parallel | view
            }
        }
    }
}
