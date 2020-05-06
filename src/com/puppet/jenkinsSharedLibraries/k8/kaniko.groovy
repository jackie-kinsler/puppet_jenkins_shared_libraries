package com.puppet.jenkinsSharedLibraries.k8

public void kaniko(body) {
  podTemplate(
    containers: [ containerTemplate( name: 'kaniko',
                                     image: 'gcr.io/kaniko-project/executor:debug-v0.19.0',
                                     alwaysPullImage: true,
                                     ttyEnabled: true,
                                     command: '/busybox/cat'
                                   )
               ],
    volumes: [ hostPathVolume( hostPath: '/etc/hosts',
                               mountPath: '/etc/hosts'
                             )
             ],
    imagePullSecrets: [ 'artifactorydockercreds' ]
  )
  {
    body.call()
  }
}

public void kanikoBuildAndPush(dockerfile, context, destination) {
  kaniko {
    node (POD_LABEL) {
      container('kaniko') {
        sh "/kaniko/executor --dockerfile ${dockerfile} --context ${context} --cache=true --destination ${destination}"
      }
    }
  }
}
