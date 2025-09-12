#!/usr/bin/bash
# used for building, validating and publishing
# see README.adoc for a more straightforward build approach

VERSION="1.0"
IMAGE=quay.io/lglussen/just-add-selenium

function jas_image_build {

  BASE_IMAGE=${1:-"registry.fedoraproject.org/fedora:latest"}
  CREDENTIALS_FILE=$2 

  # ERROR if base image is UBI and no subscription-manager service is available on the host or through provided credentials
  if echo $BASE_IMAGE | grep -q ubi && [ -z "$CREDENTIALS_FILE" ]  && ! subscription-manager status > /dev/null 2>&1; then
    >&2 echo -e "No subscription manager credentials provided and no registered subscription-manager available on host system"; exit -1
  fi
  podman pull $BASE_IMAGE

  OS=`podman inspect $BASE_IMAGE | jq -r ' .[].Config.Labels.name'`
  OS_V=`podman inspect $BASE_IMAGE | jq -r ' .[].Config.Labels.version'`

  podman build selenium-base \
              --build-arg BASE_IMAGE=$BASE_IMAGE \
              --build-arg VERSION=$VERSION \
              --build-arg GIT_COMMIT=$(git rev-parse HEAD) \
              -t $IMAGE:${OS}-${OS_V} \
              -t $IMAGE:$VERSION \
              -t $IMAGE:latest \
              $(if [[ -n "$CREDENTIALS_FILE" ]]; then echo "--secret=id=creds,src=$CREDENTIALS_FILE"; fi)
}

function build_and_run_selenium_tests {
  for dir in `ls -1 selenium`; do
    if [ -f "./$dir/test.sh" ]; then
      TEST_IMAGE=${dir}-selenium:${OS}-${OS_V}
      podman build ./selenium/$dir/ --build-arg BASE_IMAGE=$IMAGE:${OS}-${OS_V} -t $TEST_IMAGE
      sh ./selenium/robotframework/test.sh $TEST_IMAGE $OS;
    fi
  done
}

function build_fedora {
  jas_image_build "registry.fedoraproject.org/fedora:latest"
  
  echo "BUILD TEST CONTAINER ... "
  podman build ./selenium/robotframework/ --build-arg BASE_IMAGE=$IMAGE:${OS}-${OS_V} -t robotframework-selenium:${OS}-${OS_V}
  if build_and_run_selenium_tests; then
      if [[ -z $(git status --porcelain) ]]; then
        echo "Git repository is clean."
        echo "TRY TO PUSH IMAGE TO QUAY.IO"
        echo "podman login quay.io"
        echo "podman push robotframework-selenium:latest"
        echo "podman push robotframework-selenium:$VERSION"
      else
        echo "Git repository is dirty (has uncommitted changes)."
      fi
  else
      echo "DON'T PUSH IMAGE"
  fi

}

function build_ubi {
  jas_image_build "registry.access.redhat.com/ubi9/ubi:9.5" $1
  podman build ./selenium/robotframework/ --build-arg BASE_IMAGE=just-add-selenium:${OS}-${OS_V} -t robotframework-selenium:${OS}-${OS_V}
  sh ./selenium/robotframework/test.sh robotframework-selenium:${OS}-${OS_V} ubi9
}


#podman build ./selenium/computershare/  --build-arg BASE_IMAGE=just-add-selenium:fedora -t computershare
#podman build ./selenium/robotframework/ --build-arg BASE_IMAGE=just-add-selenium:fedora -t robotframework





