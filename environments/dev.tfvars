# ============================================
# Tresvita EKS Development Environment
# Managed by Wissen Team
# ============================================

# General Configuration
environment = "dev"
project_name = "tresvita-todo-app"
owner        = "wissen-team"

# AWS Region
aws_region = "us-west-2"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

# EKS Cluster Configuration
cluster_name    = "tresvita-todo-app-dev"
cluster_version = "1.29"

# Enable public access for development
# IMPORTANT: Replace "0.0.0.0/0" with your IP for security
# Get your IP: curl -s ifconfig.me
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["124.123.131.55/32"]  # Whitelisted IP
cluster_endpoint_private_access      = true

# Cluster logging
cluster_enabled_log_types = ["api", "audit", "authenticator"]

# Node Groups - Development sizing
node_groups = {
  general = {
    name           = "general"
    instance_types = ["t3.medium"]
    min_size       = 2
    max_size       = 4
    desired_size   = 2
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
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
enable_external_dns                 = false  # Disabled for dev (no domain)
enable_cert_manager                 = false  # Disabled for dev (no TLS)
enable_prometheus_stack             = false  # Disabled for dev (save costs)

# Domain Configuration (empty for dev)
domain_name    = ""
hosted_zone_id = ""

# Backup Configuration
enable_velero_backups = true
backup_bucket_name    = ""

# Security Configuration
enable_network_policy           = true
enable_pod_security_standards   = true

# IP Whitelisting (optional - leave empty to allow all)
my_ip_address = "124.123.131.55/32"
allowed_management_cidrs = ["124.123.131.55/32"]
allowed_ssh_cidrs = ["124.123.131.55/32"]

# Tags for all resources
tags = {
  Environment = "dev"
  Project     = "tresvita-todo-app"
  ManagedBy   = "wissen-team"
  Owner       = "wissen-team"
  CostCenter  = "tresvita-dev"
}
