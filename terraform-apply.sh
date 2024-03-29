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

aws --profile takehome eks update-kubeconfig --region eu-west-1 --name takehome

echo "Lookup:"
echo "  kubectl -n ingress-nginx get svc ingress-nginx-controller"
echo ""
echo "and create a /etc/hosts entry for realworld.takehome.local"
