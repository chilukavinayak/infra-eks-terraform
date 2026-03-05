# infra-eks-terraform - Agent Reference

## Project Overview

Production-ready EKS infrastructure for React (frontend) and Java (backend) Todo application with full CI/CD integration.

**Current Status**: ✅ Complete and Ready for Deployment

## Repository Structure

```
infra-eks-terraform/
├── README.md                          # Main documentation
├── QUICKSTART.md                      # Quick start guide
├── AGENTS.md                          # This file
├── .gitignore                         # Git ignore rules
├── .terraform-version                 # Terraform version (1.7.0)
├── versions.tf                        # Provider versions
├── providers.tf                       # AWS/K8s/Helm providers
├── backend.tf                         # S3/DynamoDB state backend
├── variables.tf                       # Input variables
├── outputs.tf                         # Output values
├── locals.tf                          # Local computed values
├── main.tf                            # Main infrastructure
├── helm_addons.tf                     # Helm chart deployments
├── namespaces.tf                      # K8s namespaces & security
├── backup.tf                          # Velero backup configuration
├── environments/                      # Environment configs
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
├── helm_values/                       # Helm values templates
│   └── prometheus-values.yaml
├── helm_charts/                       # Application Helm charts
│   ├── todo-frontend/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       ├── hpa.yaml
│   │       ├── pdb.yaml
│   │       ├── configmap.yaml
│   │       └── serviceaccount.yaml
│   └── todo-backend/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           ├── pdb.yaml
│           ├── configmap.yaml
│           ├── secret.yaml
│           └── serviceaccount.yaml
├── policies/                          # IAM policies
│   └── aws-load-balancer-controller.json
├── k8s_manifests/                     # Additional K8s manifests
├── scripts/                           # Utility scripts
└── docs/                              # Documentation
    ├── SETUP_GUIDE.md                 # Complete setup instructions
    ├── JENKINS_SETUP.md               # Jenkins EC2 setup
    ├── APPLICATION_DEVELOPMENT.md     # Frontend/backend repos
    ├── OPERATIONS.md                  # Day-to-day operations
    └── DISASTER_RECOVERY.md           # Backup/restore procedures
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                           AWS                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                         VPC                           │  │
│  │    Public Subnets    │    Private Subnets            │  │
│  │    ─────────────    │    ─────────────              │  │
│  │    ALB, NAT GW      │    EKS Nodes, Pods            │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    EKS Cluster                        │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐  │  │
│  │  │ frontend │ │ backend  │ │monitoring│ │  cicd   │  │  │
│  │  │Namespace │ │Namespace │ │Namespace │ │Namespace│  │  │
│  │  │          │ │          │ │          │ │         │  │  │
│  │  │ React    │ │ Java     │ │Prometheus│ │ Velero  │  │  │
│  │  │  (Nginx) │ │(Spring)  │ │ Grafana  │ │ Backup  │  │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### Infrastructure
- ✅ EKS 1.29 with managed node groups
- ✅ VPC with public/private/database subnets
- ✅ Auto-scaling (HPA + Cluster Autoscaler)
- ✅ Multi-AZ deployment

### Security
- ✅ Network Policies for namespace isolation
- ✅ Resource quotas and limit ranges
- ✅ RBAC (Admin, Developer, Deployer roles)
- ✅ Pod Security Standards
- ✅ KMS encryption

### Add-ons
- ✅ Cluster Autoscaler
- ✅ AWS Load Balancer Controller
- ✅ Metrics Server
- ✅ External DNS (optional)
- ✅ cert-manager (optional)
- ✅ Velero for backups

### Applications
- ✅ Helm charts for frontend (React)
- ✅ Helm charts for backend (Java)
- ✅ Auto-scaling configuration
- ✅ Rolling update strategy
- ✅ PDB for availability

## Environment Configuration

| Environment | Instance Type | Min Nodes | Max Nodes | Purpose |
|------------|---------------|-----------|-----------|---------|
| dev | t3.medium | 2 | 4 | Development |
| staging | t3.large | 2 | 6 | Testing |
| prod | m6i.large | 3 | 10 | Production |

## Deployment Commands

```bash
# Initialize
cd infra-eks-terraform
terraform init

# Deploy dev
terraform workspace new dev || terraform workspace select dev
terraform apply -var-file=environments/dev.tfvars

# Deploy staging
terraform workspace new staging || terraform workspace select staging
terraform apply -var-file=environments/staging.tfvars

# Deploy prod
terraform workspace new prod || terraform workspace select prod
terraform apply -var-file=environments/prod.tfvars

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name todo-app-dev

