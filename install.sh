#!/bin/bash
set -e
: '


echo "===================================================="
echo "Creating required Environment Variables."
echo "===================================================="

declare AWS_REGION="eu-central-1"
declare EKS_CLUSTER_NAME="rias-billind-dev2"
declare NAMESPACE="kube-system"

################################################

permissions_eso(){

  echo "===================================================="
  echo "Creating IRSA for EKS Cluster"
  echo "===================================================="

  ###########################################################
  # You can skip this step if you have already configured   #
  # IRSA for your Kubernetes Cluster.                       #
  ###########################################################
  
  eksctl utils associate-iam-oidc-provider --cluster ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --approve

  echo "===================================================="
  echo "Setting the required parameters for OIDC Provider"
  echo "===================================================="

  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  OIDC_PROVIDER=$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

  EBS_CSI_SERVICE_ACCOUNT_NAME="ebs-csi-controller-sa"

  echo "===================================================="
  echo "Creating Required IAM Role and Policy"
  echo "===================================================="

  # Creating IAM Trust Policy. 
  cat > aws-ebs-csi-driver-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:${NAMESPACE}:${EBS_CSI_SERVICE_ACCOUNT_NAME}"
        }
      }
    }
  ]
}
EOF
  
  # Setting the required Environment Variables for IRSA (IAM Roles for Service Accounts).
  EBS_CSI_DriverRole="AmazonEKS_EBS_CSI_DriverRole"
  EBS_CSI_IAM_ROLE_DESCRIPTION='IRSA role for EKS EBS CSI'

  aws iam create-role --role-name "${EBS_CSI_DriverRole}" --assume-role-policy-document file://aws-ebs-csi-driver-trust-policy --description "${EBS_CSI_IAM_ROLE_DESCRIPTION}"

  EBS_CSI_IAM_ROLE_ARN=$(aws iam get-role --role-name=${EBS_CSI_DriverRole} --query Role.Arn --output text
  
  echo "==================================="
  echo "Attach the AWS managed policy to the role"
  echo "================================"

  aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --role-name "${EBS_CSI_DriverRole}"

  echo "Attached."

  echo "===================================================="
  echo "Add the Amazon EBS CSI add-on"
  echo "===================================================="

  aws eks create-addon --cluster-name ${EKS_CLUSTER_NAME} --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/${EBS_CSI_DriverRole}
  
}

permissions_eso