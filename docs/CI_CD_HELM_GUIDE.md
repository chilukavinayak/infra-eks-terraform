# CI/CD Pipeline with Helm Charts - Complete Guide

## Overview

This document explains the complete CI/CD workflow for deploying Frontend (React) and Backend (Java Spring Boot) applications to AWS EKS using Helm charts.

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              CI/CD PIPELINE FLOW                                        │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│   Developer            Git Push           Jenkins              ECR              EKS    │
│      │                      │                  │                 │                │    │
│      │  1. Code Change     │                  │                 │                │    │
│      │────────────────────>│                  │                 │                │    │
│      │                      │  2. Trigger    │                 │                │    │
│      │                      │────────────────>│                 │                │    │
│      │                      │                  │  3. Build       │                │    │
│      │                      │                  │  4. Test        │                │    │
│      │                      │                  │  5. Docker Build│                │    │
│      │                      │                  │────────────────>│                │    │
│      │                      │                  │                 │  6. Push       │    │
│      │                      │                  │                 │  7. Tag        │    │
│      │                      │                  │<────────────────│                │    │
│      │                      │                  │                 │                │    │
│      │                      │                  │  8. Helm Upgrade│                │    │
│      │                      │                  │─────────────────────────────────>│    │
│      │                      │                  │                 │                │    │
│      │                      │                  │  9. Verify      │                │    │
│      │                      │                  │<─────────────────────────────────│    │
│      │                      │                  │                 │                │    │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
tresvita-eks-setup/
│
├── infra-eks-terraform/              # Infrastructure & Helm Charts
│   ├── helm_charts/
│   │   ├── todo-frontend/           # Frontend Helm Chart
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml          # Default values
│   │   │   └── templates/           # K8s manifests
│   │   └── todo-backend/            # Backend Helm Chart
│   │       ├── Chart.yaml
│   │       ├── values.yaml          # Default values
│   │       └── templates/           # K8s manifests
│   └── ...
│
├── todo-frontend-eks/               # Frontend Application
│   ├── src/                         # React source code
│   ├── Dockerfile
│   └── Jenkinsfile                  # CI/CD Pipeline
│
└── todo-backend-eks/                # Backend Application
    ├── src/                         # Java source code
    ├── Dockerfile
    └── Jenkinsfile                  # CI/CD Pipeline
```

---

## How It Works

### 1. Code Push to Repository

When you push code changes to `master` branch:

```bash
# Developer workflow
git add .
git commit -m "Add new feature"
git push origin master
```

### 2. Jenkins Pipeline Trigger

Jenkins automatically triggers the pipeline defined in `Jenkinsfile`. 

⚠️ **Important:** For automatic triggering on merge to master, you need:
1. GitHub webhook configured
2. `triggers { githubPush() }` in Jenkinsfile
3. "GitHub hook trigger for GITScm polling" enabled in job config

See [Troubleshooting](#jenkins-not-triggering-on-merge) section if pipelines don't trigger automatically.

#### Frontend Pipeline (`todo-frontend-eks/Jenkinsfile`)

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend"
        IMAGE_TAG = "${env.BUILD_NUMBER}"    // Unique tag per build
    }
    
    stages {
        stage('Build & Test') {
            steps {
                sh 'npm install'
                sh 'npm run build'
                sh 'npm test'
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
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ECR_REPO}
                    
                    docker push ${ECR_REPO}:${IMAGE_TAG}
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
                    docker push ${ECR_REPO}:latest
                """
            }
        }
        
        stage('Deploy with Helm') {
            steps {
                sh """
                    # Configure kubectl
                    aws eks update-kubeconfig --region ${AWS_REGION} --name tresvita-todo-app-dev
                    
                    # Deploy using Helm
                    helm upgrade --install tresvita-todo-frontend ../infra-eks-terraform/helm_charts/todo-frontend \
                        --namespace frontend \
                        --set image.repository=${ECR_REPO} \
                        --set image.tag=${IMAGE_TAG} \
                        --set replicaCount=2 \
                        --wait \
                        --timeout 5m
                    
                    # Verify deployment
                    kubectl rollout status deployment/tresvita-todo-frontend -n frontend --timeout=300s
                """
            }
        }
    }
}
```

