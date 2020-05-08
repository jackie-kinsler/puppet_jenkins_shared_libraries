import com.puppet.jenkinsSharedLibraries.k8.kaniko
// to be used directly in declarative pipelines DSL
// dockerfile eg `pwd`/Dockerfile
// context for the build, ie where to ADD or COPY from eg `pwd` 
// destination the full repo/image:tag location eg artifactory.d.p.n/qe/i:t
def call(dockerfile, context, destination) {
    new kanikoBuildAndPush(dockerfile, context, destination)
}