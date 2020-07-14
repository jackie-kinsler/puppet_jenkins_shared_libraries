import com.puppet.jenkinsSharedLibraries.BundleExec

def call(String rubyVersion, String bundleExecCommand) {
  def bundle = new BundleExec(rubyVersion, bundleExecCommand)

  sh "${bundle.bundleExec}"
}
