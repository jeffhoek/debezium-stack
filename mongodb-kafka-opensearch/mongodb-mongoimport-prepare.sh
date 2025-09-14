#!/bin/bash

while IFS= read -r line; do
  echo $line
done < <(cat $1 | jq -c '.vulnerabilities[]')
echo ""

