The first step in creating a Container Image to write a Dockerfile that specifies the steps used to generate the image. For more information on the specifies of this, please see the Docker documentation [here](https://docs.docker.com/).

As the container build process will include everything in the current directory in the "build context" we'll create a subdirectory called ```container``` that has only what is needed to generate the docker image. Namely, the [Dockerfile](./container/Dockerfile) and the [run_ctmserver.sh](./container/run_ctmserver.sh) shell script that will be used as our entry point.

```
mkdir container
touch container/Dockerfile
touch container/run_ctmserver.sh
```

This could be manually built by running the following docker command:
```
cd container
docker build -t ctmserver:v1.0.0 .
```

However, we'll automate this step, and pushing the tagged image to private docker registry, by including the following stage in our gitlab-ci.yml file:

```
build-master:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]
  tags:
    - kubernetes
    - cluster
  script:
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"username\":\"$CI_REGISTRY_USER\",\"password\":\"$CI_REGISTRY_PASSWORD\"}}}" > /kaniko/.docker/config.json
    - |
      echo "$REGISTRY_CA_CRT" >> /kaniko/ssl/certs/ca-certificates.crt
    - /kaniko/executor --context $CI_PROJECT_DIR/container --dockerfile $CI_PROJECT_DIR/container/Dockerfile --destination $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
  only:
    - tags
```

Note: line ```echo "$REGISTRY_CA_CRT" >> /kaniko/ssl/certs/ca-certificates.crt``` in the above snippet is only needed if using an internal registry where the SSL Certificate won't be trusted by default. If using docker hub, gcr.io, quay.io, or similar, this is not necessary.
