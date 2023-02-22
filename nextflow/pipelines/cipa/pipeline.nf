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
        cp -v `find -maxdepth 1 -type f` /CiPA/hERG_fitting/results/${params.drugName}"/
        popd

        Rscript hERG_fitting.R -d $params.drugName -c $task.cpus -i $sample -l $params.population -t $params.accuracy >\
            "results/${params.drugName}/hERG_fitting.R_${sample}.log"

        mkdir -p "${params.azureFileShare}/${params.runId}/${params.drugName}/boot"
        cp -rv "results/${params.drugName}/boot"/* "${params.azureFileShare}/${params.runId}/${params.drugName}/boot"/
        cp -v "results/${params.drugName}/hERG_fitting.R_${sample}.log" "${params.azureFileShare}/${params.runId}/${params.drugName}/hERG_fitting.R_${sample}.log"
        """
}

workflow {
    // Validate cpusPerSample is a factor of 80
    def factorsOf80 = [0, 1, 2, 4, 5, 8, 10, 16, 20, 40, 80]
    if (params.cpusPerSample > 0 && factorsOf80.contains(params.cpusPerSample % 80)) {
    
        // Allow sample 0 to be run independently
        if (params.startSampleNumber == 0) {
            if (params.endSampleNumber == 0) {
                prerequisites()
            }
            else {
                throw new Exception("Invalid input: if startSampleNumber is 0 endSampleNumber needs to be 0.")
            }
        }
        
        // Make sure sample range is within bounds
        if (params.startSampleNumber > 0) {
            if (params.startSampleNumber <= params.endSampleNumber) {
                if (params.endSampleNumber < 2000) {
                    def dir = prerequisites ()
                    parallel(dir, Channel.from(params.startSampleNumber..params.endSampleNumber)) | view
                }
                else {
                    throw new Exception("Invalid input: startSampleNumber needs to be <= endSampleNumber.")
                }
            }
        }
    }
    else {
        throw new Exception("Invalid input: cpusPerSample needs to be a factor of 80.")
    }
}
