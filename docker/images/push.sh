#!/bin/bash

ACR="azurecr454"

# cipa
docker image tag default/cipa "$ACR.azurecr.io/default/cipa"
docker push "$ACR.azurecr.io/default/cipa"
