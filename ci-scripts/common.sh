#!/bin/bash

##################################################################
# Common variables
##################################################################

${VERBOSE} && set -x

export REGION="${AWS_DEFAULT_REGION}"
export CLUSTER_NAME="${EKS_CLUSTER_NAME}"

export LOG_ARCHIVE_URL=s3://${CLUSTER_NAME}-csd-archives-bucket/pingdirectory
export NAMESPACE=ping-cloud-${CI_COMMIT_REF_SLUG}
export AWS_PROFILE=csg

[[ ${CI_COMMIT_REF_SLUG} != master ]] && export ENVIRONMENT=-${CI_COMMIT_REF_SLUG}

FQDN=${ENVIRONMENT}.${TENANT_DOMAIN}

# Common
LOGS_CONSOLE=https://logs-${CLUSTER_NAME}.${TENANT_DOMAIN}

# Pingdirectory
PINGDIRECTORY_CONSOLE=https://pingdataconsole${FQDN}/console
PINGDIRECTORY_ADMIN=pingdirectory-admin${FQDN}

# Pingfederate
# admin services:
PINGFEDERATE_CONSOLE=https://pingfederate-admin${FQDN}/pingfederate/app
PINGFEDERATE_API=https://pingfederate-admin${FQDN}/pingfederate/app/pf-admin-api/api-docs

# runtime services:
PINGFEDERATE_AUTH_ENDPOINT=https://pingfederate${FQDN}
PINGFEDERATE_OAUTH_PLAYGROUND=https://pingfederate${FQDN}/OAuthPlayground

# Pingaccess
# admin services:
PINGACCESS_CONSOLE=https://pingaccess-admin${FQDN}
PINGACCESS_API=https://pingaccess-admin${FQDN}/pa-admin-api/v3/api-docs

# runtime services:
PINGACCESS_RUNTIME=https://pingaccess${FQDN}
PINGACCESS_AGENT=https://pingaccess-agent${FQDN}

# Source some utility methods.
. ${CI_PROJECT_DIR}/utils.sh

########################################################################################################################
# Configures kubectl to be able to talk to the Kubernetes API server based on the following environment variables:
#
#   - KUBE_CA_PEM
#   - KUBE_URL
#   - EKS_CLUSTER_NAME
#   - AWS_ACCOUNT_ROLE_ARN
#
# If the environment variables are not present, then the function will exit with a non-zero return code.
########################################################################################################################
configure_kube() {
  check_env_vars "KUBE_CA_PEM" "KUBE_URL" "EKS_CLUSTER_NAME" "AWS_ACCOUNT_ROLE_ARN"
  HAS_REQUIRED_VARS=${?}

  if test ${HAS_REQUIRED_VARS} -ne 0; then
    exit 1
  fi

  echo "${KUBE_CA_PEM}" > "$(pwd)/kube.ca.pem"

  kubectl config set-cluster "${EKS_CLUSTER_NAME}" \
    --server="${KUBE_URL}" \
    --certificate-authority="$(pwd)/kube.ca.pem"

  kubectl config set-credentials aws \
    --exec-command aws-iam-authenticator \
    --exec-api-version client.authentication.k8s.io/v1alpha1 \
    --exec-arg=token \
    --exec-arg=-i --exec-arg="${EKS_CLUSTER_NAME}" \
    --exec-arg=-r --exec-arg="${AWS_ACCOUNT_ROLE_ARN}"

  kubectl config set-context "${EKS_CLUSTER_NAME}" \
    --cluster="${EKS_CLUSTER_NAME}" \
    --user=aws

  kubectl config use-context "${EKS_CLUSTER_NAME}"
}

########################################################################################################################
# Configures the aws CLI to be able to talk to the AWS API server based on the following environment variables:
#
#   - AWS_ACCESS_KEY_ID
#   - AWS_ACCESS_KEY_ID
#   - AWS_DEFAULT_REGION
#   - AWS_ACCOUNT_ROLE_ARN
#
# If the environment variables are not present, then the function will exit with a non-zero return code. The AWS config
# and credentials file will be set up with a profile of ${AWS_PROFILE} environment variable defined in the common.sh
# file.
########################################################################################################################
configure_aws() {
  check_env_vars "AWS_ACCESS_KEY_ID" "AWS_ACCESS_KEY_ID" "AWS_DEFAULT_REGION" "AWS_ACCOUNT_ROLE_ARN"
  HAS_REQUIRED_VARS=${?}

  if test ${HAS_REQUIRED_VARS} -ne 0; then
    exit 1
  fi

  mkdir -p ~/.aws

  cat > ~/.aws/config <<EOF
  [default]
  output = json

  [profile ${AWS_PROFILE}]
  output = json
  region = ${AWS_DEFAULT_REGION}
  source_profile = default
  role_arn = ${AWS_ACCOUNT_ROLE_ARN}
EOF

  cat > ~/.aws/credentials <<EOF
  [default]
  aws_access_key_id = ${AWS_ACCESS_KEY_ID}
  aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}

  [${AWS_PROFILE}]
  role_arn = ${AWS_ACCOUNT_ROLE_ARN}
EOF
}