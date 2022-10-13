#!/bin/bash

set -euo pipefail

for dir in infrastructure/terraform/*; do
  echo "$dir"
  cd "$dir"

  terraform init
  terraform apply -auto-approve || terraform apply -auto-approve

  cd - > /dev/null

  echo
done
