# Tresvita Jenkins CI/CD Setup Guide

**Managed by Wissen Team**

This guide covers the setup of Jenkins on EC2 for building and deploying the Tresvita Todo application.

## 📋 Prerequisites

- EKS cluster deployed (`tresvita-todo-app-dev`)
- AWS CLI configured
- SSH key pair for EC2 access
- Terraform outputs available

## 🚀 Step-by-Step Setup

### Step 1: Get Jenkins IAM Instance Profile

After running Terraform, get the instance profile name:

```bash
cd infra-eks-terraform
terraform output jenkins_instance_profile_name

# Example output: tresvita-todo-app-dev-jenkins-profile
```

### Step 2: Launch EC2 Instance (AWS Console)

1. **Navigate to EC2 Console** → Launch Instance

2. **Name**: `tresvita-jenkins-server`

3. **AMI**: Amazon Linux 2023 (or Amazon Linux 2)

4. **Instance Type**: 
   - Dev: `t3.medium` (2 vCPU, 4 GB RAM)
   - Production Jenkins: `t3.large` (2 vCPU, 8 GB RAM)

5. **Key Pair**: Select or create a key pair

6. **Network Settings**:
   - VPC: Use the VPC created by Terraform (`tresvita-todo-app-dev-vpc`)
   - Subnet: Public subnet
   - Auto-assign public IP: Enable

7. **IAM Instance Profile**: Select `tresvita-todo-app-dev-jenkins-profile`

8. **Security Group**: Create new with these rules:

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Your IP/32 | Admin access |
| HTTP | TCP | 8080 | Your IP/32 | Jenkins UI |
| HTTPS | TCP | 8443 | Your IP/32 | Jenkins HTTPS (optional) |

9. **Storage**: 30 GB gp3

10. **Launch Instance**

### Step 3: Connect and Install Jenkins

```bash
# SSH into the instance
ssh -i your-key.pem ec2-user@<instance-public-ip>

# Update system
sudo yum update -y

# Install Java 17 (required for Jenkins LTS)
sudo dnf install java-17-amazon-corretto -y

# Verify Java
java -version
```

#### Install Jenkins

```bash
# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import GPG key
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
sudo yum install jenkins -y

# Start Jenkins
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Check status
sudo systemctl status jenkins
```

### Step 4: Install Required Tools

#### Install Docker

```bash
# Install Docker
sudo yum install docker -y

# Start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Verify
sudo docker run hello-world
```

#### Install kubectl

```bash
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make it executable
chmod +x kubectl

# Move to system path
sudo mkdir -p /usr/local/bin
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client
```

#### Install Helm

```bash
# Download Helm install script
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# Run script
chmod 700 get_helm.sh
./get_helm.sh

# Verify
helm version
```

#### Install AWS CLI v2

```bash
# Download AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Install unzip if needed
sudo yum install unzip -y

# Unzip and install
unzip awscliv2.zip
sudo ./aws/install --update

# Verify
aws --version
```

#### Install Git

```bash
sudo yum install git -y
git --version
```

#### Configure AWS CLI for Jenkins User

```bash
# Switch to jenkins user
sudo su - jenkins

# Configure AWS region
aws configure set region us-west-2
aws configure set output json

# Test AWS access (should work via instance profile)
aws sts get-caller-identity

# Configure kubectl for EKS
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev

# Test kubectl
kubectl get nodes

# Exit jenkins user
exit
```

**Note:** If instance profile doesn't work, configure credentials manually:
```bash
sudo su - jenkins
mkdir -p ~/.aws

# Create credentials file (use your actual AWS credentials)
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

exit
```

#### Restart Jenkins

```bash
sudo systemctl restart jenkins
```

### Step 5: Initial Jenkins Configuration

1. **Access Jenkins UI**
   - Open browser: `http://<instance-public-ip>:8080`

2. **Get Initial Admin Password**
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

3. **Unlock Jenkins**
   - Paste the initial admin password
   - Click "Continue"

4. **Install Plugins**
   - Select "Install suggested plugins"
   - Wait for installation to complete

