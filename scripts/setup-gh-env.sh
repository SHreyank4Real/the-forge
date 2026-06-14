#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# The Forge — GitHub Environment Setup Script
# Creates the 'forge-k8s' environment, sets all variables and secrets
# =============================================================================

REPO="SHreyank4Real/the-forge"
ENV_NAME="forge-k8s"

echo "============================================="
echo "  The Forge — forge-k8s Environment Setup"
echo "============================================="
echo ""

# Check gh is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Install it first:"
    echo "   brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub CLI. Run:"
    echo "   gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"
echo ""

# --- Collect all values interactively ---
echo "📋 Enter your configuration values (press Enter for defaults shown in [brackets]):"
echo ""

read -rp "AWS Region [us-east-1]: " REGION
REGION=${REGION:-us-east-1}

read -rp "S3 Bucket Name prefix for kOps state [the-forge-kops-state]: " BUCKET_NAME
BUCKET_NAME=${BUCKET_NAME:-the-forge-kops-state}

read -rp "Cluster Name (FQDN, e.g. cluster.example.com): " CLUSTER_NAME
while [[ -z "$CLUSTER_NAME" ]]; do
    echo "  ⚠️  Cluster name is required!"
    read -rp "Cluster Name (FQDN, e.g. cluster.example.com): " CLUSTER_NAME
done

read -rp "Control Plane (master) count [1]: " MASTER_COUNT
MASTER_COUNT=${MASTER_COUNT:-1}

read -rp "Worker node count [2]: " NODE_COUNT
NODE_COUNT=${NODE_COUNT:-2}

read -rp "Worker node instance type [t3.medium]: " NODE_SIZE
NODE_SIZE=${NODE_SIZE:-t3.medium}

read -rp "Control Plane instance type [t3.medium]: " MASTER_SIZE
MASTER_SIZE=${MASTER_SIZE:-t3.medium}

read -rp "EBS Volume size in GB [20]: " VOL_SIZE
VOL_SIZE=${VOL_SIZE:-20}

read -rp "VPC CIDR block [10.0.0.0/16]: " VPC_CIDR
VPC_CIDR=${VPC_CIDR:-10.0.0.0/16}

read -rp "Route53 Hosted Zone ID: " HOSTED_ZONE_ID
while [[ -z "$HOSTED_ZONE_ID" ]]; do
    echo "  ⚠️  Hosted Zone ID is required!"
    read -rp "Route53 Hosted Zone ID: " HOSTED_ZONE_ID
done

read -rp "AWS Access Key ID: " AWS_ACCESS_KEY
while [[ -z "$AWS_ACCESS_KEY" ]]; do
    echo "  ⚠️  AWS Access Key is required!"
    read -rp "AWS Access Key ID: " AWS_ACCESS_KEY
done

read -rsp "AWS Secret Access Key (hidden): " AWS_SECRET_KEY
echo ""
while [[ -z "$AWS_SECRET_KEY" ]]; do
    echo "  ⚠️  AWS Secret Key is required!"
    read -rsp "AWS Secret Access Key (hidden): " AWS_SECRET_KEY
    echo ""
done

read -rp "Credentials S3 Bucket Name prefix [the-forge-creds]: " CREDS_BUCKET_NAME
CREDS_BUCKET_NAME=${CREDS_BUCKET_NAME:-the-forge-creds}

# SSH Public Key
SSH_KEY_PATH="$HOME/.ssh/kops_ed25519.pub"
read -rp "SSH Public Key file path [$SSH_KEY_PATH]: " SSH_KEY_INPUT
SSH_KEY_PATH=${SSH_KEY_INPUT:-$SSH_KEY_PATH}