# Deploy apps
helm upgrade --install todo-frontend ./helm_charts/todo-frontend -n frontend
helm upgrade --install todo-backend ./helm_charts/todo-backend -n backend
```

## Namespaces

| Namespace | Purpose | Resource Quota |
|-----------|---------|----------------|
| frontend | React application | Yes (env-specific) |
| backend | Java application | Yes (env-specific) |
| monitoring | Prometheus/Grafana | No |
| cicd | Velero, etc. | No |
| kube-system | EKS add-ons | No |
| cert-manager | TLS certificates | No |
| velero | Backups | No |

## Important File Locations

### Configuration
- `variables.tf` - All configurable variables
- `environments/*.tfvars` - Environment-specific values
- `locals.tf` - Computed values and logic

### Helm Charts
- `helm_charts/todo-frontend/` - Frontend deployment
- `helm_charts/todo-backend/` - Backend deployment
- `helm_values/prometheus-values.yaml` - Monitoring config

### Policies
- `policies/aws-load-balancer-controller.json` - ALB IAM policy

### Documentation
- `README.md` - Main documentation
- `QUICKSTART.md` - Quick start
- `docs/SETUP_GUIDE.md` - Detailed setup
- `docs/JENKINS_SETUP.md` - CI/CD setup
- `docs/APPLICATION_DEVELOPMENT.md` - App repos
- `docs/OPERATIONS.md` - Operations
- `docs/DISASTER_RECOVERY.md` - DR procedures

## Common Operations

### Backup
```bash
velero backup create manual-backup-$(date +%Y%m%d)
```

### Restore
```bash
velero restore create --from-backup <backup-name>
```

### Scale
```bash
kubectl scale deployment todo-frontend --replicas=5 -n frontend
```

### Rollback
```bash
helm rollback todo-frontend 1 -n frontend
```

## Rollback Procedures

### Application Rollback
```bash
# Helm rollback
helm rollback todo-frontend 1 -n frontend

# Or kubectl rollback
kubectl rollout undo deployment/todo-frontend -n frontend
```

### Infrastructure Rollback
```bash
# Use Terraform state versioning in S3
aws s3api list-object-versions \
  --bucket todo-app-tfstate-<account-id> \
  --prefix eks/terraform.tfstate

# Restore previous version
aws s3api get-object \
  --bucket todo-app-tfstate-<account-id> \
  --key eks/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate
```

### Velero Restore
```bash
# List backups
velero backup get

# Restore
velero restore create --from-backup daily-backup-20240115
```

## Security Considerations

### Network
- Network policies isolate frontend/backend traffic
- Only frontend namespace exposed via ALB
- DNS traffic restricted to kube-system

### RBAC
- `admin` - Full cluster access
- `developer` - Read-only access
- `deployer` (Jenkins) - Deploy access

### Pod Security
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
```

## Cost Optimization

### Dev Environment
- Single NAT Gateway
- Spot instances for non-prod
- Reduced monitoring

### All Environments
- Cluster Autoscaler for right-sizing
- HPA for pod scaling
- EBS gp3 volumes

## Dependencies

### Required
- AWS Account with admin access
- Terraform >= 1.5.0
- AWS CLI configured
- kubectl
- Helm >= 3.0

### Optional
- Domain name (for TLS)
- Route53 hosted zone
- GitHub repos for apps

## Troubleshooting

### Node Not Joining
```bash
kubectl describe node <node-name>
kubectl logs -n kube-system deployment/cluster-autoscaler
```

### ALB Not Creating
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
aws ec2 describe-subnets --subnet-ids <subnet-id>
```

### Pods Pending
```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl describe resourcequota -n <namespace>
```

## Testing

```bash
# Validate Terraform
terraform fmt -check -recursive
terraform validate

# Plan changes
terraform plan -var-file=environments/dev.tfvars

# Check Helm charts
helm lint ./helm_charts/todo-frontend
helm lint ./helm_charts/todo-backend

# Dry run
helm template todo-frontend ./helm_charts/todo-frontend
```

## Maintenance

### Monthly
- Review and update AMI versions
- Check for deprecated APIs
- Test backup/restore
- Review costs

### Quarterly
- Update Kubernetes version
- Review and rotate credentials
- Security audit
- DR drill

## Support Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://docs.aws.amazon.com/eks/latest/best-practices/)
- [Helm Documentation](https://helm.sh/docs/)
- [Velero Documentation](https://velero.io/docs/)

---

**Maintained by**: Platform Team  
**Last Updated**: 2024  
**Terraform Version**: 1.7.0  
**EKS Version**: 1.29
