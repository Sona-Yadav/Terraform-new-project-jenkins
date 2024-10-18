pipeline {
    agent any

    environment {
        AWS_CREDENTIALS = credentials('aws-access-key-id') // Update with your Jenkins credential ID for AWS
    }

    stages {
        stage('Git Checkout') {
            steps {
                // Checkout the Terraform code from GitHub
                git branch: 'main', url: 'https://github.com/Sona-Yadav/Terraform-new-project-jenkins.git'
            }
        }
        
        stage('Terraform Init') {
            steps {
                script {
                    // Initialize Terraform in the workspace directory
                    sh 'terraform init'
                }
            }
        }
	    
        stage('Terraform Plan') {
            steps {
                script {
                    // Generate and display an execution plan
                    sh 'terraform plan -out=tfplan'
                }
            }
        }

        stage('Manual Approval') {
            steps {
                // Pause for manual approval before applying changes
                input "Approve the Terraform changes?"
            }
        }
	    
        stage('Terraform Apply') {
            steps {
                script {
                    // Apply the Terraform plan
                    sh 'terraform apply tfplan'
                }
            }
        }
    }

    // post {
    //     always {
    //         // Clean up the workspace after the pipeline finishes
    //         cleanWs()
    //     }
    // }
}
