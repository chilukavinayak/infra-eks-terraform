# ============================================
# Tresvita EKS Staging Environment
# Managed by Wissen Team
# ============================================

# General Configuration
environment = "staging"
project_name = "tresvita-todo-app"
owner        = "wissen-team"

# AWS Region
aws_region = "us-west-2"

# VPC Configuration
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
database_subnet_cidrs = ["10.1.21.0/24", "10.1.22.0/24", "10.1.23.0/24"]

# EKS Cluster Configuration
cluster_name    = "tresvita-todo-app-staging"
cluster_version = "1.29"

cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
cluster_endpoint_private_access      = true

# Cluster logging - full for staging
cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

# Node Groups - Staging sizing
node_groups = {
  general = {
    name           = "general"
    instance_types = ["t3.large"]
    min_size       = 2
    max_size       = 6
    desired_size   = 3
    capacity_type  = "ON_DEMAND"
    disk_size      = 100
    labels = {
      workload = "general"
    }
    taints = []
  }
}

# Add-ons Configuration
enable_cluster_autoscaler           = true
enable_metrics_server               = true
enable_aws_load_balancer_controller = true
enable_external_dns                 = true
enable_cert_manager                 = true
enable_prometheus_stack             = true

# Domain Configuration
domain_name    = "staging.tresvita.com"
hosted_zone_id = ""  # Fill in after creating hosted zone

# Backup Configuration
enable_velero_backups = true
backup_bucket_name    = ""

# Security Configuration
enable_network_policy           = true
enable_pod_security_standards   = true

# Tags for all resources
tags = {
  Environment = "staging"
  Project     = "tresvita-todo-app"
  ManagedBy   = "wissen-team"
  Owner       = "wissen-team"
  CostCenter  = "tresvita-staging"
}