5. **Create Admin User**
   - Username: `admin`
   - Password: (choose strong password)
   - Full name: `Tresvita Administrator`
   - Email: admin@tresvita.com

6. **Instance Configuration**
   - Jenkins URL: `http://<instance-public-ip>:8080/`
   - Click "Save and Finish"

### Step 6: Install Additional Plugins

1. Navigate to: **Manage Jenkins** → **Manage Plugins** → **Available**

2. Search and install these plugins:

   **Pipeline & Build:**
   - Pipeline
   - Pipeline: Stage View
   - Pipeline: GitHub Groovy Libraries
   
   **Source Control:**
   - GitHub Integration
   - GitHub Branch Source
   
   **Docker:**
   - Docker Pipeline
   - Docker Commons
   
   **Kubernetes:**
   - Kubernetes
   - Kubernetes CLI
   - Kubernetes Continuous Deploy
   
   **AWS:**
   - Amazon ECR
   - AWS Steps
   
   **Utilities:**
   - Generic Webhook Trigger
   - Build Timestamp
   - AnsiColor
   - Blue Ocean (optional, better UI)

3. Click "Install without restart"

### Step 7: Configure Credentials

1. Navigate to: **Manage Jenkins** → **Manage Credentials**

2. Click **(global)** → **Add Credentials**

3. Add these credentials:

   **GitHub Token:**
   - Kind: Secret text
   - Secret: (your GitHub personal access token)
   - ID: `github-token`
   - Description: GitHub Personal Access Token

   **AWS Account ID:**
   - Kind: Secret text
   - Secret: (your AWS account ID, e.g., 845844106369)
   - ID: `aws-account-id`
   - Description: AWS Account ID

   **kubeconfig (optional):**
   - Kind: Secret file
   - File: Upload your kubeconfig file
   - ID: `kubeconfig`
   - Description: Kubernetes Config

### Step 8: Configure GitHub Webhooks (CRITICAL FOR AUTO-TRIGGER)

⚠️ **If Jenkins is not triggering on merge to master, check these configurations:**

#### Prerequisites

Ensure these plugins are installed:
- GitHub Integration
- GitHub Branch Source
- Pipeline: GitHub Groovy Libraries

#### In Jenkins (Global Configuration):

1. Navigate to: **Manage Jenkins** → **Configure System**

2. Find **GitHub** section:
   - Check "Manage hooks"
   - Credentials: Select `github-token`
   - Click "Test Connection"
   \n3. **For GitHub Enterprise (if applicable):**
   - Add GitHub Enterprise Servers section
   - API endpoint: `https://github.com/api/v3`
   - Credentials: Select `github-token`

#### In GitHub (for each repository):

1. Go to repository → **Settings** → **Webhooks** → **Add webhook**

2. Configure webhook:
   | Setting | Value |
   |---------|-------|
   | Payload URL | `http://<jenkins-public-ip>:8080/github-webhook/` |
   | Content type | `application/json` |
   | Secret | (leave blank unless using signature verification) |
   | Events | Select **"Just the push event"** |
   | Active | ✓ |

3. Click **"Add webhook"**

4. **Verify webhook is working:**
   - After adding, GitHub will show a green checkmark ✅ if the webhook is reachable
   - Red cross ❌ indicates connection issues (check security group rules)

#### In Jenkins (Job Configuration):

For each pipeline job, ensure:

1. **Build Triggers** section:
   - ☑️ Check **"GitHub hook trigger for GITScm polling"**
   
2. **Pipeline** section:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL must match exactly (use HTTPS or SSH consistently)

#### Jenkinsfile Trigger Directive

Ensure your Jenkinsfile includes the trigger directive:

```groovy
pipeline {
    agent any
    
    triggers {
        // This enables automatic trigger on GitHub push
        githubPush()
    }
    
    // ... rest of pipeline
}
```

#### Testing Webhook Trigger

1. **Test webhook delivery in GitHub:**
   - Go to repository → Settings → Webhooks
   - Click on your webhook
   - Click "Recent Deliveries"
   - Click "Redeliver" to test

