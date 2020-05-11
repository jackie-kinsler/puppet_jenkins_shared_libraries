// to be used directly in declarative pipelines DSL
// dockerfile:"foo" eg `pwd`/Dockerfile
// context:"bar" for the build, ie where to ADD or COPY from eg `pwd` 
// destination:"baz" the full repo/image:tag location eg artifactory.d.p.n/qe/i:t
def call(Map config, body) {
    agent {
        kubernetes {
        yaml """
    apiVersion: v1
    kind: Pod
    metadata:
    spec:
        containers:
        - name: kaniko
            image: gcr.io/kaniko-project/executor:debug-v0.19.0
            command:
            - /busybox/cat
            tty: true
            imagePullPolicy: Always
            volumeMounts:
            - name: host-resolve
            mountPath: /etc/hosts
        volumes:
        - name: host-resolve
            hostPath:
            path: /etc/hosts
            type: File
    imagePullSecrets:
    - name: "artifactorydockercreds"
    """
        }
    }
    container('kaniko') {
        sh "/kaniko/executor --dockerfile ${config.dockerfile} --context ${config.context} --cache=true --destination ${config.destination}"
        body()
    }
}