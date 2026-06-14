#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# The Forge — Quick Update Script
# Updates only the frequently changing variables/secrets
# =============================================================================

REPO="SHreyank4Real/the-forge"
ENV_NAME="forge-k8s"

echo "============================================="
echo "  The Forge — Quick Variable Update"
echo "============================================="
echo ""

# Check gh
if ! gh auth status &> /dev/null 2>&1; then
    echo "❌ Not authenticated. Run: gh auth login"
    exit 1
fi

echo "📋 Enter the values to update (all required):"
echo ""

read -rp "AWS Access Key ID: " AWS_ACCESS_KEY
while [[ -z "$AWS_ACCESS_KEY" ]]; do
    read -rp "  ⚠️  Required — AWS Access Key ID: " AWS_ACCESS_KEY
done

read -rsp "AWS Secret Access Key (hidden): " AWS_SECRET_KEY
echo ""
while [[ -z "$AWS_SECRET_KEY" ]]; do
    read -rsp "  ⚠️  Required — AWS Secret Access Key (hidden): " AWS_SECRET_KEY
    echo ""
done

read -rp "S3 Bucket Name prefix: " BUCKET_NAME
while [[ -z "$BUCKET_NAME" ]]; do
    read -rp "  ⚠️  Required — S3 Bucket Name prefix: " BUCKET_NAME
done

read -rp "Cluster Name (FQDN): " CLUSTER_NAME
while [[ -z "$CLUSTER_NAME" ]]; do
    read -rp "  ⚠️  Required — Cluster Name (FQDN): " CLUSTER_NAME
done

read -rp "Route53 Hosted Zone ID: " HOSTED_ZONE_ID
while [[ -z "$HOSTED_ZONE_ID" ]]; do
    read -rp "  ⚠️  Required — Hosted Zone ID: " HOSTED_ZONE_ID
done

echo ""
echo "---------------------------------------------"
echo "  AWS Access Key:   ${AWS_ACCESS_KEY:0:8}..."
echo "  AWS Secret Key:   ****hidden****"
echo "  Bucket Name:      $BUCKET_NAME"
echo "  Cluster Name:     $CLUSTER_NAME"
echo "  Hosted Zone ID:   $HOSTED_ZONE_ID"
echo "---------------------------------------------"
echo ""

read -rp "🚀 Update these? (y/n) [y]: " CONFIRM
CONFIRM=${CONFIRM:-y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "📝 Updating..."

gh variable set AWS_ACCESS_KEY --repo "$REPO" --env "$ENV_NAME" --body "$AWS_ACCESS_KEY" && \
    echo "  ✅ AWS_ACCESS_KEY" || echo "  ❌ AWS_ACCESS_KEY"

gh secret set AWS_SEC_KEY --repo "$REPO" --env "$ENV_NAME" --body "$AWS_SECRET_KEY" && \
    echo "  ✅ AWS_SEC_KEY (secret)" || echo "  ❌ AWS_SEC_KEY"

gh variable set BUCKET_NAME --repo "$REPO" --env "$ENV_NAME" --body "$BUCKET_NAME" && \
    echo "  ✅ BUCKET_NAME" || echo "  ❌ BUCKET_NAME"

gh variable set CLUSTER_NAME --repo "$REPO" --env "$ENV_NAME" --body "$CLUSTER_NAME" && \
    echo "  ✅ CLUSTER_NAME" || echo "  ❌ CLUSTER_NAME"

gh variable set HOSTED_ZONE_ID --repo "$REPO" --env "$ENV_NAME" --body "$HOSTED_ZONE_ID" && \
    echo "  ✅ HOSTED_ZONE_ID" || echo "  ❌ HOSTED_ZONE_ID"

echo ""
echo "✅ Done! 4 variables + 1 secret updated."
echo ""
