pipeline {
  agent any
  environment {
    AWS_REGION = 'ap-south-1'
    REGISTRY   = '413816840602.dkr.ecr.ap-south-1.amazonaws.com'
  }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Build') {
      steps {
        sh '''
          docker build -t $REGISTRY/week2-flask:$GIT_COMMIT -t $REGISTRY/week2-flask:latest ./backend
          docker build -t $REGISTRY/week2-nginx:$GIT_COMMIT -t $REGISTRY/week2-nginx:latest ./proxy
        '''
      }
    }
    stage('Push') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-cli',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          sh '''
            aws ecr get-login-password --region $AWS_REGION | \
              docker login --username AWS --password-stdin $REGISTRY
            docker push $REGISTRY/week2-flask:$GIT_COMMIT
            docker push $REGISTRY/week2-flask:latest
            docker push $REGISTRY/week2-nginx:$GIT_COMMIT
            docker push $REGISTRY/week2-nginx:latest
          '''
        }
      }
    }
  }
}
