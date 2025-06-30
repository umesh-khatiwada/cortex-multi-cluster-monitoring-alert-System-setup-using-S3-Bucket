#!/bin/bash

#s3 ruler_storage  & altert storage
ruler_BucketName=cortex-ruler-alertmanager-storage
ruler_AccessKeyId=fake_AKIAV3QV2TJG2JKF5P
ruler_SecretAccessKey=fake_UbEEmH69CGrLpPzvSJHJFaVY7qWcEcokRA3g4f
ruler_Endpoint=s3.ap-southeast-1.amazonaws.com
ruler_Region=ap-southeast-1

#s3 blocks_storage  
blocks_BucketName=cortex-prometheus
blocks_AccessKeyId=fake_AKIAV3QV2TJG2JKF5PEG
blocks_SecretAccessKey=fake_UbEEmH69CGrLpPzvSJHJFaVY7qWcEcokRA3g4f
blocks_Endpoint=s3.ap-southeast-1.amazonaws.com
rblocks_Region==ap-southeast-1

#default cortex ngginx password
adminPass="$apr1$nrby0wtu$Eok15nxLwYTJeYqddN.gQ0"

#remote Variable
remoteUser="$remote_user"
