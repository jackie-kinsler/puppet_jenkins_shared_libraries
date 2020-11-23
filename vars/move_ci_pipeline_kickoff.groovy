def call(String branch, String hour) {

  node('worker') {
    withCredentials([string(credentialsId: 'githubtoken', variable: 'GITHUB_TOKEN')]) {
      sh "curl -O https://raw.githubusercontent.com/puppetlabs/puppet_jenkins_shared_libraries/main/vars/bash/move_ci_pipeline_kickoff.sh"
      sh "chmod +x move_ci_pipeline_kickoff.sh"
      sh "bash move_ci_pipeline_kickoff.sh $branch $hour"
    }
  }
}