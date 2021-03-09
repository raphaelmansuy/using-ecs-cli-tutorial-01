#!/bin/sh

aws ec2 describe-subnets --filters Name=tag:project,Values=tutorial-cluster \
 | jq ".Subnets[].SubnetId" | \
xargs -ISUBNET  aws efs create-mount-target \
 --file-system-id fs-5574bd52 --subnet-id SUBNET

aws ec2 describe-subnets --filters Name=tag:project,Values=tutorial-cluster \
 | jq ".Subnets[].SubnetId" | \
xargs -ISUBNET  aws efs create-mount-target \
 --file-system-id fs-5574bd52 --subnet-id SUBNET


 efs_sg=$(aws efs describe-mount-targets --file-system-id fs-5574bd52 \
	| jq ".MountTargets[0].MountTargetId" \
	 | xargs -IMOUNTG aws efs describe-mount-target-security-groups \
	 --mount-target-id MOUNTG | jq ".SecurityGroups[0]" | xargs echo )

 vpc_sg="$(aws ec2 describe-security-groups  \
 --filters Name=tag:project,Values=tutorial-cluster \
 | jq '.SecurityGroups[].GroupId' | xargs echo)"

aws ec2 authorize-security-group-ingress \
--group-id $efs_sg \
--protocol tcp \
--port 2049 \
--source-group $vpc_sg \
--region us-west-2
