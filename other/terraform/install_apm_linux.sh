#!/bin/bash
# =================================================================
# Copyright 2017 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =================================================================

# Check if a command exists
command_exists() {
  type "$1" &> /dev/null;
}

TEMP_DIR=/tmp

# Check Parameters

if [ "$#" -lt 5 ]; then
    echo "Usage: $0 apm_source source_type source_subdir apm_dir [agents]" >&2
    exit 1
fi

# Assign Parameters

SOURCE=$1
SOURCE_TYPE=$2
SOURCE_SUBDIR=$3
APM_DIR=$4

shift
shift
shift
shift

AGENTS="$@"

# Download APM Installer

cd $TEMP_DIR
case $SOURCE_TYPE  in
    http)
        INSTALLER=${SOURCE##*/}
        curl -O $SOURCE
        ;;
    *) exit 1
esac

tar xvf $INSTALLER

# Modify Silent Install File

cd $SOURCE_SUBDIR
cp APMADV_silent_install.txt APMADV_silent_install.txt.tmp

echo "" >> APMADV_silent_install.txt.tmp
echo "AGENT_HOME=$APM_DIR" >> APMADV_silent_install.txt.tmp
echo "License_Agreement=\"I agree to use the software only in accordance with the installed license.\"" >> APMADV_silent_install.txt.tmp

for AGENT in $AGENTS
do
  echo "INSTALL_AGENT=$AGENT" >> APMADV_silent_install.txt.tmp
done

# Install Pre-requisites

# Identify the platform and version using Python
if command_exists python; then
  PLATFORM=`python -c "import platform;print(platform.platform())" | rev | cut -d '-' -f3 | rev | tr -d '".' | tr '[:upper:]' '[:lower:]'`
  PLATFORM_VERSION=`python -c "import platform;print(platform.platform())" | rev | cut -d '-' -f2 | rev`
else
  if command_exists python3; then
    PLATFORM=`python3 -c "import platform;print(platform.platform())" | rev | cut -d '-' -f3 | rev | tr -d '".' | tr '[:upper:]' '[:lower:]'`
    PLATFORM_VERSION=`python3 -c "import platform;print(platform.platform())" | rev | cut -d '-' -f2 | rev`
  fi
fi
# Check if the executing platform is supported
if [[ $PLATFORM == *"ubuntu"* ]] || [[ $PLATFORM == *"redhat"* ]] || [[ $PLATFORM == *"rhel"* ]] || [[ $PLATFORM == *"centos"* ]]; then
  echo "[*] Platform identified as: $PLATFORM $PLATFORM_VERSION"
else
  echo "[ERROR] Platform $PLATFORM not supported"
  exit 1
fi
# Change the string 'redhat' to 'rhel'
if [[ $PLATFORM == *"redhat"* ]]; then
  PLATFORM="rhel"
fi

if [[ $PLATFORM == *"ubuntu"* ]]; then
  wait_apt_lock
  PACKAGE_MANAGER=apt-get
  if { sudo -n apt-get -qqy update 2>&1 || echo E: update failed; } | grep -q '^[W]:'; then
    echo "[ERROR] There was an error obtaining the latest packages"
  fi
else
  PACKAGE_MANAGER=yum
  if { sudo -n yum -y update 2>&1 || echo E: update failed; } | grep -q '^[W]:'; then
    echo "[ERROR] There was an error obtaining the latest packages"
  fi
fi

PACAKGES="bc"

for PACKAGE in $PACKAGES
do
  $PACKAGE_MANAGER install -y $PACKAGE
done


# Install Agent
./installAPMAgents.sh -p  APMADV_silent_install.txt.tmp

if $? != 0
then
  exit 1
fi

# Cleanup
rm $TEMP_DIR/$INSTALLER
rm -Rf $TEMP_DIR/$SOURCE_SUBDIR