#### Backend Pipeline (`todo-backend-eks/Jenkinsfile`)

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }
    
    stages {
        stage('Build & Test') {
            steps {
                sh './mvnw clean package'
                sh './mvnw test'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                docker.build("${ECR_REPO}:${IMAGE_TAG}")
            }
        }
        
        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${ECR_REPO}
                    
                    docker push ${ECR_REPO}:${IMAGE_TAG}
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
                    docker push ${ECR_REPO}:latest
                """
            }
        }
        
        stage('Deploy with Helm') {
            steps {
                sh """
                    aws eks update-kubeconfig --region ${AWS_REGION} --name tresvita-todo-app-dev
                    
                    helm upgrade --install tresvita-todo-backend ../infra-eks-terraform/helm_charts/todo-backend \
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
    }
}
```

---

## Helm Chart Deep Dive

### What is a Helm Chart?

A Helm chart is a package of pre-configured Kubernetes resources. Think of it as a "template" for deploying applications.

```
helm_charts/todo-frontend/
├── Chart.yaml              # Chart metadata (name, version, description)
├── values.yaml             # Default configuration values
└── templates/              # Kubernetes manifest templates
    ├── deployment.yaml     # Pod deployment
    ├── service.yaml        # Service exposure
    ├── ingress.yaml        # ALB ingress rules
    ├── hpa.yaml            # Horizontal Pod Autoscaler
    ├── configmap.yaml      # Configuration
    └── _helpers.tpl        # Helper templates
```

### How Helm Deployment Works

```
┌────────────────────────────────────────────────────────────────────────┐
│                        HELM DEPLOYMENT FLOW                            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   values.yaml + CLI overrides    ───>   Template Engine   ───>         │
│   (image.tag=123)                                                        │
│                                                                        │
│                                         Renders to:                    │
│                                         - Deployment                   │
│                                         - Service                      │
│                                         - Ingress                      │
│                                         - HPA                          │
│                                         - ConfigMap                    │
│                                                                        │
│                                         ───>   Apply to Kubernetes     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### Key Helm Commands Used

```bash
# Install or upgrade a release
helm upgrade --install <release-name> <chart-path> [flags]

# Breakdown:
# --install           # Install if doesn't exist, upgrade if exists
# --namespace         # Target namespace
# --set key=value     # Override values
# --wait              # Wait for deployment to complete
# --timeout           # Timeout duration
```

---

## Deployment Configuration

### 1. Image Tag Strategy

The Jenkins pipeline uses the **build number** as the image tag:

```groovy
IMAGE_TAG = "${env.BUILD_NUMBER}"   // e.g., "45"
```

This ensures:
- Each deployment is traceable to a specific build
- Easy rollback to any previous version
- No conflicts with `latest` tag caching issues

### 2. Helm Override Values

The pipeline overrides these values during deployment:

```bash
helm upgrade --install tresvita-todo-frontend ../infra-eks-terraform/helm_charts/todo-frontend \
    --namespace frontend \
    --set image.repository=${ECR_REPO} \          # ECR repository URL
    --set image.tag=${IMAGE_TAG} \                # Build-specific tag
    --set replicaCount=2                          # Number of pods
```

### 3. Available Override Options

You can customize deployment by adding more `--set` flags:

```bash
# Override resource limits
--set resources.limits.cpu=1000m \
--set resources.limits.memory=1Gi \

# Override environment variables
--set env[0].name=REACT_APP_API_URL \
--set env[0].value=https://api.example.com \

# Enable/disable features
--set autoscaling.enabled=true \
--set autoscaling.minReplicas=3 \
--set pdb.enabled=false

# Use a values file for environment-specific config
--values values-production.yaml
```

---

## Environment-Specific Deployments

### Branch-Based Deployment Strategy

```groovy
stage('Deploy to Dev') {
    when {
        branch 'develop'      // Only deploy to dev from develop branch
    }
    steps {
        sh """
            helm upgrade --install ... \
                --set replicaCount=2
        """
    }
}

stage('Deploy to Production') {
    when {
        branch 'main'         // Only deploy to prod from main branch
    }
    steps {
        input message: 'Deploy to Production?', ok: 'Deploy'  // Manual approval
        sh """
            helm upgrade --install ... \
                --set replicaCount=3
        """
    }
}
```

