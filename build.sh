#!/bin/bash
(cd external/hmftools; mvn -T 1C clean package )
version=$(grep software.version Dockerfile | grep -oh '".*"' | tr -d \")
docker build --tag gridss/gridss-purple-linx:$version .
docker build --tag gridss/gridss-purple-linx:latest .
echo "docker push gridss/gridss-purple-linx:latest"
echo "docker push gridss/gridss-purple-linx:$version"

