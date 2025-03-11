#!/usr/bin/bash
CREDENTIALS_FILE=$1
IMAGES=""

function test {
  IMAGE=$1; RED='\033[1;31m'; BLUE='\033[1;34m'; NC='\033[0m' # No Color
  OUTPUT_DIR=$(sed 's,[:/],_,g' <<< $IMAGE).test-results
  if podman volume exists ${OUTPUT_DIR}; then echo "VOLUME $OUTPUT_DIR exists"; else
      podman volume create ${OUTPUT_DIR}
  fi

  if podman run -it --rm -v ./test:/test:ro,z -v ${OUTPUT_DIR}:/out:rw,z ${IMAGE} robot -d /out /test/all-browsers.robot ; then
    echo -e "${BLUE}[TEST SUCCESS] ${IMAGE}${NC}"
    echo -e "${BLUE} -> do tagging promotion stuff ...${NC}"
    echo -e "${BLUE} -> do image push stuff ...${NC}"
  else
    echo -e "${RED}[TEST FAILURE] ${IMAGE}${NC}"
  fi
  REPORT="$(podman volume inspect ${OUTPUT_DIR} | jq -r '.[].Mountpoint')/report.html"
  echo -e "\e]8;;file://${REPORT}\e\\  ROBOT FRAMEWORK TEST REPORT: report.html ($REPORT)\e]8;;\e\\"
  echo
}

function build {
  METHOD=$1; OS=$2; shift 2;
  OS_NAME=`podman inspect $OS | jq -r ' .[].Config.Labels.name'`
  IMAGE=robot-selenium:${OS_NAME}-${METHOD}
  echo "podman build . --build-arg ROOT_METHOD=$METHOD --build-arg BASE_IMAGE=$OS -t $IMAGE $@"
  podman build . --build-arg ROOT_METHOD=$METHOD --build-arg BASE_IMAGE=$OS -t $IMAGE $@
  test $IMAGE $OS_NAME;
  export IMAGES="${IMAGES}\n${IMAGE}"
}

function test {
  echo "testing: '$1', OS: $2"
}
function test2 {
  IMAGE=$1; OS=$2; RED='\033[1;31m'; BLUE='\033[1;34m'; NC='\033[0m' # No Color
  OUTPUT_DIR=$(sed 's,[:/],_,g' <<< $IMAGE).test-results
  if podman volume exists ${OUTPUT_DIR}; then echo "VOLUME $OUTPUT_DIR exists"; else
      podman volume create ${OUTPUT_DIR}
  fi

  if podman run -it --rm -v ./test:/test:ro,z -v ${OUTPUT_DIR}:/out:rw,z ${IMAGE} robot -d /out /test/${OS}.robot ; then
    echo -e "${BLUE}[TEST SUCCESS] ${IMAGE}${NC}"
    echo -e "${BLUE} -> do tagging promotion stuff ...${NC}"
    echo -e "${BLUE} -> do image push stuff ...${NC}"
  else
    echo -e "${RED}[TEST FAILURE] ${IMAGE}${NC}"
  fi
  REPORT="$(podman volume inspect ${OUTPUT_DIR} | jq -r '.[].Mountpoint')/report.html"
  echo -e "\e]8;;file://${REPORT}\e\\  ROBOT FRAMEWORK TEST REPORT: report.html ($REPORT)\e]8;;\e\\"
  echo
}

build setuid  fedora:latest
build sudoers fedora:latest

if [ -f $CREDENTIALS_FILE ]; then
  build setuid  registry.access.redhat.com/ubi9/ubi:9.5 --secret=id=creds,src=$CREDENTIALS_FILE
  build sudoers registry.access.redhat.com/ubi9/ubi:9.5 --secret=id=creds,src=$CREDENTIALS_FILE
else
  build setuid  registry.access.redhat.com/ubi9/ubi:9.5
  build sudoers registry.access.redhat.com/ubi9/ubi:9.5
fi

echo -e $IMAGES