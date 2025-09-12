# register subscription-manager ------------------------------------------------
#   if in a BASE_IMAGE is ubi/rhel and a secret of id=creds have been provided 
if [ -f /etc/redhat-release ]; then
    if grep -q 'Red Hat Enterprise Linux release' /etc/redhat-release; then
        if [ -f /run/secrets/creds ]; then
            source /run/secrets/creds && subscription-manager register --username $USERNAME --password $PASSWORD;
        else
            echo -e '\n\n\033[1;31m[WARNING]\033[0m subscription-manager credentials not provided\n\texample: `--secret=id=creds,src=<path/to/credentials>`\n\tThis is fine if the host system is RHEL with a registered subscription-manager\n\tIf the host system is not RHEL, expect dnf installs to fail for packages not in the basic default ubi registries\n\n';
        fi
    fi
    echo -e '/etc/redhat-release: \033[1;34m' `cat /etc/redhat-release` '\033[0m';
else 
    >&2 echo "[ERROR] unsupported OS. Can't find file /etc/redhat-release";
    exit 1;
fi


set -e

# Virtual Display Buffer for Graphical Goodness --------------------------------
dnf install -y xorg-x11-server-Xvfb 

# Browser(s) Install -----------------------------------------------------------

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
