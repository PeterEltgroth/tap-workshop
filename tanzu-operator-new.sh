#!/bin/bash

read -p "AWS Region Code: " aws_region_code

aws cloudformation delete-stack --region $aws_region_code --stack-name tanzu-operator-stack

aws cloudformation create-stack --region $aws_region_code --stack-name tanzu-operator-stack --template-body file://config/tanzu-operator-stack.yaml
echo "Remove any existing Key Pair, Security Group, and Jumpbox"
aws ec2 delete-key-pair --key-name tanzu-operations-$aws_region_code
rm tanzu-operations-$aws_region_code.pem
aws ec2 delete-security-group --group-name tanzu-operations-$aws_region_code
aws cloudformation delete-stack --region $aws_region_code --stack-name tanzu-operator-stack --no-cli-pager

aws cloudformation wait stack-create-complete --stack-name tanzu-operator-stack --region $aws_region_code
echo "Create Key Pair and Security Group"
aws ec2 create-key-pair --key-name tanzu-operations-$aws_region_code --query 'KeyMaterial' --output text > tanzu-operations-$aws_region_code.pem
chmod 400 tanzu-operations-$aws_region_code.pem
sg_group_id=$(aws ec2 create-security-group --group-name tanzu-operations-$aws_region_code --description "Allow SSH" --output text --no-cli-pager)
aws ec2 authorize-security-group-ingress --group-id $sg_group_id --protocol tcp --port 22 --cidr 0.0.0.0/0 --no-cli-pager

aws cloudformation describe-stacks --stack-name tanzu-operator-stack --region $aws_region_code --query "Stacks[0].Outputs[?OutputKey=='PublicDnsName'].OutputValue" --output text
echo "Create jumpbox"
aws cloudformation create-stack --region $aws_region_code --stack-name tanzu-operator-stack --template-body file://config/tanzu-operator-stack.yaml --no-cli-pager

aws cloudformation wait stack-create-complete --stack-name tanzu-operator-stack --region $aws_region_code --no-cli-pager

aws cloudformation describe-stacks --stack-name tanzu-operator-stack --region $aws_region_code --query "Stacks[0].Outputs[?OutputKey=='PublicDnsName'].OutputValue" --output text --no-cli-pager
