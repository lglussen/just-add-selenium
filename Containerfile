ARG DISPLAY_SIZE="1920x1200x24"
ARG ROOT_METHOD=setuid
ARG BASE_IMAGE=registry.access.redhat.com/ubi9/ubi:9.5

# ===================== Browser Bundle =========================================
# - Virtual Display Buffer (screenshot rendering / non-headless browser testing)
# - Major browsers installed and versions recorded
FROM $BASE_IMAGE as Browser_Bundle

# register subscription-manager if in a BASE_IMAGE is ubi/rhel and a secret of id=creds has been provided
RUN --mount=type=secret,id=creds \
    if [ -f /etc/redhat-release ]; then \
        if grep -q 'Red Hat Enterprise Linux release' /etc/redhat-release; then \
            if [ -f /run/secrets/creds ]; then \
                source /run/secrets/creds && subscription-manager register --username $USERNAME --password $PASSWORD; \
            else \
                echo -e '\n\n\033[1;31m[WARNING]\033[0m subscription-manager credentials not provided\n\texample: `--secret=id=creds,src=<path/to/credentials>`\n\tThis is fine if the host system is RHEL with a registered subscription-manager\n\tIf the host system is not RHEL, expect dnf installs to fail for packages not in the basic default ubi registries\n\n';\
            fi; \
        else \
          echo -e '\033[1;31m[' `cat /etc/redhat-release` ']\033[0m';\
        fi; \
    else \
        >&2 echo "[ERROR] unsupported OS. Can't find file /etc/redhat-release";\
        exit 1;\
    fi

# Virtual Display Buffer for Graphical Goodness
RUN dnf install -y xorg-x11-server-Xvfb  && dnf clean all

# Browser(s) Install --------------
RUN <<EOF
    set -e

    # Firefox THE PEOPLES BROWSER
    dnf install -y firefox
    
    # MS-EDGE-LORD
    curl -L -o /etc/yum.repos.d/ms-edge.repo https://packages.microsoft.com/yumrepos/edge/config.repo
    dnf install -y microsoft-edge-stable

    # Add Chrome/Chromium browsers for Fedora (Seemingly unavailable in RHEL9) 
    if grep -q 'Fedora release' /etc/redhat-release; then
        # Chromium - OG Chrome
        dnf install -y chromium
        
        # Google Chrome - corporate spyware
        dnf install -y fedora-workstation-repositories
        dnf config-manager setopt google-chrome.enabled=1
        dnf install -y google-chrome-stable
    fi

    dnf clean all
EOF

# -------------------------- Binary Prep ---------------------------------------
# Build container for downloading, unpacking & preparing web-driver dependencies
# scripts and other binaries.
# Built on Browser_Bundle to access the browser versions & pair webdrivers
# ------------------------------------------------------------------------------
FROM Browser_Bundle as staging
ARG DISPLAY_SIZE

# Support tools needed for downloading and unpacking webdrivers
RUN dnf install jq unzip dos2unix -y

# Firefox Webdriver (geckodriver)
RUN json=`curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest` && \
    GEKODRIVER=`echo " $json "  | jq -r ' .assets[].browser_download_url | select(contains("linux64") and endswith("tar.gz")) '` && \
    curl -L -o geckodriver.tar.gz $GEKODRIVER && \
    tar -xvf geckodriver.tar.gz && \
    mv geckodriver /tmp/geckodriver

# Microsoft Edge Webdriver 
# LATEST_STABLE=`curl -L -o - $API_URL/LATEST_STABLE | dos2unix`
RUN ZIP=edgedriver_linux64.zip                                     && \
    API_URL=https://msedgedriver.azureedge.net                     && \
    VERSION=`microsoft-edge --version | grep -Eo '[0-9\.]+'`       && \
    curl -L -o $ZIP $API_URL/$VERSION/$ZIP                         && \
    unzip $ZIP && mv msedgedriver /tmp/