if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo ""
    echo "⚠️  SSH key not found at $SSH_KEY_PATH"
    read -rp "Generate a new SSH key now? (y/n) [y]: " GEN_KEY
    GEN_KEY=${GEN_KEY:-y}
    if [[ "$GEN_KEY" =~ ^[Yy]$ ]]; then
        PRIVATE_KEY_PATH="${SSH_KEY_PATH%.pub}"
        ssh-keygen -t ed25519 -C "kops@the-forge" -f "$PRIVATE_KEY_PATH" -N ""
        echo "✅ SSH key generated:"
        echo "   Private: $PRIVATE_KEY_PATH"
        echo "   Public:  $SSH_KEY_PATH"
    else
        echo "❌ Cannot proceed without SSH public key. Exiting."
        exit 1
    fi
fi

SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")

# --- Show summary ---
echo ""
echo "============================================="
echo "  Configuration Summary"
echo "============================================="
echo "  Repo:            $REPO"
echo "  Environment:     $ENV_NAME"
echo "  Region:          $REGION"
echo "  Bucket Name:     $BUCKET_NAME"
echo "  Cluster Name:    $CLUSTER_NAME"
echo "  Master Count:    $MASTER_COUNT"
echo "  Node Count:      $NODE_COUNT"
echo "  Node Size:       $NODE_SIZE"
echo "  Master Size:     $MASTER_SIZE"
echo "  Volume Size:     $VOL_SIZE GB"
echo "  VPC CIDR:        $VPC_CIDR"
echo "  Hosted Zone ID:  $HOSTED_ZONE_ID"
echo "  AWS Access Key:  ${AWS_ACCESS_KEY:0:8}..."
echo "  AWS Secret Key:  ****hidden****"
echo "  Creds Bucket:    $CREDS_BUCKET_NAME"
echo "  SSH Key:         $SSH_KEY_PATH"
echo "============================================="
echo ""

read -rp "🚀 Proceed with setup? (y/n) [y]: " CONFIRM
CONFIRM=${CONFIRM:-y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# --- Create environment ---
echo ""
echo "📦 Creating environment '$ENV_NAME'..."
gh api --method PUT "repos/$REPO/environments/$ENV_NAME" --silent && \
    echo "✅ Environment '$ENV_NAME' created" || \
    echo "ℹ️  Environment may already exist"

# --- Set variables ---
echo ""
echo "📝 Setting variables..."

set_var() {
    local name="$1" value="$2"
    gh variable set "$name" --repo "$REPO" --env "$ENV_NAME" --body "$value" && \
        echo "  ✅ $name" || \
        echo "  ❌ Failed to set $name"
}

set_var "REGION" "$REGION"
set_var "BUCKET_NAME" "$BUCKET_NAME"
set_var "CLUSTER_NAME" "$CLUSTER_NAME"
set_var "MASTER_COUNT" "$MASTER_COUNT"
set_var "NODE_COUNT" "$NODE_COUNT"
set_var "NODE_SIZE" "$NODE_SIZE"
set_var "MASTER_SIZE" "$MASTER_SIZE"
set_var "VOL_SIZE" "$VOL_SIZE"
set_var "VPC_CIDR" "$VPC_CIDR"
set_var "HOSTED_ZONE_ID" "$HOSTED_ZONE_ID"
set_var "AWS_ACCESS_KEY" "$AWS_ACCESS_KEY"
set_var "CREDS_BUCKET_NAME" "$CREDS_BUCKET_NAME"
set_var "SSH_PUBLIC_KEY" "$SSH_PUBLIC_KEY"

# --- Set secret ---
echo ""
echo "🔐 Setting secret..."
gh secret set AWS_SEC_KEY --repo "$REPO" --env "$ENV_NAME" --body "$AWS_SECRET_KEY" && \
    echo "  ✅ AWS_SEC_KEY" || \
    echo "  ❌ Failed to set AWS_SEC_KEY"

# --- Done ---
echo ""
echo "============================================="
echo "  ✅ Setup Complete!"
echo "============================================="
echo ""
echo "  Variables set:  13"
echo "  Secrets set:    1"
echo "  Environment:    $ENV_NAME"
echo ""
echo "  Next steps:"
echo "    1. git add . && git commit -m 'feat: add kOps workflow'"
echo "    2. git push -u origin main"
echo "    3. gh workflow run 'Install Cluster in AWS' --repo $REPO"
echo ""
