#!/bin/sh
# Get my IP
myip="$(dig +short myip.opendns.com @resolver1.opendns.com)"

# Get the security group
sg="$(aws ec2 describe-security-groups   --filters Name=tag:project,Values=tutorial-cluster | jq '.SecurityGroups[].GroupId' | sed s/\"//g)"

# Add port 22 to the Security Group of the VPC
aws ec2 authorize-security-group-ingress \
        --group-id $sg \
        --protocol tcp \
        --port 22 \
        --cidr "$myip/32" | jq '.'