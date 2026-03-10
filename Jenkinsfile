#!/usr/bin/env groovy

pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        TF_IN_AUTOMATION = 'true'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                    echo "=== Current Directory ==="
                    pwd
                    echo "=== All files in workspace ==="
                    ls -la
                    echo "=== Check if main.tf exists ==="
                    ls -la main.tf 2>/dev/null && echo "main.tf FOUND at root" || echo "main.tf NOT at root"
                    echo "=== Check for environments folder ==="
                    ls -la environments/ 2>/dev/null && echo "environments/ FOUND at root" || echo "environments/ NOT at root"
                    echo "=== Check one level deeper ==="
                    ls -la */main.tf 2>/dev/null || echo "No main.tf in subdirs"
                    ls -la */environments/ 2>/dev/null || echo "No environments/ in subdirs"
                '''
            }
        }
        
        stage('Terraform Init') {
            steps {
                script {
                    // Determine TF_DIR based on file existence
                    if (fileExists('main.tf')) {
                        env.TF_DIR = '.'
                    } else if (fileExists('infra-eks-terraform/main.tf')) {
                        env.TF_DIR = 'infra-eks-terraform'
                    } else {
                        error "Could not find main.tf. Check repository structure."
                    }
                    echo "Using TF_DIR: ${env.TF_DIR}"
                }
                sh '''
                    cd "${TF_DIR}"
                    echo "=== Contents of TF_DIR ==="
                    ls -la
                    echo "=== Contents of environments ==="
                    ls -la environments/
                    terraform init -backend-config="bucket=tresvita-todo-app-tfstate-${AWS_ACCOUNT_ID}" -backend-config="key=terraform.tfstate" -backend-config="region=${AWS_REGION}" -backend-config="dynamodb_table=tresvita-todo-app-tfstate-lock"
                '''
            }
        }
        
        stage('Select Workspace') {
            steps {
                sh '''
                    cd "${TF_DIR}"
                    terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}
                '''
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
            }
            steps {
                sh '''
                    cd "${TF_DIR}"
                    terraform plan -var-file="environments/${ENVIRONMENT}.tfvars" -out=tfplan -input=false
                    terraform show tfplan
                '''
            }
        }
        
        stage('Approval') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                input message: "Approve Terraform apply for ${params.ENVIRONMENT}?", ok: 'Approve'
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                sh '''
                    cd "${TF_DIR}"
                    terraform apply tfplan
                '''
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                script {
                    input message: "DESTROY all infrastructure in ${params.ENVIRONMENT}?", ok: 'Destroy'
                }
                sh '''
                    cd "${TF_DIR}"
                    terraform destroy -var-file="environments/${ENVIRONMENT}.tfvars" -auto-approve -input=false
                '''
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
