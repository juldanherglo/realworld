locals {
  name             = "realworld-app"
  ghcr_secret_name = "docker-ghcr"
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = data.terraform_remote_state.eks.outputs.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["--profile", "takehome", "eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.eks.cluster_id]
  }
}

resource "kubectl_manifest" "ghcr_secret" {
  yaml_body = <<-YAML
  apiVersion: v1
  data:
    .dockerconfigjson: ${data.sops_file.secrets_enc_yaml.data[".dockerconfigjson"]}
  kind: Secret
  metadata:
    creationTimestamp: null
    name: ${local.ghcr_secret_name}
    namespace: default
  type: kubernetes.io/dockerconfigjson
  YAML
}

resource "kubectl_manifest" "deployment" {
  yaml_body = <<-YAML
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    creationTimestamp: null
    labels:
      app: realworld-app
    name: realworld-app
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: realworld-app
    strategy: {}
    template:
      metadata:
        creationTimestamp: null
        labels:
          app: realworld-app
      spec:
        imagePullSecrets:
        - name: ${local.ghcr_secret_name}
        containers:
        - image: ghcr.io/juldanherglo/realworld:main
          name: realworld
          resources: {}
          env:
          - name: DATABASE_HOST
            value: ${module.db.db_instance_address}
          - name: DATABASE_PASSWORD
            value: ${module.db.db_instance_password}
  status: {}
  YAML
}
