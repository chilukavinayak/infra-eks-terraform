# ============================================
# General Configuration
# ============================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "tresvita-todo-app"
}

variable "owner" {
  description = "Owner/team responsible for the infrastructure"
  type        = string
  default     = "wissen-team"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# ============================================
# VPC Configuration
# ============================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

# ============================================
# EKS Cluster Configuration
# ============================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = ""
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

variable "cluster_enabled_log_types" {
  description = "List of log types to enable for EKS cluster"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to EKS API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to EKS API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks allowed for public access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ============================================
# Node Groups Configuration
# ============================================

variable "node_groups" {
  description = "Map of EKS node group configurations"
  type = map(object({
    name           = string
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string
    disk_size      = number
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {}
}

# ============================================
# Environment Scaling Configuration
# ============================================

variable "environment_scaling" {
  description = "Scaling configuration for different environments"
  type = map(object({
    node_instance_types = list(string)
    node_min_size       = number
    node_max_size       = number
    node_desired_size   = number
    enable_monitoring   = bool
  }))
  default = {
    dev = {
      node_instance_types = ["t3.medium"]
      node_min_size       = 2
      node_max_size       = 4
      node_desired_size   = 2
      enable_monitoring   = false
    }
    staging = {
      node_instance_types = ["t3.large"]
      node_min_size       = 2
      node_max_size       = 6
      node_desired_size   = 3
      enable_monitoring   = true
    }
    prod = {
      node_instance_types = ["m6i.large", "m5.large"]
      node_min_size       = 3
      node_max_size       = 10
      node_desired_size   = 3
      enable_monitoring   = true
    }
  }
}

# ============================================
# Add-ons Configuration
# ============================================

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable Metrics Server"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable External DNS"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Enable cert-manager for TLS certificates"
  type        = bool
  default     = true
}

variable "enable_prometheus_stack" {
  description = "Enable Prometheus/Grafana monitoring stack"
  type        = bool
  default     = false
}

# ============================================
# Domain and DNS Configuration
# ============================================

variable "domain_name" {
  description = "Domain name for applications"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

# ============================================
# Backup and Recovery
# ============================================

variable "enable_velero_backups" {
  description = "Enable Velero for cluster backups"
  type        = bool
  default     = true
}

variable "backup_bucket_name" {
  description = "S3 bucket name for backups"
  type        = string
  default     = ""
}

# ============================================
# Security Configuration
# ============================================

variable "enable_network_policy" {
  description = "Enable Kubernetes Network Policies"
  type        = bool
  default     = true
}

variable "enable_pod_security_standards" {
  description = "Enable Pod Security Standards"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
}

# ============================================
# Remote State Configuration
# ============================================

variable "remote_state_bucket" {
  description = "S3 bucket for Terraform remote state"
  type        = string
  default     = ""
}

variable "remote_state_lock_table" {
  description = "DynamoDB table for state locking"
  type        = string
  default     = ""
}
