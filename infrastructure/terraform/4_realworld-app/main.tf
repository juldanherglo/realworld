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
  for_each = toset(["default", "flux-system"])

  yaml_body = <<-YAML
  apiVersion: v1
  kind: Secret
  metadata:
    name: ${local.ghcr_secret_name}
    namespace: ${each.key}
    creationTimestamp: null
  data:
    .dockerconfigjson: ${data.sops_file.secrets_enc_yaml.data[".dockerconfigjson"]}
  type: kubernetes.io/dockerconfigjson
  YAML
}

resource "kubectl_manifest" "deployment" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Secret
  metadata:
    name: realworld-db
    namespace: default
    creationTimestamp: null
  data:
    DATABASE_HOST: ${base64encode(module.db.db_instance_address)}
    DATABASE_PASSWORD: ${base64encode(module.db.db_instance_password)}
  YAML
}

resource "kubectl_manifest" "realworld_loadtest" {
  yaml_body = <<-YAML
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: realworld-loadtest
    namespace: default
  spec:
    minReadySeconds: 3
    replicas: 0
    revisionHistoryLimit: 5
    progressDeadlineSeconds: 60
    strategy:
      rollingUpdate:
        maxUnavailable: 0
      type: RollingUpdate
    selector:
      matchLabels:
        app: realworld-loadtest
    template:
      metadata:
        labels:
          app: realworld-loadtest
      spec:
        containers:
        - name: realworld-loadtest
          image: busybox
          imagePullPolicy: IfNotPresent
          command:
          - /bin/ash
          - -c
          - "while true; do wget -q -O- realworld:3000; done"
          resources:
            limits:
              cpu: 1000m
              memory: 768Mi
            requests:
              cpu: 1000m
              memory: 256Mi
  YAML
}
