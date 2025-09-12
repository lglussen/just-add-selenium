# Support tools needed for downloading and unpacking webdrivers
dnf install jq unzip dos2unix -y

# Firefox Webdriver (geckodriver)
json=`curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest` && \
GEKODRIVER=`echo " $json "  | jq -r ' .assets[].browser_download_url | select(contains("linux64") and endswith("tar.gz")) '` && \
curl -L -o geckodriver.tar.gz $GEKODRIVER && \
tar -xvf geckodriver.tar.gz && \
mv geckodriver /tmp/geckodriver

# Microsoft Edge Webdriver 
# LATEST_STABLE=`curl -L -o - $API_URL/LATEST_STABLE | dos2unix`
ZIP=edgedriver_linux64.zip                                     && \
API_URL=https://msedgedriver.azureedge.net                     && \
VERSION=`microsoft-edge --version | grep -Eo '[0-9\.]+'`       && \
curl -L -o $ZIP $API_URL/$VERSION/$ZIP                         && \
unzip $ZIP && mv msedgedriver /tmp/

# Google Chrome / Chromium Webdriver
if [ -f /tmp/google-chrome-version ]; then \
    VERSION=`chromium-browser --version | grep -Eo '[0-9\.]+'` && \
    DOWNLOAD_JSON=https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json && \
    DRIVER=`curl $DOWNLOAD_JSON | jq -r " .versions[] | select(.version==\"${VERSION}\").downloads.chromedriver[] | select(.platform==\"linux64\").url"` && \
    curl -L -o chromedriver.zip $DRIVER && \
    unzip chromedriver.zip && \
    mv chromedriver-linux64/chromedriver /tmp/;\
fi

# Entrypoint file
cat <<-EOF > /usr/bin/entrypoint
	#!/bin/bash
	export DISPLAY=:10
	echo "running script: \${@}"
	xvfb-run -s "-screen 0 ${DISPLAY_SIZE}" "\${@}"
EOF
chmod 755 /usr/bin/entrypoint