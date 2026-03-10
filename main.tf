# ============================================
# EKS Infrastructure - Main Configuration
# ============================================

# --------------------------------------------
# VPC Module
# --------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # Database subnets for future use (RDS, etc.)
  database_subnets = var.database_subnet_cidrs

  # NAT Gateway configuration
  enable_nat_gateway     = true
  single_nat_gateway     = var.environment == "dev"
  one_nat_gateway_per_az = var.environment != "dev"
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true
  flow_log_max_aggregation_interval    = 60

  # Tags for Kubernetes integration
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
    "Type"                                        = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
    "Type"                                        = "private"
  }

  tags = local.common_tags
}

# --------------------------------------------
# EKS Cluster Module
# --------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # VPC Configuration
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnets
  control_plane_subnet_ids  = module.vpc.private_subnets

  # Cluster API Access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Cluster Logging
  cluster_enabled_log_types = var.cluster_enabled_log_types

  # Encryption
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = local.node_groups

  # Fargate Profiles (optional - for serverless workloads)
  fargate_profiles = var.environment == "dev" ? {
    default = {
      name = "default"
      selectors = [
        { namespace = "kube-system" },
        { namespace = "default" }
      ]
    }
  } : {}

  # Authentication Mode (for EKS API)
  authentication_mode                        = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions   = false

  # Access Entries (new way in v20.x)
  access_entries = {
    # Current user (Vinayak) - Terraform operator
    terraform_user = {
      principal_arn = data.aws_caller_identity.current.arn
      type          = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    # IAM role for admin access
    admin_role = {
      principal_arn = aws_iam_role.admin.arn
      type          = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    developer = {
      principal_arn = aws_iam_role.developer.arn
      type          = "STANDARD"
      policy_associations = {
        view = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    jenkins = {
      principal_arn = aws_iam_role.jenkins.arn
      type          = "STANDARD"
      policy_associations = {
        edit = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Tags
  tags = local.common_tags

  depends_on = [module.vpc]
}

# --------------------------------------------
# KMS Key for EKS Encryption
# --------------------------------------------
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-eks-encryption"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# --------------------------------------------
# IAM Roles
# --------------------------------------------

# Admin Role
resource "aws_iam_role" "admin" {
  name = "${local.cluster_name}-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Developer Role
resource "aws_iam_role" "developer" {
  name = "${local.cluster_name}-developer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Jenkins CI/CD Role
resource "aws_iam_role" "jenkins" {
  name = "${local.cluster_name}-jenkins"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Jenkins Instance Profile
resource "aws_iam_instance_profile" "jenkins" {
  name = "${local.cluster_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name

  tags = local.common_tags
}

# Jenkins IAM Policy for ECR and other CI/CD permissions
resource "aws_iam_role_policy" "jenkins" {
  name = "${local.cluster_name}-jenkins-policy"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:ListRepositories"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = var.enable_velero_backups ? [
          aws_s3_bucket.velero_backups[0].arn,
          "${aws_s3_bucket.velero_backups[0].arn}/*"
        ] : ["*"]
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.eks.arn
      }
    ]
  })
}

# --------------------------------------------
# Security Group for Management Access
# This security group allows access from your IP address
# --------------------------------------------

locals {
  # Combine all allowed CIDRs
  management_cidrs = distinct(compact(concat(
    var.allowed_management_cidrs,
    var.my_ip_address != "" ? [var.my_ip_address] : []
  )))
}

# Security group for cluster management access
resource "aws_security_group" "management" {
  count = length(local.management_cidrs) > 0 ? 1 : 0

  name_prefix = "${local.cluster_name}-management-"
  description = "Security group for management access from whitelisted IPs"
  vpc_id      = module.vpc.vpc_id

  # Allow HTTPS access for kubectl
  ingress {
    description = "Kubernetes API access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.management_cidrs
  }

  # Allow HTTP access (for ALB/ingress testing)
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.management_cidrs
  }

  # Allow port 8080 access (Jenkins UI, kubectl port-forward)
  ingress {
    description = "Port 8080 access (Jenkins, port-forward)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = local.management_cidrs
  }

  # Allow SSH access if needed
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-management"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security group rule for EKS cluster endpoint access
resource "aws_security_group_rule" "cluster_management_access" {
  count = length(local.management_cidrs) > 0 ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.management[0].id
  security_group_id        = module.eks.cluster_security_group_id
  description              = "Allow management access from whitelisted IPs"
}

# --------------------------------------------
# Security Group for Jenkins EC2 Instance
# This security group allows access to Jenkins UI
# --------------------------------------------

resource "aws_security_group" "jenkins" {
  count = length(local.management_cidrs) > 0 ? 1 : 0

  name_prefix = "${local.cluster_name}-jenkins-"
  description = "Security group for Jenkins CI/CD server"
  vpc_id      = module.vpc.vpc_id

  # Allow Jenkins UI access (port 8080)
  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = local.management_cidrs
  }

  # Allow SSH access
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # Allow HTTP (for webhook)
  ingress {
    description = "HTTP for GitHub webhook"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-jenkins"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------
# EKS Add-ons
# --------------------------------------------
resource "aws_eks_addon" "core_dns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.core_dns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [module.eks]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi_driver.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [module.eks]
}

# Data sources for addon versions
data "aws_eks_addon_version" "core_dns" {
  addon_name         = "coredns"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

# --------------------------------------------
# IAM Role for EBS CSI Driver
# --------------------------------------------
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${local.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}
