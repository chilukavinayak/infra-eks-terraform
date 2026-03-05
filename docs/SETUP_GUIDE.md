# Tresvita EKS Complete Setup Guide

**Managed by Wissen Team**

This guide provides step-by-step instructions for setting up the entire Tresvita EKS infrastructure, from cluster creation to application deployment.

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS account with admin access
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.7.0 installed
- [ ] kubectl installed
- [ ] Helm >= 3.0 installed
- [ ] Git installed

## 🚀 Phase 1: EKS Infrastructure Setup

### Step 1: Configure AWS CLI

```bash
# Configure AWS credentials
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY_ID
# AWS Secret Access Key: YOUR_SECRET_ACCESS_KEY
# Default region name: us-west-2
# Default output format: json

# OR use environment variables
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_REGION=us-west-2

# Verify configuration
aws sts get-caller-identity
```

**For EC2 Instances:** If running on EC2, attach an IAM Instance Profile or create credentials file:
```bash
mkdir -p ~/.aws
cat > ~/.aws/credentials << 'EOF'
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
EOF
chmod 600 ~/.aws/credentials

cat > ~/.aws/config << 'EOF'
[default]
region = us-west-2
output = json
EOF
```

### Step 2: Install kubectl (if not installed)

```bash
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make executable and move to PATH
chmod +x kubectl
sudo mkdir -p /usr/local/bin
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

### Step 3: Clone and Prepare Repository

```bash
# Clone the infrastructure repository
git clone https://github.com/chilukavinayak/infra-eks-terraform.git
cd infra-eks-terraform

# Initialize Terraform
terraform init
```

### Step 4: Deploy Development Environment

```bash
# Create and select workspace
terraform workspace new dev
terraform workspace select dev

# Review the plan
terraform plan -var-file=environments/dev.tfvars

# Apply the configuration (takes ~15-20 minutes)
terraform apply -var-file=environments/dev.tfvars
```

**⚠️ Note:** If you encounter an error about access entry already existing:
```bash
# Import the existing access entry first
terraform import 'module.eks.aws_eks_access_entry.this["terraform_user"]' 'tresvita-todo-app-dev:arn:aws:iam::845844106369:user/Vinayak'

# Then re-run apply
terraform apply -var-file=environments/dev.tfvars
```

**Expected outputs:**
- VPC ID
- Subnet IDs
- EKS cluster endpoint
- kubectl configuration command

### Step 5: Configure kubectl

```bash
# Update kubeconfig (correct cluster name)
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### Step 6: Verify Add-ons

```bash
# Check all system pods
kubectl get pods -n kube-system

# Expected running pods:
# - aws-load-balancer-controller
# - cluster-autoscaler
# - coredns
# - ebs-csi-controller
# - kube-proxy
# - metrics-server

# Check Tresvita namespaces
kubectl get namespaces
# Should show: frontend, backend, monitoring, cicd
```

### Step 7: Deploy Staging Environment (Optional)

```bash
# Create staging workspace
terraform workspace new staging
terraform workspace select staging

# Apply staging configuration
terraform apply -var-file=environments/staging.tfvars

# Configure kubectl for staging
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-staging
```

### Step 8: Deploy Production Environment

```bash
# Create production workspace
terraform workspace new prod
terraform workspace select prod

# Review and apply production configuration
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars

# Configure kubectl for production
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-prod
```

## 🔧 Phase 2: Jenkins CI/CD Setup (Optional)

### Step 1: Create Jenkins EC2 Instance

```bash
# Use the existing Jenkins IAM profile created by Terraform
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids <sg-id> \
  --iam-instance-profile Name=tresvita-todo-app-dev-jenkins-profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=tresvita-jenkins-server}]'
```

### Step 2: Install Jenkins and Tools

```bash
# SSH into instance
ssh -i your-key.pem ec2-user@<jenkins-public-ip>

# Update system
sudo yum update -y

# Install Java
sudo amazon-linux-extras install java-openjdk11 -y

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Install Jenkins
sudo yum install jenkins -y
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Install Docker
sudo amazon-linux-extras install docker -y
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker jenkins

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Step 3: Configure Jenkins

1. **Access Jenkins UI**
   - Navigate to `http://<jenkins-public-ip>:8080`
   - Enter initial admin password
   - Install suggested plugins
   - Create admin user

2. **Install Additional Plugins**
   - Go to Manage Jenkins → Manage Plugins → Available
   - Install: Pipeline, GitHub Integration, Docker Pipeline, Kubernetes CLI, Amazon ECR

3. **Configure AWS Credentials**
   - Go to Manage Jenkins → Manage Credentials
   - Add AWS Credentials for ECR access

## 📝 Phase 3: Application Repository Setup

### Frontend Repository (React)

The frontend code is already created in `todo-frontend-eks/`:

```bash
cd todo-frontend-eks

# Build Docker image locally (for testing)
docker build -t tresvita-todo-frontend:v1.0.0 .

# Push to ECR (after creating repo)
aws ecr create-repository --repository-name tresvita-todo-frontend
docker tag tresvita-todo-frontend:v1.0.0 <account>.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend:v1.0.0
docker push <account>.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend:v1.0.0
```

### Backend Repository (Java/Spring Boot)

The backend code is already created in `todo-backend-eks/`:

```bash
cd todo-backend-eks

# Build with Maven
./mvnw clean package -DskipTests

# Build Docker image
docker build -t tresvita-todo-backend:v1.0.0 .

# Push to ECR
aws ecr create-repository --repository-name tresvita-todo-backend
docker tag tresvita-todo-backend:v1.0.0 <account>.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend:v1.0.0
docker push <account>.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend:v1.0.0
```

## 🚀 Phase 4: Application Deployment

