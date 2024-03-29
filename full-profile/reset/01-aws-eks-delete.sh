#!/bin/bash

export EKS_CLUSTER_NAME=tap-full

classic_lb=$(aws elb describe-load-balancers | jq -r .LoadBalancerDescriptions[].LoadBalancerName)
network_lb=$(aws elbv2 describe-load-balancers | jq -r .LoadBalancers[].LoadBalancerArn)

aws elb delete-load-balancer --load-balancer-name $classic_lb
aws elbv2 delete-load-balancer --load-balancer-arn $network_lb

sleep 10

aws ec2 describe-internet-gateways

#aws ecr delete-repository --repository-name tap-images --region $AWS_REGION --force
#aws ecr delete-repository --repository-name tap-build-service --region $AWS_REGION --force

aws ecr delete-repository --repository-name tanzu-application-platform/tanzu-java-web-app-default --region $AWS_REGION --force
aws ecr delete-repository --repository-name tanzu-application-platform/tanzu-java-web-app-default-bundle --region $AWS_REGION --force

# aws eks delete-nodegroup --cluster-name $EKS_CLUSTER_NAME --nodegroup-name ${EKS_CLUSTER_NAME}-node-group
# aws eks wait nodegroup-active --cluster-name $EKS_CLUSTER_NAME --nodegroup-name ${EKS_CLUSTER_NAME}-node-group

# aws eks delete-cluster --name $EKS_CLUSTER_NAME


eksctl delete cluster --name $EKS_CLUSTER_NAME

rm .kube/config

#aws cloudformation delete-stack --stack-name tap-workshop-singlecluster-stack --region $AWS_REGION
#aws cloudformation wait stack-delete-complete --stack-name tap-workshop-singlecluster-stack --region $AWS_REGION

#vpc_id=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Value=='tap-workshop-singlecluster-vpc']].VpcId" --output text)

#aws ec2 delete-vpc --vpc-id $vpc_id --force
#aws ec2 wait delete-vpc --vpc-id $vpc_id --force

#aws cloudformation delete-stack --stack-name tap-workshop-singlecluster-stack --region $AWS_REGION
#aws cloudformation wait stack-delete-complete --stack-name tap-workshop-singlecluster-stack --region $AWS_REGION



#hosted_zones_count=$(aws route53 get-hosted-zone-count | jq .HostedZoneCount)
#hosted_zones=$(aws route53 list-hosted-zones | jq -r .HostedZones)
#hosted_zones_count=$(echo $hosted_zones | jq length)

#index=0
#while [ $index -lt ${hosted_zones_count} ]
#do
#  hosted_zone_name=$(aws route53 list-hosted-zones | jq -r .HostedZones[$index].Name)
#  counter=`expr $index + 1`
#  index=`expr $index + 1`
  
#  echo "$counter) $hosted_zone_name"
#done


#vpc="vpc-xxxxxxxxxxxxx" 
#aws ec2 describe-internet-gateways --filters 'Name=attachment.vpc-id,Values='$vpc | grep InternetGatewayId
#aws ec2 describe-subnets --filters 'Name=vpc-id,Values='$vpc | grep SubnetId
#aws ec2 describe-route-tables --filters 'Name=vpc-id,Values='$vpc | grep RouteTableId
#aws ec2 describe-network-acls --filters 'Name=vpc-id,Values='$vpc | grep NetworkAclId
#aws ec2 describe-vpc-peering-connections --filters 'Name=requester-vpc-info.vpc-id,Values='$vpc | grep VpcPeeringConnectionId
#aws ec2 describe-vpc-endpoints --filters 'Name=vpc-id,Values='$vpc | grep VpcEndpointId
#aws ec2 describe-nat-gateways --filter 'Name=vpc-id,Values='$vpc | grep NatGatewayId
#aws ec2 describe-security-groups --filters 'Name=vpc-id,Values='$vpc | grep GroupId
#aws ec2 describe-instances --filters 'Name=vpc-id,Values='$vpc | grep InstanceId
#aws ec2 describe-vpn-connections --filters 'Name=vpc-id,Values='$vpc | grep VpnConnectionId
#aws ec2 describe-vpn-gateways --filters 'Name=attachment.vpc-id,Values='$vpc | grep VpnGatewayId
#aws ec2 describe-network-interfaces --filters 'Name=vpc-id,Values='$vpc | grep NetworkInterfaceId
