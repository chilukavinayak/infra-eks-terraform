# ============================================
# Backup and Recovery Configuration (Velero)
# ============================================

# S3 Bucket for Velero Backups
resource "aws_s3_bucket" "velero_backups" {
  count = var.enable_velero_backups ? 1 : 0

  bucket = local.backup_bucket

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-velero-backups"
  })
}

resource "aws_s3_bucket_versioning" "velero_backups" {
  count = var.enable_velero_backups ? 1 : 0

  bucket = aws_s3_bucket.velero_backups[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_backups" {
  count = var.enable_velero_backups ? 1 : 0

  bucket = aws_s3_bucket.velero_backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.velero[0].arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "velero_backups" {
  count = var.enable_velero_backups ? 1 : 0

  bucket = aws_s3_bucket.velero_backups[0].id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "velero_backups" {
  count = var.enable_velero_backups ? 1 : 0

  bucket = aws_s3_bucket.velero_backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# KMS Key for Velero Encryption
resource "aws_kms_key" "velero" {
  count = var.enable_velero_backups ? 1 : 0

  description             = "KMS key for Velero backup encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-velero-key"
  })
}

resource "aws_kms_alias" "velero" {
  count = var.enable_velero_backups ? 1 : 0

  name          = "alias/${local.cluster_name}-velero"
  target_key_id = aws_kms_key.velero[0].key_id
}

# IAM Role for Velero
resource "aws_iam_role" "velero" {
  count = var.enable_velero_backups ? 1 : 0

  name = "${local.cluster_name}-velero"

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
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:velero:velero"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "velero" {
  count = var.enable_velero_backups ? 1 : 0

  name = "${local.cluster_name}-velero"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.velero_backups[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.velero_backups[0].arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "velero" {
  count = var.enable_velero_backups ? 1 : 0

  policy_arn = aws_iam_policy.velero[0].arn
  role       = aws_iam_role.velero[0].name
}

# Helm Release for Velero
resource "helm_release" "velero" {
  count = var.enable_velero_backups ? 1 : 0

  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = "5.1.0"
  namespace  = "velero"

  create_namespace = true

  set {
    name  = "configuration.backupStorageLocation[0].name"
    value = "default"
  }

  set {
    name  = "configuration.backupStorageLocation[0].provider"
    value = "aws"
  }

  set {
    name  = "configuration.backupStorageLocation[0].bucket"
    value = aws_s3_bucket.velero_backups[0].id
  }

  set {
    name  = "configuration.backupStorageLocation[0].prefix"
    value = "backups"
  }

  set {
    name  = "configuration.backupStorageLocation[0].config.region"
    value = var.aws_region
  }

  set {
    name  = "configuration.volumeSnapshotLocation[0].name"
    value = "default"
  }

  set {
    name  = "configuration.volumeSnapshotLocation[0].provider"
    value = "aws"
  }

  set {
    name  = "configuration.volumeSnapshotLocation[0].config.region"
    value = var.aws_region
  }

  set {
    name  = "serviceAccount.server.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.server.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.velero[0].arn
  }

  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-aws"
  }

  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-aws:v1.8.0"
  }

  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }

  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }

  # Default backup schedule
  set {
    name  = "schedules.daily.schedule"
    value = "0 2 * * *"
  }

  set {
    name  = "schedules.daily.template.ttl"
    value = "720h0m0s"  # 30 days retention
  }

  set {
    name  = "schedules.daily.template.storageLocation"
    value = "default"
  }

  set {
    name  = "schedules.daily.template.volumeSnapshotLocations[0]"
    value = "aws"
  }

  # Disable the upgrade CRDs job that causes issues
  # CRDs will be managed manually or during initial install
  set {
    name  = "upgradeCRDs"
    value = "false"
  }

  set {
    name  = "cleanUpCRDs"
    value = "false"
  }

  depends_on = [module.eks, aws_iam_role_policy_attachment.velero]
}
