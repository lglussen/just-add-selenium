#!/usr/bin/bash
# used for building, validating and publishing
# see README.adoc for a more straightforward build approach
set -e
VERSION="1.0"
JAS_IMAGE=quay.io/lglussen/just-add-selenium
RF_IMAGE=quay.io/lglussen/robotframework-selenium
PY_IMAGE=quay.io/lglussen/python-selenium

function error {
   >&2 echo -e "$1"; exit -1
}

function get_base_os {
  REDHAT_RELEASE=$(podman run -it --rm --entrypoint cat "$1" /etc/redhat-release)
  if [[ "$REDHAT_RELEASE" == "Red Hat"* ]]; then
    echo "ubi"
  elif [[ "$REDHAT_RELEASE" == "Fedora"* ]]; then
    echo "fedora"
  else
    error "unknown base OS"
  fi
}

function get_build_dir {
   echo $1 | sed -E "s,quay.io/lglussen/(.*)-selenium.*,\1,g"
}

function jas_image_build {

  BASE_IMAGE=${1:-"registry.fedoraproject.org/fedora:latest"}
  CREDENTIALS_FILE=$2 

  # ERROR if base image is UBI and no subscription-manager service is available on the host or through provided credentials
  if echo $BASE_IMAGE | grep -q ubi && [ -z "$CREDENTIALS_FILE" ] && (! which subscription-manager > /dev/null 2>&1 || ! subscription-manager status > /dev/null 2>&1); then
    error "No subscription manager credentials provided and no registered subscription-manager available on host system"
  fi

  podman pull $BASE_IMAGE

  OS=`podman inspect $BASE_IMAGE | jq -r ' .[].Config.Labels.name'`
  OS_V=`podman inspect $BASE_IMAGE | jq -r ' .[].Config.Labels.version'`

  podman build selenium-base \
              --build-arg BASE_IMAGE=$BASE_IMAGE \
              --build-arg VERSION=$VERSION \
              --build-arg GIT_COMMIT=$(git rev-parse HEAD) \
              -t $JAS_IMAGE:${OS}-${OS_V} \
              -t $JAS_IMAGE:$VERSION \
              -t $JAS_IMAGE:${VERSION}-$(git rev-parse --short HEAD) \
              -t $JAS_IMAGE:latest \
              $(if [[ -n "$CREDENTIALS_FILE" ]]; then echo "--secret=id=creds,src=$CREDENTIALS_FILE"; fi)
}

# test_image <image-name>
function test_image {
    TEST_FILE="./selenium/$(get_build_dir $1)/test.sh"
    if [ -f "$TEST_FILE" ]; then
      echo "===================================================================="
      echo TESTING $1
      sh "$TEST_FILE" $1 $(get_base_os $1);
    else
      echo "NO TESTS FOR $1"
    fi
}
# build_and_test  <base-image> <name/tag>
function build_and_test {
    podman build ./selenium/$(get_build_dir $2)/ --build-arg BASE_IMAGE=$1  \
        -t $2:${OS}-${OS_V} \
        -t $2:${VERSION} \
        -t $2:${VERSION}-$(git rev-parse --short HEAD) \
        -t $2:latest 
    if test_image $2:${OS}-${OS_V}; then 
      echo "PASS"
    else
      error "FAIL"
    fi
}

function build_and_test_child_images {
  # Build and test robotframework-selenium image
  build_and_test $JAS_IMAGE:${OS}-${OS_V} $RF_IMAGE
  # Build and test python-selenium image
  build_and_test $JAS_IMAGE:${OS}-${OS_V} $PY_IMAGE
}

function push_image {
  podman push $1:$VERSION
  podman push $1:latest
  podman push $1:$VERSION-$(git rev-parse --short HEAD)
}

function build_fedora {
  jas_image_build "registry.fedoraproject.org/fedora:latest"
  
  echo "building JUST-ADD-SELENIUM IMAGE from $JAS_IMAGE:${OS}-${OS_V} ..."
  podman build ./selenium/robotframework/ --build-arg BASE_IMAGE=$JAS_IMAGE:${OS}-${OS_V} -t robotframework-selenium:${OS}-${OS_V}

  echo; echo;
  echo "building JUST-ADD-SELENIUM Child images and running any tests ..."
  if build_and_test_child_images; then
      echo; echo;
      echo "All child image builds and tests PASS for $JAS_IMAGE:${OS}-${OS_V}"
      if [[ -z $(git status --porcelain) ]]; then
        echo -e "Git repository is clean.\nTRY TO PUSH IMAGE TO QUAY.IO"
        source .push_secret
        podman login --username $QUAY_USERNAME --password $QUAY_PASSWORD quay.io
        
        push_image $JAS_IMAGE
        push_image $RF_IMAGE
        push_image $PY_IMAGE
      else
        error "Git repository is dirty (has uncommitted changes).\n\tNOT PUSHING IMAGE"
      fi
  else
      error "FAILED child image tests for $JAS_IMAGE:${OS}-${OS_V}: NOT PUSHING IMAGE"
  fi

}

function build_ubi {
  jas_image_build "registry.access.redhat.com/ubi9/ubi:9.5" $1
  if build_and_test_child_images; then
    echo "All child image builds and tests PASS for $JAS_IMAGE:${OS}-${OS_V}"
  else
    error "Failed build or test of child images for $JAS_IMAGE:${OS}-${OS_V}"
  fi
}

function build_robotframework_selenium {
  podman build ./selenium/robotframework/ --build-arg BASE_IMAGE=just-add-selenium:${OS}-${OS_V} -t robotframework-selenium:${OS}-${OS_V}
  sh ./selenium/robotframework/test.sh robotframework-selenium:${OS}-${OS_V} ubi9
}


# Build And Test UBI based builds
build_ubi $SUBSCRIPTION_MANAGER_AUTH_FILE

#Build, Test & Publish Fedora based builds
build_fedora



