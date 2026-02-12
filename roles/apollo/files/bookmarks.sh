#!/bin/env bash

PERSONAL_PROFILE=Default
BUSINESS_PROFILE="Profile 1"

PERSONAL_SOURCE_FILE=$( mktemp )
PERSONAL_APOLLO_PATH=$( mktemp -p /mnt/zeus/Downloads/ )
PERSONAL_ZEUS_PATH=/mnt/raid/Downloads/$( echo ${PERSONAL_APOLLO_PATH} | awk -F '/' '{ print $5 }')

BUSINESS_SOURCE_FILE=$( mktemp )
BUSINESS_APOLLO_PATH=$( mktemp -p /mnt/zeus/Downloads/ )
BUSINESS_ZEUS_PATH=/mnt/raid/Downloads/$( echo ${BUSINESS_APOLLO_PATH} | awk -F '/' '{ print $5 }')

cp "${HOME}/.config/google-chrome/${PERSONAL_PROFILE}/Bookmarks" ${PERSONAL_SOURCE_FILE}
jq 'del(.roots.bookmark_bar.children[0].children[1,2,4],.roots.bookmark_bar.children[45:],.roots.synced.children,.sync_metadata)' ${PERSONAL_SOURCE_FILE} > ${PERSONAL_APOLLO_PATH}
ssh zeus "rclone copyto ${PERSONAL_ZEUS_PATH} onedrive:/bookmarks/personal/Bookmarks && rm ${PERSONAL_ZEUS_PATH}"

cp "${HOME}/.config/google-chrome/${BUSINESS_PROFILE}/Bookmarks" ${BUSINESS_SOURCE_FILE}
jq 'del(.roots.bookmark_bar.children[0],.sync_metadata)' $BUSINESS_SOURCE_FILE > $BUSINESS_APOLLO_PATH
ssh zeus "rclone copyto ${BUSINESS_ZEUS_PATH} onedrive:/bookmarks/business/Bookmarks && rm ${BUSINESS_ZEUS_PATH}"
