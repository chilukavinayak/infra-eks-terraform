#!/usr/bin/env groovy

// Tresvita EKS Infrastructure Pipeline
// Managed by Wissen Team
// This pipeline manages Terraform infrastructure deployments

pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS = '-no-color'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
        ansiColor('xterm')
    }
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment for deployment'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy', 'plan-destroy'],
            description: 'Terraform action to perform'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Auto-approve Terraform apply (use with caution!)'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                    echo "Git Commit: $(git log -1 --pretty=format:'%h %s')"
                    echo "Branch: ${BRANCH_NAME}"
                    echo "Environment: ${ENVIRONMENT}"
                    echo "Action: ${ACTION}"
                '''
            }
        }
        
        stage('Validate Branch') {
            steps {
                script {
                    // Enforce branch-based environment deployment
                    if (params.ENVIRONMENT == 'prod' && env.BRANCH_NAME != 'main') {
                        error("Production deployments must be from 'main' branch. Current branch: ${env.BRANCH_NAME}")
                    }
                    if (params.ENVIRONMENT == 'staging' && env.BRANCH_NAME != 'staging') {
                        error("Staging deployments must be from 'staging' branch. Current branch: ${env.BRANCH_NAME}")
                    }
                    if (params.ENVIRONMENT == 'dev' && env.BRANCH_NAME != 'develop') {
                        error("Dev deployments must be from 'develop' branch. Current branch: ${env.BRANCH_NAME}")
                    }
                }
            }
        }
        
        stage('Setup Tools') {
            steps {
                sh '''
                    # Check Terraform version
                    terraform --version
                    
                    # Check AWS CLI
                    aws --version
                    
                    # Configure AWS region
                    aws configure set region ${AWS_REGION}
                '''
            }
        }
        
        stage('Terraform Init') {
            steps {
                sh '''
                    cd infra-eks-terraform
                    
                    # Initialize Terraform with S3 backend
                    terraform init \
                        -backend-config="bucket=tresvita-terraform-state-${AWS_ACCOUNT_ID}" \
                        -backend-config="key=eks/${ENVIRONMENT}/terraform.tfstate" \
                        -backend-config="region=${AWS_REGION}" \
                        -backend-config="dynamodb_table=tresvita-terraform-locks-${ENVIRONMENT}"
                '''
            }
        }
        
        stage('Terraform Validate') {
            steps {
                sh '''
                    cd infra-eks-terraform
                    
                    # Validate Terraform syntax
                    terraform validate
                    
                    # Check formatting
                    terraform fmt -check -recursive || echo "Formatting issues found. Run 'terraform fmt' to fix."
                '''
            }
        }
        
        stage('Select Workspace') {
            steps {
                sh '''
                    cd infra-eks-terraform
                    
                    # Create workspace if it doesn't exist, then select it
                    terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}
                    
                    echo "Current workspace: $(terraform workspace show)"
                '''
            }
        }
        
        stage('Terraform Plan') {
            when {
                anyOf {
                    params.ACTION == 'plan'
                    params.ACTION == 'apply'
                }
            }
            steps {
                sh '''
                    cd infra-eks-terraform
                    
                    # Generate plan
                    terraform plan \
                        -var-file="environments/${ENVIRONMENT}.tfvars" \
                        -out=tfplan \
                        -input=false
                    
                    # Show plan summary
                    echo "========== PLAN SUMMARY =========="
                    terraform show -json tfplan | jq -r '.resource_changes[] | select(.change.actions[] | contains("create")) | "CREATE: \(.address)"' 2>/dev/null || echo "No new resources to create"
                    terraform show -json tfplan | jq -r '.resource_changes[] | select(.change.actions[] | contains("delete")) | "DELETE: \(.address)"' 2>/dev/null || echo "No resources to delete"
                    terraform show -json tfplan | jq -r '.resource_changes[] | select(.change.actions[] | contains("update")) | "UPDATE: \(.address)"' 2>/dev/null || echo "No resources to update"
                    echo "=================================="
                '''
            }
        }
        
        stage('Terraform Plan Destroy') {
            when {
                params.ACTION == 'plan-destroy'
            }
            steps {
                sh '''
                    cd infra-eks-terraform
                    
                    # Generate destroy plan
                    terraform plan \
                        -var-file="environments/${ENVIRONMENT}.tfvars" \
                        -destroy \
                        -out=tfplan \
                        -input=false
                    
                    echo "========== DESTROY PLAN =========="
                    echo "WARNING: This will destroy all resources!"
                    terraform show tfplan
                    echo "=================================="
                '''
            }
        }
        
        stage('Approval') {
            when {
                allOf {
                    params.ACTION == 'apply'
                    params.AUTO_APPROVE == false
                }
            }
            steps {
                script {
                    input message: "Approve Terraform ${params.ACTION} for ${params.ENVIRONMENT}?", ok: 'Approve'
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                params.ACTION == 'apply'
            }
            steps {
                sh '''
                    cd infra-eks-terraform
                    
                    # Apply Terraform plan
                    if [ "${AUTO_APPROVE}" = "true" ]; then
                        terraform apply \
                            -var-file="environments/${ENVIRONMENT}.tfvars" \
                            -auto-approve \
                            -input=false
                    else
                        terraform apply \
                            -var-file="environments/${ENVIRONMENT}.tfvars" \
                            tfplan
                    fi
                '''
            }
        }
        
        stage('Terraform Destroy') {
            when {
                params.ACTION == 'destroy'
            }
            steps {
                script {
                    input message: "DESTROY all infrastructure in ${params.ENVIRONMENT}? This cannot be undone!", ok: 'Destroy'
                }
                sh '''
                    cd infra-eks-terraform
                    
                    # Destroy infrastructure
                    terraform destroy \
                        -var-file="environments/${ENVIRONMENT}.tfvars" \
                        -auto-approve \
                        -input=false
                '''
            }
        }
        
        stage('Post-Deployment Verification') {
            when {
                params.ACTION == 'apply'
            }
            steps {
                sh '''
                    cd infra-eks-terraform
                    
                    echo "========== DEPLOYMENT OUTPUTS =========="
                    terraform output -raw configure_kubectl 2>/dev/null || echo "No kubectl config output"
                    terraform output -raw cluster_endpoint 2>/dev/null || echo "No cluster endpoint output"
                    terraform output cluster_name 2>/dev/null || echo "No cluster name output"
                    echo "========================================"
                    
                    # Configure kubectl if cluster was created/updated
                    if command -v kubectl &> /dev/null; then
                        aws eks update-kubeconfig --region ${AWS_REGION} --name tresvita-todo-app-${ENVIRONMENT} || echo "Cluster may not be ready yet"
                        kubectl cluster-info 2>/dev/null || echo "Cluster not accessible yet"
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            script {
                // Archive Terraform plan if it exists
                if (fileExists('infra-eks-terraform/tfplan')) {
                    archiveArtifacts artifacts: 'infra-eks-terraform/tfplan', allowEmptyArchive: true
                }
            }
            cleanWs()
        }
        success {
            echo '''
            ✅ =========================================
            ✅ Infrastructure Pipeline Completed Successfully!
            ✅ Environment: ${ENVIRONMENT}
            ✅ Action: ${ACTION}
            ✅ =========================================
            '''
        }
        failure {
            echo '''
            ❌ =========================================
            ❌ Infrastructure Pipeline Failed!
            ❌ Environment: ${ENVIRONMENT}
            ❌ Action: ${ACTION}
            ❌ =========================================
            '''
        }
    }
}
