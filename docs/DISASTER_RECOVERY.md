# Disaster Recovery Guide

This guide provides procedures for recovering from various disaster scenarios.

## 📋 Recovery Scenarios

1. [Application Data Loss](#1-application-data-loss)
2. [Kubernetes Cluster Failure](#2-kubernetes-cluster-failure)
3. [Complete Infrastructure Loss](#3-complete-infrastructure-loss)
4. [Regional Outage](#4-regional-outage)
5. [Terraform State Corruption](#5-terraform-state-corruption)

## 1. Application Data Loss

### Scenario
Application data (todos) is lost or corrupted.

### Recovery Steps

#### 1.1 Identify Last Good Backup

```bash
# List available backups
velero backup get

# Describe specific backup
velero backup describe daily-backup-20240115

# Check backup contents
velero backup describe daily-backup-20240115 --details
```

#### 1.2 Restore from Backup

```bash
# Create restore
velero restore create restore-from-backup-20240115 \
  --from-backup daily-backup-20240115 \
  --include-namespaces backend \
  --wait

# Check restore status
velero restore get

# Verify restore
velero restore describe restore-from-backup-20240115
```

#### 1.3 Verify Application

```bash
# Check pods are running
kubectl get pods -n backend

# Check application logs
kubectl logs -n backend -l app.kubernetes.io/name=todo-backend

# Test API
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://todo-backend.backend.svc.cluster.local:8080/api/todos
```

### Prevention
- Daily automated backups at 2 AM
- 30-day backup retention
- Test restores monthly

---

## 2. Kubernetes Cluster Failure

### Scenario
EKS cluster becomes unavailable or corrupted.

### Recovery Steps

#### 2.1 Assess Cluster Status

```bash
# Check cluster status
aws eks describe-cluster --name todo-app-prod

# Check node status
aws eks describe-nodegroup --cluster-name todo-app-prod --nodegroup-name general-workloads
```

#### 2.2 If Cluster is Recoverable

```bash
# Try updating cluster
aws eks update-cluster-config --name todo-app-prod

# Recreate node group if needed
aws eks create-nodegroup \
  --cluster-name todo-app-prod \
  --nodegroup-name general-workloads-new \
  --subnets <subnet-ids> \
  --node-role <role-arn>
```

#### 2.3 If Cluster Must be Recreated

```bash
# 1. Destroy current resources
terraform workspace select prod
terraform destroy -var-file=environments/prod.tfvars

# 2. Recreate infrastructure
terraform apply -var-file=environments/prod.tfvars

# 3. Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name todo-app-prod

# 4. Restore from Velero backup
velero restore create --from-backup <latest-backup>

# 5. Redeploy applications
helm upgrade --install todo-frontend ./helm_charts/todo-frontend -n frontend
helm upgrade --install todo-backend ./helm_charts/todo-backend -n backend
```

---

## 3. Complete Infrastructure Loss

### Scenario
All infrastructure is lost (VPC, EKS, etc.).

### Recovery Steps

#### 3.1 Prerequisites

- Access to Terraform state backend (S3)
- AWS credentials
- Domain DNS access

#### 3.2 Recover Terraform State

```bash
# If state backend exists
aws s3 ls s3://todo-app-tfstate-<account-id>/

# Download state
aws s3 cp s3://todo-app-tfstate-<account-id>/eks/terraform.tfstate ./

# Initialize Terraform
terraform init
```

#### 3.3 Recreate Infrastructure

```bash
# Select workspace
terraform workspace select prod

# Plan and apply
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

#### 3.4 Restore Applications

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name todo-app-prod

# Install Velero (if not restored by Terraform)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket todo-app-backups-<account-id>-us-west-2 \
  --backup-location-config region=us-west-2 \
  --snapshot-location-config region=us-west-2 \
  --secret-file ./credentials-velero

# Restore from backup
velero restore create --from-backup <latest-backup>

# Or redeploy manually
helm upgrade --install todo-frontend ./helm_charts/todo-frontend \
  --namespace frontend \
  --set image.repository=<account>.dkr.ecr.us-west-2.amazonaws.com/todo-frontend \
  --set image.tag=latest

helm upgrade --install todo-backend ./helm_charts/todo-backend \
  --namespace backend \
  --set image.repository=<account>.dkr.ecr.us-west-2.amazonaws.com/todo-backend \
  --set image.tag=latest
```

#### 3.5 Update DNS

```bash
# Get new ALB URL
kubectl get ingress -n frontend -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# Update Route53 records
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://dns-update.json
```

---

## 4. Regional Outage

### Scenario
Complete AWS region outage.

### Recovery Steps

#### 4.1 Activate DR Region

```bash
# Switch to DR region configuration
export AWS_REGION=us-east-1

# Clone infrastructure repo
git clone <repo-url>
cd infra-eks-terraform

# Create DR workspace
terraform workspace new prod-dr

# Update variables for DR region
cat > environments/prod-dr.tfvars << EOF
environment = "prod-dr"
aws_region = "us-east-1"
vpc_cidr = "10.3.0.0/16"
# ... other settings
EOF

# Deploy DR infrastructure
terraform apply -var-file=environments/prod-dr.tfvars
```

#### 4.2 Restore Data in DR Region

```bash
# Velero backup bucket is cross-region replicated
# Or restore from S3 backup
aws s3 sync s3://todo-app-backups-primary/velero/backups/ s3://todo-app-backups-dr/velero/backups/

# Restore in DR cluster
aws eks update-kubeconfig --region us-east-1 --name todo-app-prod-dr
velero restore create --from-backup <latest-backup>
```

#### 4.3 Update DNS Failover

```bash
# Update Route53 failover records
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://failover-to-dr.json
```

---

## 5. Terraform State Corruption

### Scenario
Terraform state file is corrupted or lost.

### Recovery Steps

#### 5.1 From S3 Versioning

```bash
# List state versions
aws s3api list-object-versions \
  --bucket todo-app-tfstate-<account-id> \
  --prefix eks/terraform.tfstate

# Get specific version
aws s3api get-object \
  --bucket todo-app-tfstate-<account-id> \
  --key eks/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.recovered

# Use recovered state
terraform state pull > current-state.json
cp terraform.tfstate.recovered terraform.tfstate
terraform state push terraform.tfstate
```

#### 5.2 From Local Backup

```bash
# If you have local backup
cp backup/terraform.tfstate.backup.<date> terraform.tfstate
terraform state push terraform.tfstate
```

#### 5.3 Reconstruct State (Last Resort)

```bash
# Import existing resources
terraform import module.eks.aws_eks_cluster.this <cluster-name>
terraform import module.vpc.aws_vpc.this <vpc-id>
# ... import other resources

# Verify state
terraform state list
terraform plan
```

---

## 🔄 Recovery Testing

### Monthly DR Drill

1. **Schedule**: First Saturday of each month
2. **Duration**: 2-4 hours
3. **Scope**: Test one scenario at a time

### Test Procedure

```bash
# 1. Announce test
# 2. Create test environment
cd infra-eks-terraform
terraform workspace new dr-test

# 3. Run recovery procedure
# 4. Verify functionality
# 5. Document findings
# 6. Cleanup
terraform destroy -var-file=environments/dev.tfvars
terraform workspace select dev
terraform workspace delete dr-test
```

### Validation Checklist

- [ ] Infrastructure recreated successfully
- [ ] Applications deployed and running
- [ ] Data restored correctly
- [ ] DNS updated and propagated
- [ ] SSL certificates valid
- [ ] Monitoring functional
- [ ] CI/CD pipelines working

---

## 📞 Emergency Contacts

| Role | Contact | Responsibility |
|------|---------|----------------|
| Primary On-Call | oncall@company.com | Initial response |
| Infrastructure Lead | infra-lead@company.com | Infrastructure decisions |
| Engineering Manager | eng-mgr@company.com | Business coordination |
| AWS Support | AWS Console | AWS infrastructure issues |

## 📋 Recovery Time Objectives

| Component | RTO | RPO |
|-----------|-----|-----|
| Application | 30 minutes | 24 hours |
| Data | 1 hour | 1 hour |
| Infrastructure | 2 hours | 24 hours |
| Complete DR | 4 hours | 24 hours |

---

**Note**: Keep this document updated with current contact information and procedures.
