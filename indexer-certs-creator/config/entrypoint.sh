#!/bin/bash
# Wazuh Docker Copyright (C) 2021 Wazuh Inc. (License GPLv2)

##############################################################################
# Downloading Cert Gen Tool
##############################################################################

## Variables
CERT_TOOL=wazuh-certs-tool.sh
PASSWORD_TOOL=wazuh-passwords-tool.sh
PACKAGES_URL=https://packages.wazuh.com/4.3/
PACKAGES_DEV_URL=https://packages-dev.wazuh.com/4.3/

## Check if the cert tool exists in S3 buckets
CERT_TOOL_PACKAGES=$(curl --silent -I $PACKAGES_URL$CERT_TOOL | grep -E "^HTTP" | awk  '{print $2}')
CERT_TOOL_PACKAGES_DEV=$(curl --silent -I $PACKAGES_DEV_URL$CERT_TOOL | grep -E "^HTTP" | awk  '{print $2}')

## If cert tool exists in some bucket, download it, if not exit 1
if [ "$CERT_TOOL_PACKAGES" = "200" ]; then
  curl -o $CERT_TOOL $PACKAGES_URL$CERT_TOOL
  echo "Cert tool exists in Packages bucket"
elif [ "$CERT_TOOL_PACKAGES_DEV" = "200" ]; then
  curl -o $CERT_TOOL $PACKAGES_DEV_URL$CERT_TOOL
  echo "Cert tool exists in Packages-dev bucket"
else
  echo "Cert tool does not exist in any bucket"
  echo "ERROR: certificates were not created"
  exit 1
fi

chmod 700 /$CERT_TOOL

##############################################################################
# Functions
##############################################################################

function cert_parseYaml() {

    local prefix=${2}
    local s='[[:space:]]*'
    local w='[a-zA-Z0-9_]*'
    local fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
            -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
            -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  ${1} |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=%s\n", "'$prefix'",vn, $2, $3);
        }
    }'

}

##############################################################################
# Creating Cluster certificates
##############################################################################

/$CERT_TOOL -A
echo "Moving created certificates to destination directory"
cp /wazuh-certificates/* /certificates/
echo "changing certificate permissions"
chmod -R 500 /certificates
chmod -R 400 /certificates/*
echo "Setting UID indexer and dashboard"
chown 1000:1000 /certificates/*
echo "Setting UID for wazuh manager and worker"
cp /certificates/root-ca.pem /certificates/root-ca-manager.pem
cp /certificates/root-ca.key /certificates/root-ca-manager.key
chown 999:997 /certificates/root-ca-manager.pem
chown 999:997 /certificates/root-ca-manager.key

## Parsin cert.yml yo set UID permissions
nodes_server=$( cert_parseYaml /certificates/certs.yml | grep nodes_server_name | sed 's/nodes_server_name=//' )
arr=($nodes_server)

for i in ${arr[@]}; 
do 
  chown 999:997 "/certificates/${i}.pem"
  chown 999:997 "/certificates/${i}-key.pem"
done
