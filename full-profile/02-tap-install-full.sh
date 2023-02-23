#!/bin/bash

read -p "AWS Account Id: " aws_account_id
read -p "AWS Region Code: " aws_region_code

aws_account_id=964978768106
tap_full_cluster=tap-full
pivnet_user=mjames@pivotal.io
target_registry=tanzuapplicationplatform
git_catalog_repository=tanzu-application-platform
full_domain=full.tap.nycpivot.com
tap_version=1.4.0

#CREDS
pivnet_pass=$(az keyvault secret show --name pivnet-registry-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
refresh_token=$(az keyvault secret show --name pivnet-api-refresh-token --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'${refresh_token}'"}')
access_token=$(echo ${token} | jq -r .access_token)

curl -i -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X GET https://network.pivotal.io/api/v2/authentication

target_registry_secret=$(az keyvault secret show --name tanzu-application-platform-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

#UPDATE KUBECONFIG
arn=arn:aws:eks:${aws_region_code}:${aws_account_id}:cluster

aws eks update-kubeconfig --name $tap_full_cluster --region $aws_region_code

kubectl config rename-context ${arn}/${tap_full_cluster} $tap_full_cluster

kubectl config use-context $tap_full_cluster


#INSTALL CSI PLUGIN
rolename=${tap_full_cluster}-csi-driver-role

aws iam detach-role-policy \
    --role-name ${rolename} \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
    
aws iam delete-role \
    --role-name ${rolename}

#https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html
#INSTALL CSI DRIVER PLUGIN (REQUIRED FOR K8S 1.23)
aws eks delete-addon \
    --cluster-name $tap_full_cluster \
    --addon-name aws-ebs-csi-driver

aws eks create-addon \
    --cluster-name $tap_full_cluster \
    --addon-name aws-ebs-csi-driver \
    --service-account-role-arn "arn:aws:iam::${account_id}:role/${rolename}"

#https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
aws eks describe-cluster --name $tap_full_cluster --query "cluster.identity.oidc.issuer" --output text

#https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
oidc_id=$(aws eks describe-cluster --name $tap_full_cluster --query "cluster.identity.oidc.issuer" --output text | awk -F '/' '{print $5}')
echo "OIDC Id: $oidc_id"

# Check if a IAM OIDC provider exists for the cluster
# https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
if [[ -z $(aws iam list-open-id-connect-providers | grep $oidc_id) ]]; then
    echo "Creating IAM OIDC provider"
    if ! [ -x "$(command -v eksctl)" ]; then
    echo "Error `eksctl` CLI is required, https://eksctl.io/introduction/#installation" >&2
    exit 1
    fi

    eksctl utils associate-iam-oidc-provider --cluster $tap_full_cluster --approve
fi

rm aws-ebs-csi-driver-trust-policy.json
cat <<EOF | tee aws-ebs-csi-driver-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${aws_region_code}.amazonaws.com/id/${oidc_id}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${aws_region_code}.amazonaws.com/id/${oidc_id}:aud": "sts.amazonaws.com",
          "oidc.eks.${aws_region_code}.amazonaws.com/id/${oidc_id}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name $rolename \
  --assume-role-policy-document file://"aws-ebs-csi-driver-trust-policy.json"
  
aws iam attach-role-policy \
  --role-name $rolename \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
  
kubectl annotate serviceaccount ebs-csi-controller-sa \
    -n kube-system --overwrite \
    eks.amazonaws.com/role-arn=arn:aws:iam::${account_id}:role/${rolename}


#TANZU PREREQS
rm -rf $HOME/tanzu
mkdir $HOME/tanzu

cli_filename=tanzu-framework-linux-amd64-v0.25.4.1.tar

rm $HOME/tanzu/${cli_filename}
wget https://network.tanzu.vmware.com/api/v2/products/tanzu-application-platform/releases/1239018/product_files/1404618/download --header="Authorization: Bearer ${access_token}" -O $HOME/tanzu/${cli_filename}
tar -xvf $HOME/tanzu/${cli_filename} -C $HOME/tanzu

export TANZU_CLI_NO_INIT=true
export VERSION=v0.25.4
cd tanzu

sudo install cli/core/$VERSION/tanzu-core-linux_amd64 /usr/local/bin/tanzu

tanzu version
sleep 5

tanzu plugin install --local cli all
tanzu plugin list

cd $HOME

#CLUSTER ESSENTIALS
rm -rf $HOME/tanzu-cluster-essentials
mkdir $HOME/tanzu-cluster-essentials

essentials_filename=tanzu-cluster-essentials-linux-amd64-1.4.0.tgz

rm $HOME/tanzu-cluster-essentials/${essentials_filename}
wget https://network.tanzu.vmware.com/api/v2/products/tanzu-cluster-essentials/releases/1238179/product_files/1407185/download --header="Authorization: Bearer ${access_token}" -O $HOME/tanzu-cluster-essentials/${essentials_filename}
tar -xvf $HOME/tanzu-cluster-essentials/${essentials_filename} -C $HOME/tanzu-cluster-essentials

export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:5fd527dda8af0e4c25c427e5659559a2ff9b283f6655a335ae08357ff63b8e7f
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$pivnet_user
export INSTALL_REGISTRY_PASSWORD=$pivnet_pass
cd $HOME/tanzu-cluster-essentials

./install.sh --yes

sudo cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp
sudo cp $HOME/tanzu-cluster-essentials/imgpkg /usr/local/bin/imgpkg

cd $HOME

docker login registry.tanzu.vmware.com -u $pivnet_user -p $pivnet_pass


#TBS REGISTRY
docker login ${target_registry}.azurecr.io -u $target_registry -p $target_registry_secret

export INSTALL_REGISTRY_HOSTNAME=${target_registry}.azurecr.io
export INSTALL_REGISTRY_USERNAME=$target_registry
export INSTALL_REGISTRY_PASSWORD=$target_registry_secret
export TARGET_REPOSITORY=build-service
export TAP_VERSION=1.4.0

imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${TARGET_REPOSITORY}/tap-packages


#TAP-INSTALL-FULL
kubectl create ns tap-install

tanzu secret registry add tap-registry \
  --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
  --server ${INSTALL_REGISTRY_HOSTNAME} \
  --export-to-all-namespaces --yes --namespace tap-install

tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${TARGET_REPOSITORY}/tap-packages:$TAP_VERSION \
  --namespace tap-install

sleep 30

tanzu package repository get tanzu-tap-repository --namespace tap-install
sleep 5

tanzu package available list --namespace tap-install
sleep 5

tanzu package available list tap.tanzu.vmware.com --namespace tap-install


#TAP INSTALL FULL
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=mjames@pivotal.io
export INSTALL_REGISTRY_PASSWORD=$pivnet_pass

#APPEND GUI SETTINGS
rm tap-values-full.yaml
cat <<EOF | tee tap-values-full.yaml
profile: full
ceip_policy_disclosed: true
shared:
  ingress_domain: "${full_domain}"
buildservice:
  kp_default_repository: ${target_registry}.azurecr.io/build-service
  kp_default_repository_username: $target_registry
  kp_default_repository_password: $target_registry_secret
supply_chain: basic
ootb_supply_chain_basic:
  registry:
    server: ${target_registry}.azurecr.io
    repository: "supply-chain"
  gitops:
    ssh_secret: ""
  cluster_builder: default
  service_account: default
tap_gui:
  service_type: LoadBalancer
  app_config:
    app:
      baseUrl: http://tap-gui.${full_domain}
    catalog:
      locations:
        - type: url
          target: https://github.com/nycpivot/${git_catalog_repository}/catalog-info.yaml
learningcenter:
  ingressDomain: "learningcenter.full.tap.nycpivot.com"
metadata_store:
  app_service_type: LoadBalancer
scanning:
  metadataStore:
    url: ""
grype:
  namespace: "default"
  targetImagePullSecret: "registry-credentials"
contour:
  infrastructure_provider: aws
  envoy:
    service:
      aws:
        LBType: nlb
cnrs:
  domain_name: $full_domain
policy:
  tuf_enabled: false
#tap_telemetry:
#  customer_entitlement_account_number: "CUSTOMER-ENTITLEMENT-ACCOUNT-NUMBER" # (Optional) Identify data for creating Tanzu Application Platform usage reports.
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $tap_version --values-file tap-values-full.yaml -n tap-install
tanzu package installed get tap -n tap-install
tanzu package installed list -A

kubectl get svc -n tanzu-system-ingress

read -p "Tanzu System Ingress IP: " external_ip

nslookup $external_ip
read -p "IP Address: " ip_address

rm change-batch.json
cat <<EOF | tee change-batch.json
{
    "Comment": "Update IP address.",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "*.${full_domain}",
                "Type": "A",
                "TTL": 60,
                "ResourceRecords": [
                    {
                        "Value": "${ip_address}"
                    }
                ]
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id Z0294944QU6R4X4A718M --change-batch file:///$HOME/change-batch.json


#DEVELOPER NAMESPACE
tanzu secret registry add registry-credentials --server ${target_registry}.azurecr.io --username "${target_registry}" --password "${target_registry_secret}" --namespace default

cat <<EOF | kubectl -n default apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default
EOF

echo "DONE"
echo
echo http://tap-gui.${full_domain}
echo

