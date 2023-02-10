#!/bin/bash

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd ${script_dir}

echo "---cipa---"
cd cipa
docker build -t default/cipa -f Dockerfile .
cd ..