### Using Environment-Specific Values Files

Create environment-specific values files:

```
helm_charts/todo-frontend/
├── values.yaml              # Default values
├── values-dev.yaml          # Dev environment overrides
├── values-staging.yaml      # Staging environment overrides
└── values-prod.yaml         # Production environment overrides
```

Example `values-dev.yaml`:

```yaml
replicaCount: 2

resources:
  limits:
    cpu: 500m
    memory: 512Mi

env:
  - name: REACT_APP_API_URL
    value: "http://api-dev.tresvita.local/api"
```

Example `values-prod.yaml`:

```yaml
replicaCount: 5

resources:
  limits:
    cpu: 1000m
    memory: 1Gi

env:
  - name: REACT_APP_API_URL
    value: "https://api.tresvita.com/api"
```

Pipeline usage:

```bash
# Dev deployment
helm upgrade --install ... \
    --values ../infra-eks-terraform/helm_charts/todo-frontend/values-dev.yaml

# Production deployment
helm upgrade --install ... \
    --values ../infra-eks-terraform/helm_charts/todo-frontend/values-prod.yaml
```

---

## Complete Workflow Example

### Scenario: Deploy New Feature

```bash
# 1. Developer makes changes
cd todo-frontend-eks
git checkout -b feature/new-ui
echo "// New feature" >> src/App.js

# 2. Commit and push
git add .
git commit -m "Add new UI feature"
git push origin feature/new-ui

# 3. Create Pull Request to master
# (via GitHub/GitLab UI)

# 4. After review, merge to master
git checkout master
git merge feature/new-ui
git push origin master

# 5. Jenkins automatically:
#    - Detects push to master
#    - Runs pipeline
#    - Builds image with tag (e.g., "46")
#    - Pushes to ECR
#    - Deploys to EKS with Helm

# 6. Verify deployment
kubectl get pods -n frontend
kubectl get svc -n frontend
kubectl get ingress -n frontend
```

---

## Rollback Procedures

### Rollback to Previous Version

```bash
# 1. List Helm releases
helm list -n frontend
helm list -n backend

# 2. View revision history
helm history tresvita-todo-frontend -n frontend

# 3. Rollback to previous version
helm rollback tresvita-todo-frontend 45 -n frontend

# 4. Rollback to specific version
helm rollback tresvita-todo-frontend 43 -n frontend

# 5. Verify rollback
kubectl rollout status deployment/tresvita-todo-frontend -n frontend
```

### Rollback via Jenkins

You can also trigger a rollback by redeploying a specific build:

```bash
# In Jenkins, use "Replay" feature with older build number
# Or manually run Helm with specific image tag

helm upgrade --install tresvita-todo-frontend ./helm_charts/todo-frontend \
    --namespace frontend \
    --set image.repository=<account>.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend \
    --set image.tag=45    # Use specific build number
```

---

## Monitoring Deployments

### Check Deployment Status

```bash
# View pods
kubectl get pods -n frontend -w
kubectl get pods -n backend -w

# View deployment status
kubectl get deployment tresvita-todo-frontend -n frontend
kubectl get deployment tresvita-todo-backend -n backend

# View rollout history
kubectl rollout history deployment/tresvita-todo-frontend -n frontend

# View pod logs
kubectl logs -n frontend -l app.kubernetes.io/name=tresvita-todo-frontend --tail=100
kubectl logs -n backend -l app.kubernetes.io/name=tresvita-todo-backend --tail=100
```

### Helm-Specific Commands

```bash
# List releases
helm list --all-namespaces

# Get release status
helm status tresvita-todo-frontend -n frontend

# Get release values
helm get values tresvita-todo-frontend -n frontend

# Get rendered manifests
helm get manifest tresvita-todo-frontend -n frontend

# Get release notes
helm get notes tresvita-todo-frontend -n frontend
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Image Pull Error

```bash
# Symptom: Pod status shows "ImagePullBackOff"
kubectl describe pod <pod-name> -n frontend

