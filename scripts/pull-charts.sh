#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Pull/Update Helm Charts Locally
# Stores charts in the charts/ folder for version-controlled installs
# =============================================================================

CHARTS_DIR="$(cd "$(dirname "$0")/.." && pwd)/charts"

echo "============================================="
echo "  Pulling Helm Charts → charts/"
echo "============================================="
echo ""

mkdir -p "$CHARTS_DIR"

# --- Traefik ---
echo "📦 Pulling Traefik chart..."
helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
helm repo update traefik

# Remove old version before pulling new
rm -rf "$CHARTS_DIR/traefik"
helm pull traefik/traefik --untar --untardir "$CHARTS_DIR/"

TRAEFIK_VERSION=$(helm show chart "$CHARTS_DIR/traefik" | grep '^version:' | awk '{print $2}')
echo "  ✅ Traefik chart v${TRAEFIK_VERSION}"

# --- Summary ---
echo ""
echo "============================================="
echo "  ✅ Charts pulled to: $CHARTS_DIR"
echo "============================================="
echo ""
ls -1 "$CHARTS_DIR"
echo ""
echo "Next steps:"
echo "  git add charts/"
echo "  git commit -m 'chore: update helm charts'"
echo "  git push"
