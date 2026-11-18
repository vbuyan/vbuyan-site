#!/usr/bin/env bash
# One-time bootstrap, run in AWS CloudShell by the account owner.
# Creates the three things Terraform cannot create for itself:
#   1. an S3 bucket for Terraform state (versioned, private, encrypted)
#   2. the GitHub Actions OIDC identity provider
#   3. the role GitHub Actions assumes to run Terraform (main branch only)
# Safe to run again: every step checks what already exists.
set -euo pipefail

REPO="vbuyan/vbuyan-site"
REGION="us-east-1"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="vbuyan-tfstate-${ACCOUNT}"
ROLE="vbuyan-site-terraform"
OIDC_URL="token.actions.githubusercontent.com"
OIDC_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/${OIDC_URL}"

echo "Account ${ACCOUNT}, region ${REGION}"

echo "1. State bucket ${STATE_BUCKET}"
if ! aws s3api head-bucket --bucket "${STATE_BUCKET}" 2>/dev/null; then
  aws s3api create-bucket --bucket "${STATE_BUCKET}" --region "${REGION}" >/dev/null
fi
aws s3api put-public-access-block --bucket "${STATE_BUCKET}" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket "${STATE_BUCKET}" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "${STATE_BUCKET}" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "2. GitHub OIDC provider"
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" >/dev/null 2>&1; then
  aws iam create-open-id-connect-provider --url "https://${OIDC_URL}" --client-id-list sts.amazonaws.com >/dev/null
fi

echo "3. Role ${ROLE} (only ${REPO} main branch can assume it)"
TRUST=$(cat <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
 "Principal":{"Federated":"${OIDC_ARN}"},
 "Action":"sts:AssumeRoleWithWebIdentity",
 "Condition":{"StringEquals":{
   "${OIDC_URL}:aud":"sts.amazonaws.com",
   "${OIDC_URL}:sub":"repo:${REPO}:ref:refs/heads/main"}}}]}
EOF
)
if aws iam get-role --role-name "${ROLE}" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "${ROLE}" --policy-document "${TRUST}"
else
  aws iam create-role --role-name "${ROLE}" --assume-role-policy-document "${TRUST}" \
    --description "Terraform for vbuyan.com, assumed by GitHub Actions" --max-session-duration 3600 >/dev/null
fi

POLICY=$(cat <<EOF
{"Version":"2012-10-17","Statement":[
 {"Sid":"State","Effect":"Allow","Action":["s3:ListBucket","s3:GetObject","s3:PutObject","s3:DeleteObject"],
  "Resource":["arn:aws:s3:::${STATE_BUCKET}","arn:aws:s3:::${STATE_BUCKET}/*"]},
 {"Sid":"SiteBucket","Effect":"Allow","Action":"s3:*",
  "Resource":["arn:aws:s3:::vbuyan-site-${ACCOUNT}","arn:aws:s3:::vbuyan-site-${ACCOUNT}/*"]},
 {"Sid":"Edge","Effect":"Allow","Action":["cloudfront:*","acm:*","route53:*","budgets:*"],"Resource":"*"},
 {"Sid":"OwnRoles","Effect":"Allow","Action":"iam:*",
  "Resource":["arn:aws:iam::${ACCOUNT}:role/vbuyan-site-*","arn:aws:iam::${ACCOUNT}:policy/vbuyan-site-*"]},
 {"Sid":"Read","Effect":"Allow","Action":["iam:GetOpenIDConnectProvider","iam:ListOpenIDConnectProviders","sts:GetCallerIdentity"],"Resource":"*"}
]}
EOF
)
aws iam put-role-policy --role-name "${ROLE}" --policy-name terraform --policy-document "${POLICY}"

echo
echo "Done. Set this GitHub repository variable:"
echo "  AWS_ACCOUNT_ID = ${ACCOUNT}"