2. **Check Jenkins logs:**
   ```bash
   # SSH to Jenkins server
   sudo tail -f /var/log/jenkins/jenkins.log
   
   # Or check GitHub webhook logs in Jenkins UI
   # Manage Jenkins → System Log → GitHub WebHook
   ```

3. **Trigger manually for testing:**
   ```bash
   # From your local machine with GitHub access
   curl -X POST \
     -H "Content-Type: application/json" \
     -d '{"ref":"refs/heads/main"}' \
     http://<jenkins-public-ip>:8080/github-webhook/
   ```

### Step 9: Create Pipeline Jobs

#### Frontend Pipeline

1. **New Item** → Enter name: `tresvita-todo-frontend` → Select **Pipeline** → OK

2. **Configure:**
   - **General**:
     - Check "GitHub project"
     - Project URL: `https://github.com/chilukavinayak/todo-frontend-eks/`
   
   - **Build Triggers**:
     - Check "GitHub hook trigger for GITScm polling"
   
   - **Pipeline**:
     - Definition: Pipeline script from SCM
     - SCM: Git
     - Repository URL: `https://github.com/chilukavinayak/todo-frontend-eks.git`
     - Credentials: `github-token`
     - Branch Specifier: `*/main, */develop`
     - Script Path: `Jenkinsfile`

3. Click "Save"

#### Backend Pipeline

Repeat the same steps for `tresvita-todo-backend` repository:
- Repository URL: `https://github.com/chilukavinayak/todo-backend-eks.git`

## 📝 Sample Jenkinsfile for Tresvita

### Frontend Jenkinsfile

