#!/bin/bash

# Run this script to cach RHCOS images for baremetal intaller


# Latest stable 4.x release as of check-in
VERSION="4.4.0-0.nightly-2020-01-29-012724"
IMAGE_CACHE_FOLDER="image_caches"
if [[ -z "$VERSION" ]]; then
    echo "No version selected, trying \"latest\"..."
    VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/release.txt | grep 'Name:' | awk -F: '{print $2}' | xargs)
fi

# First try to find version in official mirror
RELEASE_IMAGE_SOURCE="https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview"
RELEASE_IMAGE=$(curl -s $RELEASE_IMAGE_SOURCE/$VERSION/release.txt | grep 'Pull From: quay.io' | awk -F ' ' '{print $3}' | xargs)

if [[ -z "$RELEASE_IMAGE" ]]; then
    # Version not found in official mirror, so try CI repo
    RELEASE_IMAGE_SOURCE="https://openshift-release-artifacts.svc.ci.openshift.org"
    RELEASE_IMAGE=$(curl -s $RELEASE_IMAGE_SOURCE/$VERSION/release.txt | grep 'Pull From: registry' | awk -F ' ' '{print $3}' | xargs)
fi

if [[ -z "$RELEASE_IMAGE" ]]; then
    echo "Unable to find release image for version $VERSION!"
    exit 1;
fi

echo "Using version $VERSION from repo $RELEASE_IMAGE_SOURCE"

CMD=openshift-baremetal-install
PULL_SECRET=~/pull-secret.json
EXTRACT_DIR=$(pwd)

# Get the oc binary
if ! [ -f /usr/local/bin/oc ]; then
  curl $RELEASE_IMAGE_SOURCE/$VERSION/openshift-client-linux-$VERSION.tar.gz | tar zxvf - oc
  sudo cp ./oc /usr/local/bin/oc
else
printf "Skipping OC client download(file exists)"
fi


# Extract the baremetal installer
oc adm release extract --registry-config "${PULL_SECRET}" --command=$CMD --to "${EXTRACT_DIR}" ${RELEASE_IMAGE}

COMMIT_ID=$(./openshift-baremetal-install version | grep '^built from commit' | awk '{print $4}')

export RHCOS_OPENSTACK_URI=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .images.openstack.path | sed 's/"//g')
export RHCOS_QEMU_URI=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .images.qemu.path | sed 's/"//g')
export RHCOS_PATH=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json | jq .baseURI | sed 's/"//g')
export RHCOS_QEMU_SHA_UNCOMPRESSED=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json  | jq -r '.images.qemu["uncompressed-sha256"]')
export RHCOS_OPENSTACK_SHA_COMPRESSED=$(curl -s -S https://raw.githubusercontent.com/openshift/installer/$COMMIT_ID/data/data/rhcos.json  | jq -r '.images.openstack.sha256')

#In DEV SCRIPTS change in config_$USER 
printf "\nMACHINE_OS_IMAGE_NAME=$RHCOS_OPENSTACK_URI"
printf "\nMACHINE_OS_IMAGE_SHA256=$RHCOS_OPENSTACK_URI"
printf "\nMACHINE_OS_BOOTSTRAP_IMAGE_NAME=$RHCOS_QEMU_URI"
printf "\nMACHINE_OS_BOOTSTRAP_IMAGE_UNCOMPRESSED_SHA256=$RHCOS_QEMU_SHA_UNCOMPRESSED"

#http://${MIRROR_IP}/images/${MACHINE_OS_IMAGE_NAME}?sha256=${MACHINE_OS_IMAGE_SHA256}
#bootstrapOSImage: http://${MIRROR_IP}/images/${MACHINE_OS_BOOTSTRAP_IMAGE_NAME}?sha256=${MACHINE_OS_BOOTSTRAP_IMAGE_UNCOMPRESSED_SHA256}

printf "\n*****************\n"
printf "RHCOS IMAGE (place this in config file  as \"bootstrapOSImage\"):\n http://172.22.0.1/$RHCOS_QEMU_URI?sha256=$RHCOS_QEMU_SHA_UNCOMPRESSED\n"
printf "RHCOS IMAGE (place this in config file as s \"clusterOSImage\"):\n http://172.22.0.1/$RHCOS_OPENSTACK_URI?sha256=$RHCOS_OPENSTACK_SHA_COMPRESSED\n"
printf "\n*****************\n"
 

array=($RHCOS_OPENSTACK_URI,$RHCOS_QEMU_URI)

for IMAGE_FILE in "${array[@]}"
do
  mkdir -p "$HOME/$IMAGE_CACHE_FOLDER/images$i"
  COMP_IMAGE_FILE=$(echo "$IMAGE_FILE" | sed 's/x86_64/x86_64compressed/')
  cd "$HOME/image_cache/images/$i"
  
  if [[ ! -f "$COMP_IMAGE_FILE" ]]; then
        echo "Pre-caching $IMAGE_FILE for bootstrap..."
        curl -L "${RHCOS_PATH}${RHCOS_QEMU_URI}" > $IMAGE_FILE
    fi
done
  USER=$(whoami)
  sudo podman rm -f image_cache >/dev/null
  sudo podman run --name image_cache -p 172.22.0.1:80:80/tcp -v /home/"$USER"/"$IMAGE_CACHE_FOLDER":/usr/share/nginx/html:ro -d nginx
