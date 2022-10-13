locals {
  name             = "realworld-app"
  ghcr_secret_name = "docker-ghcr"
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Complete PostgreSQL example security group"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = data.terraform_remote_state.vpc.outputs.vpc.vpc_cidr_block
    },
  ]
}

################################################################################
# RDS Module
################################################################################

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.0"

  identifier = local.name

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "14.4"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "gobuff_realworld_example_app_development"
  username = "postgres"
  port     = 5432

  multi_az               = false
  db_subnet_group_name   = data.terraform_remote_state.vpc.outputs.vpc.database_subnet_group
  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60
  monitoring_role_name                  = "example-monitoring-role-name"
  monitoring_role_use_name_prefix       = true
  monitoring_role_description           = "Description for monitoring role"

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]
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

resource "kubectl_manifest" "namespace" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Namespace
  metadata:
    annotations:
      linkerd.io/inject: enabled
    name: realworld
  YAML
}

resource "kubectl_manifest" "ghcr_secret" {
  for_each = toset(["realworld", "flux-system"])

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

  depends_on = [
    kubectl_manifest.namespace,
  ]
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
    DATABASE_HOST: ${base64encode(module.db.db_instance_address)}
    DATABASE_PASSWORD: ${base64encode(module.db.db_instance_password)}
  YAML

  depends_on = [
    kubectl_manifest.namespace,
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
    kubectl_manifest.namespace,
  ]
}