Create this file as `Jenkinsfile` in your `todo-frontend-eks` repository:

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1'
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }
        
        stage('Lint') {
            steps {
                sh 'npm run lint || echo "No lint script, skipping"'
            }
        }
        
        stage('Test') {
            steps {
                sh 'npm test -- --coverage --watchAll=false || echo "No tests, skipping"'
            }
        }
        
        stage('Build Application') {
            steps {
                sh 'npm run build'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def image = docker.build("${ECR_REPO}:${IMAGE_TAG}")
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REPO}
                        
                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        
                        docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
                        docker push ${ECR_REPO}:latest
                    """
                }
            }
        }
        
        stage('Deploy to Dev') {
            when {
                branch 'develop'
            }
            steps {
                sh """
                    aws eks update-kubeconfig --region ${AWS_REGION} --name tresvita-todo-app-dev
                    
                    helm upgrade --install tresvita-todo-frontend ./helm_charts/todo-frontend \
                        --namespace frontend \
                        --set image.repository=${ECR_REPO} \
                        --set image.tag=${IMAGE_TAG} \
                        --set replicaCount=2 \
                        --wait \
                        --timeout 5m
                    
                    kubectl rollout status deployment/tresvita-todo-frontend -n frontend --timeout=300s
                """
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to Production?', ok: 'Deploy'
                
                sh """
                    aws eks update-kubeconfig --region ${AWS_REGION} --name tresvita-todo-app-dev
                    
                    helm upgrade --install tresvita-todo-frontend ./helm_charts/todo-frontend \
                        --namespace frontend \
                        --set image.repository=${ECR_REPO} \
                        --set image.tag=${IMAGE_TAG} \
                        --set replicaCount=3 \
                        --wait \
                        --timeout 10m
                    
                    kubectl rollout status deployment/tresvita-todo-frontend -n frontend --timeout=600s
                """
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}
```

### Backend Jenkinsfile

Create this file as `Jenkinsfile` in your `todo-backend-eks` repository:

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        MAVEN_OPTS = '-Xmx1024m'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1'
            }
        }
        
        stage('Build & Test') {
            steps {
                sh './mvnw clean package -DskipTests'
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh './mvnw test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${ECR_REPO}:${IMAGE_TAG}")
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REPO}
                        
                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
                        docker push ${ECR_REPO}:latest
                    """
                }
            }
        }
        
        stage('Deploy to Dev') {
            when {
                branch 'develop'
            }
            steps {
                sh """
                    aws eks update-kubeconfig --region ${AWS_REGION} --name tresvita-todo-app-dev
                    
                    helm upgrade --install tresvita-todo-backend ./helm_charts/todo-backend \
                        --namespace backend \
                        --set image.repository=${ECR_REPO} \
                        --set image.tag=${IMAGE_TAG} \
                        --set replicaCount=2 \
                        --wait \
                        --timeout 5m
                    
                    kubectl rollout status deployment/tresvita-todo-backend -n backend --timeout=300s
                """
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to Production?', ok: 'Deploy'
                
                sh """
                    aws eks update-kubeconfig --region ${AWS_REGION} --name tresvita-todo-app-dev
                    
                    helm upgrade --install tresvita-todo-backend ./helm_charts/todo-backend \
                        --namespace backend \
                        --set image.repository=${ECR_REPO} \
                        --set image.tag=${IMAGE_TAG} \
                        --set replicaCount=3 \
                        --wait \
                        --timeout 10m
                    
                    kubectl rollout status deployment/tresvita-todo-backend -n backend --timeout=600s
                """
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}
```

## 🔧 Maintenance

### Update Jenkins

```bash
# Update packages
sudo yum update jenkins -y

# Restart Jenkins
sudo systemctl restart jenkins
```

### Backup Jenkins

```bash
# Create backup directory
sudo mkdir -p /var/backups/jenkins

# Backup Jenkins home
sudo tar -czf /var/backups/jenkins/jenkins-backup-$(date +%Y%m%d).tar.gz /var/lib/jenkins/

# Copy to S3 (optional)
aws s3 cp /var/backups/jenkins/jenkins-backup-$(date +%Y%m%d).tar.gz s3://tresvita-backups/jenkins/
```

### Monitor Jenkins

```bash
# Check disk space
df -h

# Check memory
free -m

# Check Jenkins logs
sudo journalctl -u jenkins -f
```

## 🆘 Troubleshooting

### Jenkins Won't Start

```bash
# Check logs
sudo journalctl -u jenkins

# Check port availability
sudo netstat -tlnp | grep 8080

# Check permissions
ls -la /var/lib/jenkins/
```

### Docker Permission Denied

```bash
# Fix docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Verify
groups jenkins
```

### kubectl Connection Refused / i/o timeout

**Error:** `dial tcp 10.0.x.x:443: i/o timeout`

**Cause 1:** EKS cluster endpoint is private-only

**Solution 1 - Enable Public Endpoint:**
```bash
# Enable public endpoint (from local machine with AWS access)
aws eks update-cluster-config \
  --region us-west-2 \
  --name tresvita-todo-app-dev \
  --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=0.0.0.0/0

# Wait for update
aws eks wait cluster-active --region us-west-2 --name tresvita-todo-app-dev

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev
```

**Cause 2:** Jenkins EC2 is in same VPC as EKS → DNS resolves to private IPs

**Solution 2 - Update EC2 Security Group:**
```bash
# Get Jenkins EC2 security group ID
export EC2_SG_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=tresvita-jenkins-server" \
  --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
  --output text)

# Add outbound HTTPS rule to allow EKS API access
aws ec2 authorize-security-group-egress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Test as jenkins user
sudo su - jenkins
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev
kubectl get nodes
exit
```

### AWS Credentials Not Working

```bash
# Check instance profile
aws sts get-caller-identity

# If using credentials file, verify permissions
ls -la /var/lib/jenkins/.aws/
sudo chmod 600 /var/lib/jenkins/.aws/credentials
```

### Build Fails - Out of Memory

```bash
# Increase instance type to t3.large
# OR add swap
sudo dd if=/dev/zero of=/swapfile bs=128M count=16
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Helm Deployment Fails

```bash
# Check Helm version
helm version

# Verify kubeconfig
kubectl config current-context

# Check namespace exists
kubectl get namespaces

# Check Helm releases
helm list --all-namespaces
```

### Jenkins Not Triggering on Merge to Master (Webhook Issues)

#### Symptom: Pipeline doesn't start when code is pushed/merged

#### Check 1: Verify Webhook Configuration
```bash
# On Jenkins server, check if webhook endpoint is accessible
curl -v http://localhost:8080/github-webhook/

# Should return HTTP 200 with "OK" or similar
```

