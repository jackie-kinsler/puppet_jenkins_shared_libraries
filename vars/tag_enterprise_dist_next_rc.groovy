import com.puppet.jenkinsSharedLibraries.BundleInstall

def call(String version, String codename) {

  rubyVersion = "2.5.1"
  def setup_gems = new BundleInstall(rubyVersion)

  sh "${setup_gems.bundleInstall}"

  if (version =~ '^20[0-9]{2}[.]([0-9]*)[.]([0-9]*)$') {
    println "${version} is a valid version"
  } else {
    println "${version} is an invalid version"
    throw new Exception("Invalid version")
  }
  //Execute bash script, catch and print output and errors
  node('worker') {
    sh "curl -O https://raw.githubusercontent.com/puppetlabs/puppet_jenkins_shared_libraries/master/vars/bash/tag_enterprise_dist_next_rc.sh"
    sh "bash tag_enterprise_dist_next_rc.sh $version $codename"
  }
}
