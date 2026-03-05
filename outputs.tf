# ============================================
# Output Values
# ============================================

# --------------------------------------------
# EKS Cluster Outputs
# --------------------------------------------
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificate authority data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider" {
  description = "OIDC provider URL without protocol"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = module.eks.oidc_provider_arn
}

# --------------------------------------------
# VPC Outputs
# --------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnets
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways"
  value       = module.vpc.nat_public_ips
}

# --------------------------------------------
# Node Group Outputs
# --------------------------------------------
output "eks_managed_node_groups" {
  description = "Map of EKS managed node groups attributes"
  value       = module.eks.eks_managed_node_groups
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of autoscaling group names"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

# --------------------------------------------
# IAM Outputs
# --------------------------------------------
output "admin_iam_role_arn" {
  description = "ARN of the admin IAM role"
  value       = aws_iam_role.admin.arn
}

output "developer_iam_role_arn" {
  description = "ARN of the developer IAM role"
  value       = aws_iam_role.developer.arn
}

output "jenkins_iam_role_arn" {
  description = "ARN of the Jenkins IAM role"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_instance_profile_name" {
  description = "Name of the Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins.name
}

# --------------------------------------------
# Namespace Outputs
# --------------------------------------------
output "namespace_names" {
  description = "Map of created namespace names"
  value = {
    frontend  = kubernetes_namespace.namespaces["frontend"].metadata[0].name
    backend   = kubernetes_namespace.namespaces["backend"].metadata[0].name
    monitoring = kubernetes_namespace.namespaces["monitoring"].metadata[0].name
    cicd      = kubernetes_namespace.namespaces["cicd"].metadata[0].name
  }
}

# --------------------------------------------
# Backup Outputs
# --------------------------------------------
output "backup_bucket_name" {
  description = "Name of the S3 bucket for backups"
  value       = var.enable_velero_backups ? aws_s3_bucket.velero_backups[0].id : null
}

output "backup_bucket_arn" {
  description = "ARN of the S3 bucket for backups"
  value       = var.enable_velero_backups ? aws_s3_bucket.velero_backups[0].arn : null
}

# --------------------------------------------
# Kubeconfig Command
# --------------------------------------------
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# --------------------------------------------
# Application Deployment Info
# --------------------------------------------
output "frontend_namespace" {
  description = "Namespace for frontend application"
  value       = "frontend"
}

output "backend_namespace" {
  description = "Namespace for backend application"
  value       = "backend"
}

output "frontend_service_account" {
  description = "Service account for frontend application"
  value       = kubernetes_service_account.frontend_sa.metadata[0].name
}

output "backend_service_account" {
  description = "Service account for backend application"
  value       = kubernetes_service_account.backend_sa.metadata[0].name
}

# --------------------------------------------
# Security Group Outputs
# --------------------------------------------
output "management_security_group_id" {
  description = "Security group ID for management access (whitelist your IP)"
  value       = length(aws_security_group.management) > 0 ? aws_security_group.management[0].id : null
}

output "whitelisted_ips" {
  description = "List of whitelisted IP addresses"
  value       = local.management_cidrs
}

# --------------------------------------------
# Important Notes
# --------------------------------------------
output "important_notes" {
  description = "Important notes about the deployment"
  value       = <<-EOT
    
    ============================================
    EKS CLUSTER DEPLOYED SUCCESSFULLY
    ============================================
    
    Cluster Name: ${module.eks.cluster_name}
    Kubernetes Version: ${module.eks.cluster_version}
    Environment: ${var.environment}
    
    NEXT STEPS:
    -----------
    1. Configure kubectl:
       aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
    
    2. Verify cluster access:
       kubectl get nodes
    
    3. Check add-ons:
       kubectl get pods -n kube-system
    
    4. Check namespaces:
       kubectl get namespaces
    
    NAMESPACES CREATED:
    -------------------
    - frontend: For React frontend application
    - backend: For Java backend application
    - monitoring: For observability tools
    - cicd: For CI/CD tooling
    
    RBAC CONFIGURED:
    ----------------
    - Admin role: Full cluster access
    - Developer role: Read-only access
    - Deployer role (Jenkins): Deploy access
    
    SECURITY FEATURES:
    ------------------
    - Network policies enabled for traffic isolation
    - Resource quotas configured per namespace
    - Limit ranges set for containers
    - Pod security standards enforced
    
    BACKUP & RECOVERY:
    ------------------
    - Velero installed for cluster backups
    - Daily backups scheduled at 2 AM
    - 30-day retention policy
    - Backup bucket: ${var.enable_velero_backups ? aws_s3_bucket.velero_backups[0].id : "N/A (backups disabled)"}
    
    ROLLBACK CAPABILITY:
    --------------------
    To rollback to a previous state:
    1. Velero backup: velero backup get
    2. Restore: velero restore create --from-backup <backup-name>
    3. Terraform state: Use Terraform state versioning in S3
    
    ============================================
  EOT
}