# Fix: Verify ECR image exists
aws ecr describe-images --repository-name tresvita-todo-frontend --image-ids imageTag=45

# Fix: Re-run Jenkins build or check IAM permissions
```

#### 2. Helm Upgrade Fails

```bash
# Symptom: Helm upgrade hangs or fails
# Check for pending releases
helm list -n frontend --pending

# Fix: Rollback to last successful release
helm rollback tresvita-todo-frontend -n frontend

# Or uninstall and reinstall
helm uninstall tresvita-todo-frontend -n frontend
helm install tresvita-todo-frontend ./helm_charts/todo-frontend -n frontend
```

#### 3. Pod Not Ready

```bash
# Symptom: Pod stays in "Pending" or "CrashLoopBackOff"
kubectl describe pod <pod-name> -n frontend
kubectl logs <pod-name> -n frontend

# Common causes:
# - Resource quotas exceeded
# - Readiness probe failing
# - Environment variables missing
```

#### 4. Ingress Not Working

```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ingress status
kubectl get ingress -n frontend
kubectl describe ingress tresvita-todo-frontend -n frontend
```

---

## Jenkins Not Triggering on Merge

If your Jenkins pipeline is not automatically triggering when you merge to master, follow this troubleshooting guide:

### Quick Diagnosis Checklist

| Check | Command/Action | Expected Result |
|-------|----------------|-----------------|
| Webhook accessible | `curl http://<jenkins-ip>:8080/github-webhook/` | HTTP 200 OK |
| GitHub webhook status | GitHub → Settings → Webhooks | Green ✅ checkmark |
| Job trigger enabled | Job → Configure → Build Triggers | "GitHub hook trigger" checked |
| Jenkinsfile has trigger | Check `Jenkinsfile` in repo | Contains `githubPush()` |

### Issue 1: GitHub Webhook Not Configured

**Symptom:** No build starts when pushing to GitHub

**Solution:**

1. Go to GitHub → Repository → Settings → Webhooks → Add webhook
2. Configure:
   - **Payload URL:** `http://<your-jenkins-ip>:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Just the push event
   - **Active:** ✓
3. Click "Add webhook"
4. Verify: Green checkmark ✅ should appear next to the webhook

### Issue 2: Jenkins Security Group Blocking Webhook

**Symptom:** GitHub webhook shows red ❌ (delivery failed)

**Solution:**

Allow inbound traffic to Jenkins on port 8080:

```bash
# Get Jenkins security group ID
JENKINS_SG_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=tresvita-jenkins-server" \
  --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
  --output text)

# Add rule to allow GitHub webhooks (GitHub IPs: https://api.github.com/meta)
# For testing, you can allow all (restrict in production)
aws ec2 authorize-security-group-ingress \
  --group-id $JENKINS_SG_ID \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0
```

### Issue 3: Jenkins Job Not Configured for Webhook

**Symptom:** Webhook delivered (green ✅) but no build starts

**Solution:**

1. Go to Jenkins → Job → Configure
2. Under **Build Triggers**:
   - ☑️ Check **"GitHub hook trigger for GITScm polling"**
3. Under **Pipeline**:
   - Ensure SCM is configured with correct repository URL
4. Save and test by pushing to repository

### Issue 4: Jenkinsfile Missing Trigger Directive

**Symptom:** Manual build works, but webhook doesn't trigger

**Solution:**

Ensure your `Jenkinsfile` includes the trigger block:

```groovy
pipeline {
    agent any
    
    triggers {
        // REQUIRED: Enables automatic trigger on GitHub push
        githubPush()
    }
    
    environment {
        // ... your environment variables
    }
    
    stages {
        // ... your stages
    }
}
```

### Issue 5: CSRF Protection Blocking Webhooks

**Symptom:** GitHub webhook shows 403 Forbidden

**Solution:**

1. Jenkins → Manage Jenkins → Configure Global Security
2. Under **CSRF Protection**:
   - Check **"Enable proxy compatibility"**
   - Or temporarily disable CSRF for testing
3. Restart Jenkins

### Issue 6: Branch Mismatch

**Symptom:** Push to `master` doesn't trigger, but push to `develop` does

**Solution:**

Check branch specifier in job configuration:

1. Jenkins → Job → Configure → Pipeline → SCM
2. Ensure **Branch Specifier** includes your branch:
   - For single branch: `*/main` or `*/master`
   - For multiple: `*/main, */develop`

### Alternative: Use SCM Polling (If Webhooks Not Possible)

If you cannot configure webhooks (e.g., Jenkins behind firewall), use polling:

```groovy
pipeline {
    agent any
    
    triggers {
        // Poll every 5 minutes
        pollSCM('H/5 * * * *')
    }
    
    // ... rest of pipeline
}
```

⚠️ **Note:** Polling is less efficient than webhooks but doesn't require external access.

### Manual Trigger (Workaround)

If webhooks aren't working and you need immediate deployment:

```bash
# Trigger via Jenkins API
curl -X POST \
  --user username:api_token \
  "http://<jenkins-ip>:8080/job/tresvita-todo-frontend/build"

