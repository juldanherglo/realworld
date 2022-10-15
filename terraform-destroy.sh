#!/bin/bash

set -euo pipefail

cd infrastructure/terraform

find . -type d -maxdepth 1 -mindepth 1 | sort -r | grep -v '1_base' | while read -r dir; do
  echo "$dir"
  cd "$dir"

  terraform destroy -auto-approve || terraform destroy -auto-approve

  cd - > /dev/null

  echo
done
