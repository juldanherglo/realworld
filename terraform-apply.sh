#!/bin/bash

set -euo pipefail

cd infrastructure/terraform

find . -type d -maxdepth 1 -mindepth 1 | sort | grep -v '1_base' | while read -r dir; do
  echo "$dir"
  cd "$dir"

  terraform init
  terraform apply -auto-approve || terraform apply -auto-approve

  cd - > /dev/null

  echo
done
