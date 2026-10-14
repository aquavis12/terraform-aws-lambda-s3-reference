#!/usr/bin/env bash
#
# set-reference-mode.sh
#
# Switches a Lambda function to self-managed S3 "reference" code storage, then
# waits for the update to finish and verifies the mode took effect.
#
# The AWS provider does not yet expose s3_object_storage_mode on
# aws_lambda_function, so the module calls this script from a local-exec
# provisioner. Remove it once the provider supports the argument natively.
#
# Inputs are passed as environment variables so the command line stays simple
# and values with spaces are handled safely:
#   FUNCTION_NAME     - name of the Lambda function
#   AWS_REGION        - region the function lives in
#   S3_BUCKET         - artifact bucket name
#   S3_KEY            - object key of the deployment package
#   S3_OBJECT_VERSION - version id of the deployment package
#
# Requires AWS CLI v2 (2.35.12 or later) on PATH and credentials with
# lambda:UpdateFunctionCode, lambda:GetFunction and lambda:GetFunctionConfiguration.

set -euo pipefail

: "${FUNCTION_NAME:?FUNCTION_NAME is required}"
: "${AWS_REGION:?AWS_REGION is required}"
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${S3_KEY:?S3_KEY is required}"
: "${S3_OBJECT_VERSION:?S3_OBJECT_VERSION is required}"

aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --s3-bucket "$S3_BUCKET" \
  --s3-key "$S3_KEY" \
  --s3-object-version "$S3_OBJECT_VERSION" \
  --s3-object-storage-mode REFERENCE \
  --no-cli-pager

aws lambda wait function-updated-v2 \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION"

mode="$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --query 'Code.S3ObjectStorageMode' \
  --output text 2>/dev/null || true)"

if [ "$mode" != "REFERENCE" ]; then
  # Fallback for CLI versions that nest or omit the field differently.
  mode="$(aws lambda get-function \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION" \
    --query Code --output json \
    | grep -o 'REFERENCE' | head -n1 || true)"
fi

if [ "$mode" != "REFERENCE" ]; then
  echo "error: $FUNCTION_NAME is not in REFERENCE storage mode" >&2
  exit 1
fi

echo "$FUNCTION_NAME is in REFERENCE storage mode"
