#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.timestamp = '$(date +%Y%m%d_%H%M%S%Z)'

process prerequisites  {
    cpus "$params.cpusPerSample"
    queue 'default'
    container "$params.azureRegistryServer/default/cipa:latest"

    output:
        val "${params.azureFileShare}/${params.runId}/${params.drugName}"

    script:
        """
        cd /CiPA/hERG_fitting/

        rm -r "results/${params.drugName}"
        mkdir -p "results/${params.drugName}"

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

        pushd ${baseDir}
        cp -v `find -maxdepth 1 -type f` "/CiPA/hERG_fitting/results/${params.drugName}"/
        popd

        Rscript hERG_fitting.R -d $params.drugName -c $task.cpus -i $sample -l $params.population -t $params.accuracy >\
            "results/${params.drugName}/hERG_fitting.R_${sample}.log"

        mkdir -p "${params.azureFileShare}/${params.runId}/${params.drugName}/boot"
        cp -rv "results/${params.drugName}/boot"/* "${params.azureFileShare}/${params.runId}/${params.drugName}/boot"/
        cp -v "results/${params.drugName}/hERG_fitting.R_${sample}.log" "${params.azureFileShare}/${params.runId}/${params.drugName}/hERG_fitting.R_${sample}.log"
        """
}

process err {
    queue 'default'
    container "$params.azureRegistryServer/default/ubuntu:latest"

    input:
        val msg

    script:
        """
        echo $msg
        exit 1
        """
}

workflow {
    def factorsOf80 = [0, 1, 2, 4, 5, 8, 10, 16, 20, 40, 80]
    if(params.cpusPerSample < 1) {
        err("Invalid input: cpusPerSample must be => 1.")
    }
    if (!factorsOf80.contains(params.cpusPerSample % 80)) {
        err("Invalid input: cpusPerSample must be a factor of 80.")
    }

    // Allow sample 0 to be run independently
    if (params.startSampleNumber == 0) {
        if (params.endSampleNumber != 0) {
            err("Invalid input: if startSampleNumber is 0 endSampleNumber must be 0.")
        }
        prerequisites()
    }
    
    // Make sure sample range is within bounds
    if (params.startSampleNumber > 0) {
        if (params.endSampleNumber > 2000) {
            err("Invalid input: endSampleNumber must be <= 2000.")
        }
        if (params.startSampleNumber > params.endSampleNumber) {
            err("Invalid input: startSampleNumber must be <= endSampleNumber.")
        }
        def dir = prerequisites()
        parallel(dir, Channel.from(params.startSampleNumber..params.endSampleNumber)) | view
    }
}
