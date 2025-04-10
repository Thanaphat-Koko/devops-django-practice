pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = credentials('DOCKER_REGISTRY')
        // DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
        DJANGO_IMAGE_NAME = 'devops-django-web-app'
        NGINX_IMAGE_NAME = 'nginx-django-web-app'
        DOCKER_IMAGE_TAG = credentials('DOCKER_IMAGE_TAG')
    }
    
    stages {
        stage('Clone Git Repo') {
            steps {
                echo "Clone git............."
                git branch: "main", url: "https://github.com/Thanaphat-Koko/devops-django-practice.git"
            }
        }

        stage('Build Docker Images') {
            steps {
                echo "Build Django Web Image............."
                sh "docker build -t ${DOCKER_REGISTRY}/${DJANGO_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ."
                echo "Build Nginx Web Image............."
                sh "docker build -t ${DOCKER_REGISTRY}/${NGINX_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ../nginx"
            }
        }

    //     stage('Push Docker Image') {
    //         steps {
    //             echo "Push Docker Image............."
    //             sh "docker push ${DOCKER_REGISTRY}/${DJANGO_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
    //             sh "docker push ${DOCKER_REGISTRY}/${NGINX_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
    //         }
    //     }
        
    //     stage('Run MiniKube') {
    //         steps {
    //             echo "Run MiniKube............."
    //             sh "minikube delete"
    //             sh "minikube start"
    //         }
    //     }

    //     stage('Run Kubernetes') {
    //         steps {
    //             echo "Run Kubernetes Cluster............."
    //             sh "./run-k8s.sh"
    //         }
    //     }
    }

    post {
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed!'
        }
        always {
            //sh "kubectl get all"
            sh "docker images"
        }
    }
}