# Google Chrome / Chromium Webdriver
RUN if [ -f /tmp/google-chrome-version ]; then \
        VERSION=`chromium-browser --version | grep -Eo '[0-9\.]+'` && \
        DOWNLOAD_JSON=https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json && \
        DRIVER=`curl $DOWNLOAD_JSON | jq -r " .versions[] | select(.version==\"${VERSION}\").downloads.chromedriver[] | select(.platform==\"linux64\").url"` && \
        curl -L -o chromedriver.zip $DRIVER && \
        unzip chromedriver.zip && \
        mv chromedriver-linux64/chromedriver /tmp/;\
    fi

# Entrypoint file
RUN cat <<-EOF > /usr/bin/entrypoint
	#!/bin/bash
	create-display &
	export DISPLAY=:10
	echo "running script: \${@}"
	xvfb-run -s "-screen 0 ${DISPLAY_SIZE}" "\${@}"
EOF
RUN chmod 755 /usr/bin/entrypoint

# Xvfb Option [A]: sudoers file ------------------------------------------------
FROM staging as sudoers
ARG DISPLAY_SIZE
RUN echo "sudo Xvfb :10 -screen 0 ${DISPLAY_SIZE} -ac" > /usr/bin/create-display && \
    chmod 755 /usr/bin/create-display
RUN echo '%root ALL=(root) NOPASSWD:/usr/bin/Xvfb' > /etc/sudoers.d/xvfb

# Xvfb Option [B]: setuid + binary launcher ------------------------------------
FROM staging as setuid
ARG DISPLAY_SIZE
RUN dnf install -y gcc
WORKDIR /opt
RUN cat <<SOURCE > /opt/create-display.c
	#include <stdio.h>
	#include <stdlib.h>
	#include <unistd.h>
	int main(){
	    setuid(0);
	    return system("Xvfb :10 -screen 0 ${DISPLAY_SIZE} -ac");
	}
SOURCE
RUN gcc create-display.c -o /usr/bin/create-display && \
    chmod 4755 /usr/bin/create-display

# Conditional COPY/inclusion of setuid workaround ==============================
FROM Browser_Bundle as include_setuid
COPY --from=setuid /usr/bin/create-display /usr/bin/entrypoint /tmp/*driver /usr/bin/

# Conditional COPY/inclusion of sudoers workaround =============================
FROM Browser_Bundle as include_sudoers
COPY --from=sudoers /usr/bin/create-display /usr/bin/entrypoint /tmp/*driver /usr/bin/
COPY --from=sudoers /etc/sudoers.d/xvfb /etc/sudoers.d/xvfb

# =============== Selenium Ready Base Image ====================================
# Final image based on build-arg ROOT_METHOD value (sudoers|setuid)
# From here you may build out your selenium install and choice of 
# libraries and languages for driving selenium
# ==============================================================================
FROM include_${ROOT_METHOD} as selenium_ready
ENTRYPOINT ["/usr/bin/entrypoint"]

# ==============================================================================
# Robot Framework flavored Selenium
# ==============================================================================
FROM selenium_ready

RUN <<EOF 
    set -e
    # Pip for python dependencies
    dnf install -y python3-pip
    dnf clean all
    # Robotframework & Selenium
    pip3 install \
        robotframework \
        robotframework-seleniumlibrary
    
    # Optional library for annotating screenshots
    pip3 install robotframework-seleniumscreenshots

    ## Optional library for creating and defining the virtural display from 
    ## robotframework test scripts.  By default this image is setup to create 
    ## the display transparently without robot-framework scripts needing to know 
    ## if they are in a headless environment or not 
    pip3 install robotframework-xvfb
    
    # One of Pillow/wxPython/PyGTK/Scrot required by the built-in "Screenshot" Library
    pip3 install Pillow    
    pip3 cache purge
    # non-root user required for launching chrome and edge browsers
    # adding to group 0 to mimic OpenShift default SCC policy behavior 
    useradd -G 0 test
EOF

USER test

RUN cat <<-EOF > /home/test/run
   !#/usr/bin/bash
   robot -d /out /tests
EOF
CMD ["robot", "-d", "/out", "/tests/"]