### Step 1: Create ECR Repositories

```bash
# Create ECR repositories
aws ecr create-repository --repository-name tresvita-todo-frontend
aws ecr create-repository --repository-name tresvita-todo-backend

# Get login token
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-west-2.amazonaws.com
```

### Step 2: Build and Push Initial Images

```bash
# Get AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Frontend
cd todo-frontend-eks
docker build -t tresvita-todo-frontend:v1.0.0 .
docker tag tresvita-todo-frontend:v1.0.0 ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend:v1.0.0
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend:v1.0.0

# Backend
cd todo-backend-eks
./mvnw clean package -DskipTests
docker build -t tresvita-todo-backend:v1.0.0 .
docker tag tresvita-todo-backend:v1.0.0 ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend:v1.0.0
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend:v1.0.0
```

### Step 3: Deploy Applications

```bash
cd infra-eks-terraform

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

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n frontend
kubectl get pods -n backend

# Check services
kubectl get svc -n frontend
kubectl get svc -n backend

# Check ingress
kubectl get ingress -n frontend
kubectl get ingress -n backend

# Get ALB URL
kubectl get ingress -n frontend -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# Test backend API
curl http://$(kubectl get ingress -n backend -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')/api/todos
```

## ✅ Verification Checklist

### Infrastructure
- [ ] EKS cluster `tresvita-todo-app-dev` is running
- [ ] Nodes are ready (`kubectl get nodes`)
- [ ] All add-ons are running (`kubectl get pods -n kube-system`)
- [ ] Namespaces created: frontend, backend, monitoring, cicd

### Applications
- [ ] ECR repositories created: `tresvita-todo-frontend`, `tresvita-todo-backend`
- [ ] Docker images pushed to ECR
- [ ] Frontend pods running (`kubectl get pods -n frontend`)
- [ ] Backend pods running (`kubectl get pods -n backend`)
- [ ] ALB ingress created (`kubectl get ingress --all-namespaces`)
- [ ] Application accessible via ALB URL

### Access & Security
- [ ] kubectl configured (`aws eks update-kubeconfig`)
- [ ] Can access cluster (`kubectl get nodes`)
- [ ] IAM roles created: admin, developer, jenkins

## 🆘 Troubleshooting

### Issue: Access Entry Already Exists
```bash
terraform import 'module.eks.aws_eks_access_entry.this["terraform_user"]' 'tresvita-todo-app-dev:arn:aws:iam::845844106369:user/Vinayak'
```

### Issue: Kubernetes Provider Authentication
```bash
# Ensure AWS credentials are set
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev

# Verify access
kubectl get nodes
```

### Issue: Image Pull Errors
```bash
# Verify ECR login
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-west-2.amazonaws.com

# Check image exists
aws ecr describe-images --repository-name tresvita-todo-backend
```

## 📚 Next Steps

- [Jenkins Setup](JENKINS_SETUP.md) - Detailed CI/CD configuration
- [Operations Guide](OPERATIONS.md) - Day-to-day operations
- [Disaster Recovery](DISASTER_RECOVERY.md) - Backup and restore procedures
- [Application Development](APPLICATION_DEVELOPMENT.md) - Frontend/Backend development

---

**Client**: Tresvita  
**Managed by**: Wissen Team  
**Last Updated**: 2024


### Issue: kubectl Connection Timeout / i/o timeout

**Error:**
```
dial tcp 10.0.x.x:443: i/o timeout
Unable to connect to the server: dial tcp 10.0.12.x:443: i/o timeout
```

**Cause:** EKS cluster endpoint is configured with private access only (resolving to private IPs)

**Solution 1 - Enable Public Endpoint (Quick Fix for Dev):**
```bash
# Enable public endpoint access
aws eks update-cluster-config \
  --region us-west-2 \
  --name tresvita-todo-app-dev \
  --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=0.0.0.0/0

# Wait for update to complete (5-10 minutes)
aws eks wait cluster-active --region us-west-2 --name tresvita-todo-app-dev

# Clear old kubeconfig and get fresh one
rm -rf ~/.kube/config
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev

# Test connection
kubectl get nodes
```

**Solution 2 - Connect via EC2 Bastion (More Secure):**
```bash
# SSH into EC2 instance (Jenkins server) in the same VPC
ssh -i your-key.pem ec2-user@<jenkins-ec2-public-ip>

# From the EC2 instance, configure kubectl
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev
kubectl get nodes
```

**Debug Commands:**
```bash
# Check cluster endpoint configuration
aws eks describe-cluster --name tresvita-todo-app-dev --region us-west-2 \
  --query 'cluster.resourcesVpcConfig.{publicAccess: endpointPublicAccess, privateAccess: endpointPrivateAccess}'

# View current kubeconfig
cat ~/.kube/config | grep server
```


### Issue: kubectl Still Times Out After Enabling Public Endpoint

**Error:** 
```
dial tcp 10.0.x.x:443: i/o timeout
```

**Cause:** Your EC2 instance is in the same VPC as the EKS cluster, so DNS resolves to private IPs. The EC2 security group needs outbound HTTPS access.

**Solution 1 - Update EC2 Security Group (Quickest):**
```bash
# Get your EC2 security group ID
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

# Test again
kubectl get nodes
```

**Via AWS Console:**
1. Go to EC2 → Instances → Select your instance
2. Click "Security" tab → Click the Security Group
3. Click "Edit outbound rules"
4. Add: Type=HTTPS, Port=443, Destination=0.0.0.0/0
5. Save rules

**Solution 2 - Test from Outside VPC:**
```bash
# Run kubectl from your local laptop (not EC2)
# This uses public endpoint and bypasses VPC networking
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev
kubectl get nodes
```
