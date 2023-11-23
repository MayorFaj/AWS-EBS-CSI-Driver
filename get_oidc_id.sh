#!/bin/bash

# Set the cluster_name variable
export cluster_name=rias-billind-dev2

# Use AWS CLI to describe the EKS cluster and retrieve the OIDC issuer URL
oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

# Print the OIDC ID
echo $oidc_id
