locals {
  ghcr_secret_name = "docker-ghcr"
}

provider "flux" {}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["--profile", "takehome", "eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.eks.cluster_id]
  }
}

provider "github" {
  owner = var.github_owner
  token = data.sops_file.secrets_enc_yaml.data["github_token"]
}

# SSH
locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

resource "tls_private_key" "main" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Flux
data "flux_install" "main" {
  target_path = var.target_path
  components_extra = [
    "image-reflector-controller",
    "image-automation-controller",
  ]
}

data "flux_sync" "main" {
  target_path = var.target_path
  url         = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
  branch      = var.branch
}

# Kubernetes
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(["realworld", "flux-system"])

  metadata {
    annotations = {
      "linkerd.io/inject" = "enabled"
    }

    name = each.key
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

resource "kubectl_manifest" "ghcr_secret" {
  for_each = kubernetes_namespace.namespaces

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
    namespace: realworld
    creationTimestamp: null
  data:
    DATABASE_HOST: ${base64encode(data.terraform_remote_state.db.outputs.db.db_instance_address)}
    DATABASE_PASSWORD: ${base64encode(data.terraform_remote_state.db.outputs.db.db_instance_password)}
  YAML

  depends_on = [
    kubernetes_namespace.namespaces["realworld"],
  ]
}

resource "kubectl_manifest" "realworld_loadtest" {
  yaml_body = <<-YAML
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: realworld-loadtest
    namespace: realworld
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
          - "while true; do wget -q -O- realworld:3000 >/dev/null 2>/dev/null; done"
          resources:
            limits:
              cpu: 1000m
              memory: 768Mi
            requests:
              cpu: 1000m
              memory: 256Mi
  YAML

  depends_on = [
    kubernetes_namespace.namespaces["realworld"],
  ]
}

data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

resource "kubectl_manifest" "install" {
  for_each = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [
    kubernetes_namespace.namespaces["flux-system"],
  ]
  yaml_body = each.value
}

resource "kubectl_manifest" "sync" {
  for_each = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [
    kubernetes_namespace.namespaces["flux-system"],
  ]
  yaml_body = each.value
}

resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}

# GitHub
resource "github_repository_deploy_key" "main" {
  title      = "takehome-cluster"
  repository = var.repository_name
  key        = tls_private_key.main.public_key_openssh
  read_only  = false
}

resource "github_repository_file" "install" {
  repository = var.repository_name
  file       = data.flux_install.main.path
  content    = data.flux_install.main.content
  branch     = var.branch
}

resource "github_repository_file" "sync" {
  repository = var.repository_name
  file       = data.flux_sync.main.path
  content    = data.flux_sync.main.content
  branch     = var.branch
}

resource "github_repository_file" "kustomize" {
  repository = var.repository_name
  file       = data.flux_sync.main.kustomize_path
  content    = data.flux_sync.main.kustomize_content
  branch     = var.branch
}
