# ============================================
# Tresvita EKS Production Environment
# Managed by Wissen Team
# ============================================

# General Configuration
environment = "prod"
project_name = "tresvita-todo-app"
owner        = "wissen-team"

# AWS Region
aws_region = "us-west-2"

# VPC Configuration
vpc_cidr             = "10.2.0.0/16"
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24", "10.2.13.0/24"]
database_subnet_cidrs = ["10.2.21.0/24", "10.2.22.0/24", "10.2.23.0/24"]

# EKS Cluster Configuration
cluster_name    = "tresvita-todo-app-prod"
cluster_version = "1.29"

# Restrict public access for production
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = []  # Fill in with specific CIDRs
cluster_endpoint_private_access      = true

# Cluster logging - full for production
cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

# Node Groups - Production sizing
node_groups = {
  general = {
    name           = "general"
    instance_types = ["m6i.large", "m5.large"]
    min_size       = 3
    max_size       = 10
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
domain_name    = "tresvita.com"
hosted_zone_id = ""  # Fill in after creating hosted zone

# Backup Configuration
enable_velero_backups = true
backup_bucket_name    = ""

# Security Configuration
enable_network_policy           = true
enable_pod_security_standards   = true

# Tags for all resources
tags = {
  Environment = "prod"
  Project     = "tresvita-todo-app"
  ManagedBy   = "wissen-team"
  Owner       = "wissen-team"
  CostCenter  = "tresvita-prod"
}
