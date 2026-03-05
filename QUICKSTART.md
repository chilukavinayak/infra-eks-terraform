# Tresvita EKS Quick Start Guide

**Managed by Wissen Team**

Get Tresvita's production-ready EKS infrastructure up and running in 30 minutes.

## ⚡ Prerequisites (5 min)

```bash
# Check tools
terraform version  # >= 1.7.0
aws --version      # >= 2.0
kubectl version    # >= 1.25
helm version       # >= 3.0

# Configure AWS
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: us-west-2
# Output format: json

# Verify AWS access
aws sts get-caller-identity
```

**For EC2 Instances:**
```bash
# Create credentials file
mkdir -p ~/.aws
cat > ~/.aws/credentials << 'EOF'
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
EOF
chmod 600 ~/.aws/credentials

# Install kubectl if needed
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mkdir -p /usr/local/bin
sudo mv kubectl /usr/local/bin/
```

## 🚀 Deploy Infrastructure (20 min)

```bash
# 1. Clone and enter directory
cd infra-eks-terraform

# 2. Initialize Terraform
terraform init

# 3. Create and select dev workspace
terraform workspace new dev
terraform workspace select dev

# 4. Deploy (takes ~15-20 minutes)
terraform apply -var-file=environments/dev.tfvars -auto-approve

# ⚠️ If access entry error occurs, import existing entry first:
# terraform import 'module.eks.aws_eks_access_entry.this["terraform_user"]' 'tresvita-todo-app-dev:arn:aws:iam::845844106369:user/Vinayak'
# Then re-run: terraform apply -var-file=environments/dev.tfvars

# 5. Configure kubectl (correct cluster name)
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev

# 6. Verify
kubectl get nodes
kubectl get pods -n kube-system
kubectl get namespaces
```

## 🎯 Deploy Applications (5 min)

```bash
# Create ECR repos
aws ecr create-repository --repository-name tresvita-todo-frontend
aws ecr create-repository --repository-name tresvita-todo-backend

# Get AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Build and push images (from app repos)
cd ../todo-frontend-eks
docker build -t tresvita-todo-frontend:v1.0.0 .
docker tag tresvita-todo-frontend:v1.0.0 ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend:v1.0.0
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend:v1.0.0

cd ../todo-backend-eks
./mvnw clean package -DskipTests
docker build -t tresvita-todo-backend:v1.0.0 .
docker tag tresvita-todo-backend:v1.0.0 ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend:v1.0.0
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend:v1.0.0

# Deploy with Helm
cd ../infra-eks-terraform
helm upgrade --install tresvita-todo-frontend ./helm_charts/todo-frontend \
  --namespace frontend \
  --set image.repository=${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend \
  --set image.tag=v1.0.0

helm upgrade --install tresvita-todo-backend ./helm_charts/todo-backend \
  --namespace backend \
  --set image.repository=${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend \
  --set image.tag=v1.0.0
```

## ✅ Verify

```bash
# Check all pods
kubectl get pods --all-namespaces

# Get application URLs
kubectl get ingress -n frontend -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
kubectl get ingress -n backend -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# Test backend API
export BACKEND_URL=$(kubectl get ingress -n backend -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
curl http://${BACKEND_URL}/api/todos
curl http://${BACKEND_URL}/api/actuator/health
```

## 📚 Next Steps

1. [Complete Setup Guide](docs/SETUP_GUIDE.md) - Detailed instructions
2. [Jenkins Setup](docs/JENKINS_SETUP.md) - CI/CD configuration
3. [Application Development](docs/APPLICATION_DEVELOPMENT.md) - App repos setup
4. [Operations](docs/OPERATIONS.md) - Day-to-day operations
5. [Disaster Recovery](docs/DISASTER_RECOVERY.md) - Backup procedures

## 🔧 Common Commands

```bash
# Switch environment
terraform workspace select prod
terraform apply -var-file=environments/prod.tfvars

# View outputs
terraform output

# Destroy environment
terraform destroy -var-file=environments/dev.tfvars

# Backup cluster
velero backup create manual-backup-$(date +%Y%m%d)

# Restore from backup
velero restore create --from-backup <backup-name>

# View Tresvita application logs
kubectl logs -n backend -l app.kubernetes.io/name=tresvita-todo-backend
kubectl logs -n frontend -l app.kubernetes.io/name=tresvita-todo-frontend

# Port-forward for local testing
kubectl port-forward svc/tresvita-todo-backend 8080:8080 -n backend
kubectl port-forward svc/tresvita-todo-frontend 3000:80 -n frontend
```

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| Access entry already exists | `terraform import 'module.eks.aws_eks_access_entry.this["terraform_user"]' 'tresvita-todo-app-dev:arn:aws:iam::845844106369:user/Vinayak'` |
| kubectl not found | Download: `curl -LO https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/` |
| AWS credentials error | Configure: `aws configure` or create `~/.aws/credentials` file |
| Kubernetes auth error | Run: `aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev` |
| kubectl timeout / i/o timeout | Enable public endpoint: `aws eks update-cluster-config --region us-west-2 --name tresvita-todo-app-dev --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=0.0.0.0/0`. If still failing, add outbound HTTPS rule to EC2 security group |

---

**Client**: Tresvita  
**Managed by**: Wissen Team  
**Total Setup Time**: ~30 minutes  
**Cost**: ~$100-200/month (dev environment)
