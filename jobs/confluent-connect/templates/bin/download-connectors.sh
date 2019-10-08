#!/bin/bash

function downloadConnectors() {
  CONNECTORS_FOLDER=$1
  S3_ENDPOINT=$2
  S3_ACCESS_KEY=$3
  S3_SECRET_KEY=$4
  S3_BUCKET=$5

  rm -rf $CONNECTORS_FOLDER

  mkdir $CONNECTORS_FOLDER

  /var/vcap/packages/minio-mc/mc config host add connectors $S3_ENDPOINT $S3_ACCESS_KEY $S3_SECRET_KEY

  /var/vcap/packages/minio-mc/mc cp --recursive connectors/$S3_BUCKET/ $CONNECTORS_FOLDER

  for i in $CONNECTORS_FOLDER/*.zip; do
    newdir="${i:0:-4}" && mkdir "$newdir"
    unzip "$i" -d  "$newdir"
  done
}