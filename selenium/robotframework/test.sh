
IMAGE=$1
SUITE=$2

COLOR_NC='\e[0m'
COLOR_BLUE='\e[0;34m'
COLOR_RED='\e[0;31m'
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

OUTPUT_DIR=robotframework-selenium.tests

if podman volume exists ${OUTPUT_DIR}; then 
    echo "VOLUME $OUTPUT_DIR exists"; 
else
    podman volume create ${OUTPUT_DIR}
fi

function final_report {
    REPORT="$(podman volume inspect ${OUTPUT_DIR} | jq -r '.[].Mountpoint')/report.html"
    REPORT_LINK="\e]8;;file://${REPORT}\e\\$REPORT\e]8;;\e\\"
    FINAL_REPORT="${FINAL_REPORT}\t${REPORT_LINK}\n"
    echo -e $FINAL_REPORT
}

testdir="$SCRIPT_DIR/test";
ls $testdir

if podman run -it --rm -v "$SCRIPT_DIR/test:/test:ro,z" -v ${OUTPUT_DIR}:/out:rw,z ${IMAGE} robot -d /out --name "$IMAGE" /test/${SUITE}.robot ; then
   FINAL_REPORT="${FINAL_REPORT}${IMAGE} : ${COLOR_BLUE}tests passed${COLOR_NC}\n"
   final_report
else
   FINAL_REPORT="${FINAL_REPORT}${IMAGE} : ${COLOR_RED}tests failed${COLOR_NC}\n"
   final_report
   exit -1
fi