# Or trigger via CLI
java -jar jenkins-cli.jar -s http://<jenkins-ip>:8080/ \
  build tresvita-todo-frontend
```

---

## Best Practices

### 1. Always Use Specific Image Tags

```bash
# ✅ Good - Uses build number
--set image.tag=45

# ❌ Avoid - Uses latest (caching issues)
--set image.tag=latest
```

### 2. Use --wait Flag

```bash
# ✅ Good - Pipeline waits for deployment
helm upgrade --install ... --wait --timeout 5m

# ❌ Avoid - Pipeline continues immediately
helm upgrade --install ...
```

### 3. Verify Deployments

```bash
# Always verify after deployment
kubectl rollout status deployment/<name> -n <namespace> --timeout=300s
```

### 4. Separate CI from CD

```bash
# Option 1: Manual approval for production (already in Jenkinsfile)
input message: 'Deploy to Production?', ok: 'Deploy'

# Option 2: Separate Jenkins job for deployment
# Build job: Builds and pushes image
# Deploy job: Runs Helm upgrade (can be triggered separately)
```

### 5. Tag Images with Multiple Tags

```bash
# Push with build number (for traceability)
docker push ${ECR_REPO}:${IMAGE_TAG}

# Also tag as latest (for convenience)
docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest
```

---

## Quick Reference Commands

### Manual Deployment (for testing)

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name tresvita-todo-app-dev

# Deploy frontend manually
helm upgrade --install tresvita-todo-frontend ./infra-eks-terraform/helm_charts/todo-frontend \
    --namespace frontend \
    --set image.repository=<account>.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-frontend \
    --set image.tag=latest \
    --set replicaCount=2 \
    --wait \
    --timeout 5m

# Deploy backend manually
helm upgrade --install tresvita-todo-backend ./infra-eks-terraform/helm_charts/todo-backend \
    --namespace backend \
    --set image.repository=<account>.dkr.ecr.us-west-2.amazonaws.com/tresvita-todo-backend \
    --set image.tag=latest \
    --set replicaCount=2 \
    --wait \
    --timeout 5m
```

### Dry Run (Preview Changes)

```bash
# Preview changes without applying
helm upgrade --install tresvita-todo-frontend ./helm_charts/todo-frontend \
    --namespace frontend \
    --dry-run \
    --debug
```

### Template Rendering

```bash
# Render templates to see final YAML
helm template tresvita-todo-frontend ./helm_charts/todo-frontend \
    --namespace frontend \
    --set image.tag=45
```

---

## Summary

| Step | Tool | Description |
|------|------|-------------|
| 1. Code Change | Git | Developer pushes code |
| 2. CI Trigger | Jenkins | Pipeline starts automatically |
| 3. Build | npm/mvn | Build application |
| 4. Test | Jest/JUnit | Run tests |
| 5. Docker | Docker | Build container image |
| 6. Registry | ECR | Push image with build number tag |
| 7. Deploy | Helm | Deploy to EKS using Helm chart |
| 8. Verify | kubectl | Check deployment status |

The entire process is **automated** - from code push to production deployment!

---

**Client**: Tresvita  
**Managed By**: Wissen Team  
**Last Updated**: 2024
