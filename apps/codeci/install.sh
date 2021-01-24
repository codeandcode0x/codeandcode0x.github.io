#!/bin/bash

: ${USE_SUDO:="false"}
CODECI_HTTP_REQUEST_CLI=wget

CODECI_CLI_FILENAME=codeci

CODECI_INSTALL_DIR="/usr/local/bin"

CODECI_CLI_FILE="${CODECI_INSTALL_DIR}/${CODECI_CLI_FILENAME}"

# GITHUB_TOKEN="40c68b1cda1bf76802c04d06530bafff96478aa5"

GITHUB_ORG=codeandcode0x
GITHUB_REPO=codeci


getOS() {
    ARCH=$(uname -m)
    case $ARCH in
        armv7*) ARCH="arm";;
        aarch64) ARCH="arm64";;
        x86_64) ARCH="amd64";;
    esac

    OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')

    # Most linux distro needs root permission to copy the file to /usr/local/bin
    if [ "$OS" == "linux" ] && [ "$CODECI_INSTALL_DIR" == "/usr/local/bin" ]; then
        USE_SUDO="true"
    fi
}


runAsRoot() {
    local CMD="$*"

    if [ $EUID -ne 0 -a $USE_SUDO = "true" ]; then
        CMD="sudo $CMD"
    fi
    echo $CMD

    $CMD
}

verifySupportedOS() {
    local supported=(darwin-amd64 linux-amd64 linux-arm linux-arm64)
    local current_osarch="${OS}-${ARCH}"

    for osarch in "${supported[@]}"; do
        if [ "$osarch" == "$current_osarch" ]; then
            echo "Your system is ${OS}_${ARCH}"
            return
        fi
    done

    echo "No prebuilt binary for ${current_osarch}"
    exit 1
}


echo "Check and install codeci."

# if we don't have folder vimfiles, create it.
if [ ! -d "~/.codeci/" ]; then
    mkdir ~/.codeci/
fi


checkHttpRequestCLI() {
    if type "curl" > /dev/null; then
        CODECI_HTTP_REQUEST_CLI=curl
    elif type "wget" > /dev/null; then
        CODECI_HTTP_REQUEST_CLI=wget
    else
        echo "Either curl or wget is required"
        exit 1
    fi
}

checkExistingCodeci() {
    if [ -f "$CODECI_CLI_FILE" ]; then
        echo -e "\nCodeci CLI is detected:"
        echo -e "Reinstalling Codeci CLI - ${CODECI_CLI_FILE}...\n"
    else
        echo -e "Installing Codeci CLI...\n"
    fi
}


getLatestRelease() {
    local codeciReleaseUrl="https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}/releases?client_id=7e1acb365f08bdf6eb00&client_secret=673fc9a42c2821c945287b48ac14129d2b8aebd2"
    local latest_release=""

    if [ "$CODECI_HTTP_REQUEST_CLI" == "curl" ]; then
        latest_release=$(curl -s $codeciReleaseUrl | grep \"tag_name\" | grep -v rc | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    else
        latest_release=$(wget -q --header="Accept: application/json" -O - $codeciReleaseUrl | grep \"tag_name\" | grep -v rc | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    fi

    ret_val=$latest_release
}


downloadFile() {
    LATEST_RELEASE_TAG=$1

    CODECI_CLI_ARTIFACT="${CODECI_CLI_FILENAME}-${LATEST_RELEASE_TAG}-${OS}-${ARCH}.tar.gz"
    # convert `-` to `_` to let it work
    DOWNLOAD_BASE="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download"
    DOWNLOAD_URL="${DOWNLOAD_BASE}/${LATEST_RELEASE_TAG}/${CODECI_CLI_ARTIFACT}"

    # Create the temp directory
    CODECI_TMP_ROOT=$(mktemp -dt codeci-install-XXXXXX)
    ARTIFACT_TMP_FILE="$CODECI_TMP_ROOT/$CODECI_CLI_ARTIFACT"

    echo "Downloading $DOWNLOAD_URL ..."
    if [ "$CODECI_HTTP_REQUEST_CLI" == "curl" ]; then
        curl -SsL "$DOWNLOAD_URL" -o "$ARTIFACT_TMP_FILE"
    else
        echo "$ARTIFACT_TMP_FILE" "$DOWNLOAD_URL"
        wget -q -O "$ARTIFACT_TMP_FILE" "$DOWNLOAD_URL"
    fi

    if [ ! -f "$ARTIFACT_TMP_FILE" ]; then
        echo "failed to download $DOWNLOAD_URL ..."
        exit 1
    fi
}


installFile() {
    echo $ARTIFACT_TMP_FILE  $CODECI_TMP_ROOT
    tar xf "$ARTIFACT_TMP_FILE" -C "$CODECI_TMP_ROOT"
    local tmp_root_codeci_cli="$CODECI_TMP_ROOT/${OS}-${ARCH}/$CODECI_CLI_FILENAME"

    echo $tmp_root_codeci_cli

    if [ ! -f "$tmp_root_codeci_cli" ]; then
        echo "Failed to unpack Codeci CLI executable."
        exit 1
    fi

    chmod o+x $tmp_root_codeci_cli
    runAsRoot cp "$tmp_root_codeci_cli" "$CODECI_INSTALL_DIR"

    if [ -f "$CODECI_CLI_FILE" ]; then
        echo "$CODECI_CLI_FILENAME installed into $CODECI_INSTALL_DIR successfully."
    else 
        echo "Failed to install $CODECI_CLI_FILENAME"
        exit 1
    fi

    HOME_DIR="~/.codeci/"
    if [ ! -d $HOME_DIR ]; then
        mkdir -p $HOME_DIR
    fi

    if [ ! -d "$HOME_DIR/deployconfig.json" ]; then
        cat << EOF >HOME_DIR/deployconfig.json
{
  "servicepath": "[service paths]",
  "dbsrcname": "[database service name]",
  "namespace": "[namespace]",
  "dbuser": "[database user]",
  "dbpasswd": "[database passwd]",
  "dbname": "[database]",
  "nocheck": [
    "[no check service list]"
  ],
  "apprun": [
    "nginx",
  ]
}
EOF
    fi
}


getOS
verifySupportedOS
echo $OS

checkHttpRequestCLI
checkExistingCodeci

if [ -z "$1" ]; then
    echo "Getting the latest Codeci CLI..."
    getLatestRelease
else
    ret_val=v$1
fi

downloadFile $ret_val
installFile

#
echo "|"
echo "You can run 'codeci -h' to preview help."


