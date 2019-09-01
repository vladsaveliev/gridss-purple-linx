#!/bin/bash

(cd external/gridss  ; mvn -T 1C clean package )
(cd external/hmftools; mvn -T 1C clean package )

version=$(grep software.version Dockerfile | grep -oh '".*"' | tr -d \")
docker build --tag gridss/gridss-purple-linx:$version .
docker build --tag gridss/gridss-purple-linx:latest .
echo "docker push gridss/gridsspurplelinx:latest"
echo "docker push gridss/gridsspurplelinx:$version"

