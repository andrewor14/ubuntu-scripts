#!/bin/bash

# ============================================================================
#  A script to download an Ubuntu package (.deb) with all of its dependencies
# ============================================================================

if [[ "$#" != 1 ]]; then
  echo "Usage: download.sh <package_name>"
  exit 1
fi

# Constants
MIRROR1="mirrors.kernel.org"
MIRROR2="security.ubuntu.com"
BASE_URL="https://packages.ubuntu.com"
DISTRIBUTION="bionic" # 18.04
ARCHITECTURE="amd64"
PACKAGE_TO_DOWNLOAD="$1"

# Keep count
num_packages_found=0
num_packages_downloaded=0

# Download with retries, since the Ubuntu website is prone to internal server error
function wget_it() {
  link="$1"
  if [[ "$link" == *".deb" ]]; then
    wget -q --tries=20 --waitretry=1 "$1"
  else
    wget -qO- --tries=20 --waitretry=1 "$1"
  fi
}

# Recursively download a package and its dependencies
# This is the mMain entry way to this program
function download_package() {
  package="$1"
  # First make sure we only handle each package once (there are circular dependencies)
  var_name="$package"_exists
  var_name="$(echo $var_name | sed 's/[-\.]/_/g' | sed 's/\+/plus/g')"
  if [[ -z "${!var_name}" ]]; then
    export "$var_name"="true"
    echo "Checking package '$package'"
    num_packages_found=$((num_packages_found+1))
  else
    echo "Already handled package '$package'"
    return
  fi
  html="$(wget_it $BASE_URL/$DISTRIBUTION/$package)"

  # Download this package
  html2="$(wget_it $BASE_URL/$DISTRIBUTION/$ARCHITECTURE/$package/download)"
  url="$(echo "$html2" | grep "$MIRROR1" | grep 'href' | sed 's/.*href=\"\(.*\)\".*/\1/g')"
  if [[ -z "$url" ]]; then
    url="$(echo "$html2" | grep "$MIRROR2" | grep 'href' | sed 's/.*href=\"\(.*\)\".*/\1/g')"
  fi
  filename="$(echo "$url" | awk -F '/' '{print $NF}')"
  if [[ -z "$url" ]]; then
    echo "  ERROR: Unable to find URL for package $package"
  elif [[ -f "$filename" ]]; then
    echo "  No need to fetch $package because file $filename already exists"
  else
    echo "  Downloading '$package' from $url"
    wget_it "$url"
    num_packages_downloaded=$((num_packages_downloaded+1))
  fi

  # Download dependencies
  deps="$(echo "$html" | grep -A 1 "nonvisual\">dep:" | grep "href" | sed 's/.*>\(.*\)<.*/\1/g')"
  if [[ -n "$deps" ]]; then
    for dep in $deps; do
      download_package "$dep"
    done
  fi
}

download_package "$PACKAGE_TO_DOWNLOAD"

echo "Number of packages found: $num_packages_found"
echo "Number of packages downloaded: $num_packages_found"

