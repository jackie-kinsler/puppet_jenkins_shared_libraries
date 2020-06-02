def call(String version, String codename) {

  if (version =~ '^20[0-9]{2}[.]([0-9]*)[.]([0-9]*)$') {
    println "${version} is a valid version"
  } else {
    println "${version} is an invalid version"
    throw new Exception("Invalid version")
  }
  //Execute bash script, catch and print output and errors
  node('worker') {
    withCredentials([string(credentialsId: 'githubtoken', variable: 'GITHUB_TOKEN')]) {
      sh "curl -O https://raw.githubusercontent.com/puppetlabs/puppet_jenkins_shared_libraries/master/vars/bash/installer_team_release_creation_job.sh"
      sh "chmod +x installer_team_release_creation_job.sh"
      sh "bash installer_team_release_creation_job.sh $version $codename"
    }
  }
}
