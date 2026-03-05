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
                sh 'git log -1'
            }
        }
        
        stage('Terraform Init') {
            steps {
                sh '''
                    cd infra-eks-terraform
                    terraform init -backend-config="bucket=tresvita-terraform-state-${AWS_ACCOUNT_ID}" -backend-config="key=eks/${ENVIRONMENT}/terraform.tfstate" -backend-config="region=${AWS_REGION}" -backend-config="dynamodb_table=tresvita-terraform-locks-${ENVIRONMENT}"
                '''
            }
        }
        
        stage('Select Workspace') {
            steps {
                sh '''
                    cd infra-eks-terraform
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
                    cd infra-eks-terraform
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
                    cd infra-eks-terraform
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
                    cd infra-eks-terraform
                    terraform destroy -var-file="environments/${ENVIRONMENT}.tfvars" -auto-approve -input=false
                '''
            }
        }
    }
}