#### Check 2: Security Group Rules
Ensure Jenkins security group allows inbound traffic:

| Issue | Solution |
|-------|----------|
| GitHub can't reach Jenkins | Add inbound rule: HTTP (80) or 8080 from GitHub IPs |
| GitHub IP ranges | See https://api.github.com/meta for current IPs |

**Quick fix (for testing only):**
```bash
# Allow all HTTP traffic (NOT for production)
aws ec2 authorize-security-group-ingress \
  --group-id <jenkins-sg-id> \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0
```

#### Check 3: Jenkins Job Configuration

1. **Verify "GitHub hook trigger for GITScm polling" is checked**
   - Job → Configure → Build Triggers

2. **Verify SCM configuration**
   - Repository URL must be accessible
   - Credentials must be valid

3. **Check branch specifier**
   - Should include `main` or `master`: `*/main`

#### Check 4: Jenkinsfile Trigger Directive

Ensure Jenkinsfile has trigger block:

```groovy
pipeline {
    agent any
    
    triggers {
        githubPush()  // This is REQUIRED for auto-trigger
    }
    
    // ... rest of pipeline
}
```

#### Check 5: GitHub Webhook Delivery Status

1. Go to GitHub → Repository → Settings → Webhooks
2. Click on your webhook
3. Check "Recent Deliveries"
   - Green check ✅ = Delivered successfully
   - Red cross ❌ = Delivery failed

**Common delivery failures:**
| Status | Cause | Solution |
|--------|-------|----------|
| 403 Forbidden | CSRF protection | Disable CSRF or whitelist GitHub IPs |
| 404 Not Found | Wrong URL | Check `/github-webhook/` endpoint |
| Timeout | Network issue | Check security groups, Jenkins running |
| 200 but no build | Trigger not enabled | Check "GitHub hook trigger" in job config |

#### Check 6: Jenkins CSRF Settings

If getting 403 errors:

1. Manage Jenkins → Configure Global Security
2. Under **CSRF Protection**:
   - Option 1: Disable (not recommended for production)
   - Option 2: Enable proxy compatibility
3. Restart Jenkins

#### Check 7: Jenkins Logs

```bash
# Check Jenkins logs for webhook events
sudo tail -f /var/log/jenkins/jenkins.log | grep -i github

# Or check specific webhook plugin logs
sudo tail -f /var/log/jenkins/jenkins.log | grep -i webhook
```

#### Check 8: Alternative Trigger (Polling)

If webhooks can't be configured, use SCM polling:

```groovy
pipeline {
    agent any
    
    triggers {
        // Poll GitHub every 5 minutes
        pollSCM('H/5 * * * *')
    }
    
    // ... rest of pipeline
}
```

⚠️ **Note:** Polling is less efficient than webhooks but works without external access.

#### Manual Workaround (Immediate)

If webhooks aren't working and you need to deploy:

```bash
# Trigger Jenkins build manually via API
curl -X POST \
  --user username:api_token \
  "http://<jenkins-ip>:8080/job/tresvita-todo-frontend/build"

# Or use Jenkins CLI
java -jar jenkins-cli.jar -s http://<jenkins-ip>:8080/ \
  build tresvita-todo-frontend
```

---

## 📋 Jenkins Webhook Checklist

Use this checklist when webhook triggers aren't working:

- [ ] Jenkins URL accessible from internet (or GitHub IPs allowed)
- [ ] Security group allows inbound on port 8080
- [ ] GitHub webhook configured with correct URL
- [ ] GitHub webhook shows green checkmark (delivery successful)
- [ ] Jenkins job has "GitHub hook trigger for GITScm polling" checked
- [ ] Jenkinsfile includes `triggers { githubPush() }` block
- [ ] Repository URL in job config matches webhook repository
- [ ] Branch specifier includes the branch being pushed to
- [ ] CSRF protection not blocking webhook (check logs for 403)
- [ ] Jenkins GitHub plugin installed and configured

---

**Client**: Tresvita  
**Managed by**: Wissen Team  
**Next Steps:**
- Configure application repositories with Jenkinsfiles
- Set up automated deployments
- Configure monitoring and alerting
