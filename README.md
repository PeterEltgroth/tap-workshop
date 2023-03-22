# TAP Workshop

This repository offers application developers and operators practical examples for getting started with TAP (Tanzu Application Platform). The following is a common set of use-cases most applications will encounter.

* [TAP Services Toolkit](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/index.html), used to make backend services, such as, databases, caches, queues, and more, easily discoverable across numerous disparate platforms and to bind the connection details to application workloads.

## Prerequisites

* Ubuntu Linux
  1. `chmod +x *.sh`
  2. Run [./tanzu-operator-new.sh](tanzu-operator-new.sh) to create an Ubuntu Jumpbox on AWS.
  3. SSH to it: `ssh ubuntu@<vm-name.,aws-region>.compute.amazonaws.com -i tanzu-operations-<aws-region>.pem`
  4. Clone this repo to the jumpbox: `git clone https://github.com/nycpivot/tap-workshop.git`
  5. `cd tap-workshop`
  6. `chmod +x *.sh`

Run [./tanzu-operator-prereqs.sh](tanzu-operator-prereqs.sh) to install the following tools.

* Docker
* AWS CLI
* kubectl (1.23)
* Miscellaneous tools (helm, jq)

## Getting Started

TAP is a complete end-to-end supply chain capable of monitoring a source code repository for changes, compiling and building executable binaries packaged into OCI-conformant containers, deployed to any Kubernetes cluster running on-premises or a public cloud provider. This requires several different components with different responsibilities communicating with one another.

Depending on the environment TAP will be deployed to, these different components can all be installed on a single cluster or multiple clusters. This repository contains AWS CloudFormation templates for bootstrapping either a single AWS EKS Cluster or multiple AWS EKS Clusters into their own respective VPCs, depending on the environment. TAP refers to these as Full Profile and Multi Profile, respectively.

* [Single Cluster](full-profile/README.md)
* [Multi Cluster](multi-profile/../README.md)

Navigate to either of these links to begin installation steps.
