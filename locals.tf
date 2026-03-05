locals {
  # Cluster naming
  cluster_name = var.cluster_name != "" ? var.cluster_name : "tresvita-todo-app-${var.environment}"

  # Common tags for Tresvita resources
  common_tags = merge({
    Environment = var.environment
    Project     = "tresvita-todo-app"
    ManagedBy   = "wissen-team"
    Owner       = "wissen-team"
    Client      = "tresvita"
    Terraform   = "true"
  }, var.tags)

  # AZs to use
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)

  # Environment-specific scaling
  scaling = var.environment_scaling[var.environment]

  # Default node group configuration
  default_node_group = {
    general = {
      name           = "general-workloads"
      instance_types = local.scaling.node_instance_types
      min_size       = local.scaling.node_min_size
      max_size       = local.scaling.node_max_size
      desired_size   = local.scaling.node_desired_size
      capacity_type  = var.environment == "prod" ? "ON_DEMAND" : "SPOT"
      disk_size      = 50
      labels = {
        workload-type = "general"
        environment   = var.environment
      }
      taints = []
    }
  }

  # Merge user-provided node groups with defaults
  node_groups = length(var.node_groups) > 0 ? var.node_groups : local.default_node_group

  # Backup bucket name
  backup_bucket = var.backup_bucket_name != "" ? var.backup_bucket_name : "${var.project_name}-backups-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  # State bucket name
  state_bucket = var.remote_state_bucket != "" ? var.remote_state_bucket : "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  # State lock table
  state_lock_table = var.remote_state_lock_table != "" ? var.remote_state_lock_table : "${var.project_name}-tfstate-lock"

  # Domain configuration
  domain_name = var.domain_name != "" ? var.domain_name : "${var.environment}.${var.project_name}.local"

  # Namespace configuration for Tresvita application isolation
  namespaces = {
    frontend = {
      name = "frontend"
      labels = {
        "app.kubernetes.io/part-of"    = "tresvita-todo-app"
        "app.kubernetes.io/component"  = "frontend"
        "app.kubernetes.io/managed-by" = "wissen-team"
        "client"                       = "tresvita"
        "environment"                  = var.environment
      }
      annotations = {
        "description" = "Tresvita Frontend React application namespace - Managed by Wissen Team"
      }
      resource_quota = var.environment != "dev"
      limit_range    = true
    }
    backend = {
      name = "backend"
      labels = {
        "app.kubernetes.io/part-of"    = "tresvita-todo-app"
        "app.kubernetes.io/component"  = "backend"
        "app.kubernetes.io/managed-by" = "wissen-team"
        "client"                       = "tresvita"
        "environment"                  = var.environment
      }
      annotations = {
        "description" = "Tresvita Backend Java application namespace - Managed by Wissen Team"
      }
      resource_quota = var.environment != "dev"
      limit_range    = true
    }
    monitoring = {
      name = "monitoring"
      labels = {
        "app.kubernetes.io/part-of" = "infrastructure"
        "environment" = var.environment
      }
      annotations = {
        "description" = "Monitoring and observability namespace"
      }
      resource_quota = false
      limit_range    = false
    }
    cicd = {
      name = "cicd"
      labels = {
        "app.kubernetes.io/part-of" = "infrastructure"
        "environment" = var.environment
      }
      annotations = {
        "description" = "CI/CD tooling namespace"
      }
      resource_quota = false
      limit_range    = false
    }
  }

  # Resource quotas for namespaces (environment-specific)
  resource_quotas = {
    dev = {
      frontend = {
        "requests.cpu"    = "2"
        "requests.memory" = "4Gi"
        "limits.cpu"      = "4"
        "limits.memory"   = "8Gi"
        "pods"            = "10"
      }
      backend = {
        "requests.cpu"    = "2"
        "requests.memory" = "4Gi"
        "limits.cpu"      = "4"
        "limits.memory"   = "8Gi"
        "pods"            = "10"
      }
    }
    staging = {
      frontend = {
        "requests.cpu"    = "4"
        "requests.memory" = "8Gi"
        "limits.cpu"      = "8"
        "limits.memory"   = "16Gi"
        "pods"            = "20"
      }
      backend = {
        "requests.cpu"    = "4"
        "requests.memory" = "8Gi"
        "limits.cpu"      = "8"
        "limits.memory"   = "16Gi"
        "pods"            = "20"
      }
    }
    prod = {
      frontend = {
        "requests.cpu"    = "8"
        "requests.memory" = "16Gi"
        "limits.cpu"      = "16"
        "limits.memory"   = "32Gi"
        "pods"            = "50"
      }
      backend = {
        "requests.cpu"    = "8"
        "requests.memory" = "16Gi"
        "limits.cpu"      = "16"
        "limits.memory"   = "32Gi"
        "pods"            = "50"
      }
    }
  }

  # Limit ranges for containers
  limit_ranges = {
    frontend = {
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
      max = {
        cpu    = "2000m"
        memory = "2Gi"
      }
      min = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
    backend = {
      default = {
        cpu    = "1000m"
        memory = "1Gi"
      }
      default_request = {
        cpu    = "200m"
        memory = "256Mi"
      }
      max = {
        cpu    = "4000m"
        memory = "4Gi"
      }
      min = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}
