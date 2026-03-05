# Tresvita EKS Infrastructure - Managed by Wissen Team

This repository contains production-ready Terraform code for deploying an AWS EKS (Elastic Kubernetes Service) cluster with full CI/CD integration for Tresvita's React frontend and Java Spring Boot backend application.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Environment Configuration](#environment-configuration)
- [Deployment Guide](#deployment-guide)
- [Application Deployment](#application-deployment)
- [Backup and Recovery](#backup-and-recovery)
- [Monitoring](#monitoring)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Tresvita AWS Cloud                                │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                              VPC                                      │  │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │  │
│  │  │  Public     │    │  Private    │    │      Database           │  │  │
│  │  │  Subnets    │    │  Subnets    │    │      Subnets            │  │  │
│  │  │             │    │             │    │                         │  │  │
│  │  │  ALB        │    │  EKS Nodes  │    │  (Future RDS)           │  │  │
│  │  │  NAT GW     │    │  Pods       │    │                         │  │  │
│  │  └─────────────┘    └─────────────┘    └─────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │              Tresvita EKS Cluster (Managed by Wissen)               │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────┐ │    │
│  │  │   Frontend   │  │   Backend    │  │  Monitoring  │  │  CI/CD  │ │    │
│  │  │  Namespace   │  │  Namespace   │  │  Namespace   │  │Namespace│ │    │
│  │  │              │  │              │  │              │  │         │ │    │
│  │  │ React App    │  │  Java API    │  │ Prometheus   │  │  Velero │ │    │
│  │  │  (Nginx)     │  │(Spring Boot) │  │  Grafana     │  │  etc.   │ │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └─────────┘ │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## ✨ Features

### Infrastructure
- ✅ **Production-ready EKS cluster** with latest Kubernetes version
- ✅ **Multi-environment support** (dev, staging, prod) for Tresvita
- ✅ **Auto-scaling** with Cluster Autoscaler and HPA
- ✅ **VPC with public/private subnets** across multiple AZs
- ✅ **NAT Gateways** for secure outbound connectivity
- ✅ **Network isolation** with Network Policies

### Security
- ✅ **Pod Security Standards** enforced
- ✅ **Resource quotas and limits** per namespace
- ✅ **RBAC** with separate roles for admin, developer, and deployer
- ✅ **Network policies** for traffic isolation
- ✅ **KMS encryption** for secrets and state
- ✅ **AWS Load Balancer Controller** with SSL termination

### Backup & Recovery
- ✅ **Velero** for cluster backups
- ✅ **S3 versioning** for state and backups
- ✅ **Daily scheduled backups** with 30-day retention
- ✅ **Easy restore** capability

### Monitoring
- ✅ **Prometheus & Grafana** (staging/prod)
- ✅ **Metrics Server** for resource metrics
- ✅ **CloudWatch Logs** for control plane
- ✅ **VPC Flow Logs** for network monitoring

### Add-ons
- ✅ **Cluster Autoscaler**
- ✅ **AWS Load Balancer Controller**
- ✅ **External DNS** (optional)
- ✅ **cert-manager** for TLS (optional)
- ✅ **Metrics Server**
- ✅ **EBS CSI Driver**

## 📋 Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.5.0
4. **kubectl** installed
5. **Helm** >= 3.0
6. **Domain name** (for production with TLS)

### Required AWS Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:*",
        "kms:*",
        "logs:*",
        "route53:*",
        "s3:*",
        "dynamodb:*",
        "autoscaling:*",
        "elasticloadbalancing:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🚀 Quick Start

### 1. Clone and Initialize

```bash
cd infra-eks-terraform
terraform init
```

### 2. Configure AWS Credentials

```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: us-west-2
# Output format: json

# Verify
aws sts get-caller-identity
```

### 3. Deploy Development Environment

```bash
# Create and select workspace
terraform workspace new dev
terraform workspace select dev

# Review and deploy (takes ~15-20 minutes)
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars

# ⚠️ If you see "access entry already exists" error:
# terraform import 'module.eks.aws_eks_access_entry.this["terraform_user"]' 'tresvita-todo-app-dev:arn:aws:iam::845844106369:user/Vinayak'
# terraform apply -var-file=environments/dev.tfvars
```

### 4. Configure kubectl

```bash
# Install kubectl if not already installed
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mkdir -p /usr/local/bin
sudo mv kubectl /usr/local/bin/

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev
```

### 5. Verify Deployment

```bash
# Check cluster nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check Tresvita namespaces
kubectl get namespaces
```

## 🔧 Environment Configuration

The infrastructure uses the same configuration across all Tresvita environments, only scaling differs:

| Environment | Instance Type | Min Nodes | Max Nodes | Features |
|------------|---------------|-----------|-----------|----------|
| Dev | t3.medium | 2 | 4 | Basic monitoring |
| Staging | t3.large | 2 | 6 | Full monitoring |
| Prod | m6i.large | 3 | 10 | Full monitoring + alerting |

### Configuration Files

- `environments/dev.tfvars` - Tresvita Development environment
- `environments/staging.tfvars` - Tresvita Staging environment  
- `environments/prod.tfvars` - Tresvita Production environment

## 📦 Deployment Guide

### Step 1: Create State Backend (First Time Only)

The state backend resources are created automatically. After first apply, update `backend.tf`:

```bash
# Get the state bucket name
terraform output state_bucket_name

# Update backend.tf with the actual bucket name
# Uncomment the backend block and update values
```

### Step 2: Deploy Infrastructure

```bash
# Development
terraform workspace new dev || terraform workspace select dev
terraform apply -var-file=environments/dev.tfvars

# Staging
terraform workspace new staging || terraform workspace select staging
terraform apply -var-file=environments/staging.tfvars

# Production
terraform workspace new prod || terraform workspace select prod
terraform apply -var-file=environments/prod.tfvars
```

### Step 3: Verify Cluster Access

```bash
# Test cluster connectivity
kubectl cluster-info

# View nodes
kubectl get nodes -o wide

# View all namespaces
kubectl get namespaces
```

## 🚀 Application Deployment

### Using Helm Charts

The repository includes Helm charts for both Tresvita frontend and backend:

```bash
# Get AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Deploy Frontend
helm upgrade --install tresvita-todo-frontend ./helm_charts/todo-frontend \
  --namespace frontend \
  --set image.repository=${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend \
  --set image.tag=v1.0.0

# Deploy Backend
helm upgrade --install tresvita-todo-backend ./helm_charts/todo-backend \
  --namespace backend \
  --set image.repository=${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend \
  --set image.tag=v1.0.0
```

### Rolling Updates

```bash
# Update frontend
helm upgrade tresvita-todo-frontend ./helm_charts/todo-frontend \
  --namespace frontend \
  --set image.tag=v1.1.0

# Watch rollout
kubectl rollout status deployment/tresvita-todo-frontend -n frontend
```

### Rollback

```bash
# Helm rollback
helm rollback tresvita-todo-frontend 1 -n frontend

# Or kubectl rollback
kubectl rollout undo deployment/tresvita-todo-frontend -n frontend
```

## 💾 Backup and Recovery

### Automatic Backups

Velero is configured to create daily backups at 2 AM with 30-day retention.

### Manual Backup

```bash
# Create on-demand backup
velero backup create manual-backup-$(date +%Y%m%d)

# Check backup status
velero backup get
```

### Restore from Backup

```bash
# List available backups
velero backup get

# Restore specific backup
velero restore create --from-backup manual-backup-20240115

# Restore to different namespace
velero restore create --from-backup manual-backup-20240115 \
  --namespace-mappings frontend:frontend-restore
```

### Terraform State Recovery

State is stored in S3 with versioning enabled:

```bash
# List state versions
aws s3api list-object-versions \
  --bucket tresvita-todo-app-tfstate-<account-id> \
  --prefix eks/terraform.tfstate

# Restore previous version
aws s3api get-object \
  --bucket tresvita-todo-app-tfstate-<account-id> \
  --key eks/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.backup
```

## 📊 Monitoring

### Accessing Grafana (Staging/Prod)

```bash
# Port-forward to Grafana
kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring

# Access at http://localhost:3000
# Default credentials: admin/admin
```

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| CPU Usage | Container CPU utilization | > 80% |
| Memory Usage | Container memory utilization | > 85% |
| Pod Restarts | Number of pod restarts | > 5 in 1h |
| Disk Usage | Node disk utilization | > 85% |
| API Latency | Request latency | > 500ms |

### CloudWatch Logs

```bash
# View cluster logs
aws logs tail /aws/eks/tresvita-todo-app-dev/cluster --follow
```

## 🔒 Security

### Network Policies

Traffic is restricted between namespaces:
- Frontend can only receive traffic from ALB
- Backend only accepts traffic from frontend namespace
- DNS traffic allowed to kube-system

### RBAC

| Role | Permissions |
|------|-------------|
| Admin | Full cluster access |
| Developer | Read-only access to all resources |
| Deployer (Jenkins) | Create/update/delete deployments |

### Pod Security

```yaml
# Enforced standards
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
    - securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

## 🔧 Troubleshooting

### Common Issues

#### Access Entry Already Exists

```bash
# Import the existing access entry into Terraform state
terraform import 'module.eks.aws_eks_access_entry.this["terraform_user"]' 'tresvita-todo-app-dev:arn:aws:iam::845844106369:user/Vinayak'

# Then re-run apply
terraform apply -var-file=environments/dev.tfvars
```

#### Kubernetes Cluster Unreachable

```bash
# Ensure AWS credentials are configured
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev

# Verify access
kubectl get nodes
```

#### kubectl Not Found (EC2)

```bash
# Download and install kubectl
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mkdir -p /usr/local/bin
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

#### Nodes Not Joining

```bash
# Check node status
kubectl describe node <node-name>

# Check autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler
```

#### ALB Not Creating

```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify subnets are tagged
aws ec2 describe-subnets --subnet-ids <subnet-id>
```

#### Pods Stuck Pending

```bash
# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check resource quotas
kubectl describe resourcequota -n <namespace>
```

#### Image Pull Errors

```bash
# Verify ECR login
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-west-2.amazonaws.com

# Check image exists
aws ecr describe-images --repository-name tresvita-todo-backend
```

### Useful Commands

```bash
# Debug pod
kubectl run debug --rm -it --image=nicolaka/netshoot -- /bin/bash

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check network policies
kubectl get networkpolicies --all-namespaces

# Check RBAC
kubectl auth can-i --list
```

## 📚 Additional Documentation

- [Complete Setup Guide](docs/SETUP_GUIDE.md) - Step-by-step setup instructions
- [Jenkins CI/CD Setup](docs/JENKINS_SETUP.md) - Jenkins EC2 setup and configuration
- [Application Development](docs/APPLICATION_DEVELOPMENT.md) - Frontend and backend repo setup
- [Operations Runbook](docs/OPERATIONS.md) - Day-to-day operations guide
- [Disaster Recovery](docs/DISASTER_RECOVERY.md) - Detailed recovery procedures

## 🤝 Contributing (Wissen Team)

1. Create a feature branch
2. Make changes
3. Run `terraform fmt -recursive`
4. Run `terraform validate`
5. Submit pull request

## 📄 License

This project is licensed under the MIT License.

---

**Client**: Tresvita  
**Managed by**: Wissen Team  
**Terraform Version**: 1.7.0  
**EKS Version**: 1.29  
**Last Updated**: 2024


### kubectl Connection Timeout / i/o timeout

**Error:** `dial tcp 10.0.x.x:443: i/o timeout`

The cluster endpoint may be private-only. Enable public access:

```bash
# Enable public endpoint
aws eks update-cluster-config \
  --region us-west-2 \
  --name tresvita-todo-app-dev \
  --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=0.0.0.0/0

# Wait and refresh kubeconfig
aws eks wait cluster-active --region us-west-2 --name tresvita-todo-app-dev
rm -rf ~/.kube/config
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev
kubectl get nodes
```

Or connect via an EC2 instance (Jenkins server) in the same VPC.


### kubectl Still Times Out (EC2 in Same VPC)

If kubectl still shows `dial tcp 10.0.x.x:443: i/o timeout` after enabling public endpoint:

**Cause:** EC2 is in the same VPC as EKS → DNS resolves to private IPs

**Fix - Add Outbound HTTPS Rule to EC2 Security Group:**
```bash
# Get EC2 security group ID
export EC2_SG_ID=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
  --output text)

# Add outbound HTTPS rule
aws ec2 authorize-security-group-egress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Test
kubectl get nodes
```

Or test from your local laptop instead of EC2.
