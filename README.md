# 🔥 The Forge

Automated Kubernetes cluster provisioning on AWS using [kOps](https://kops.sigs.k8s.io/) via GitHub Actions, with **ArgoCD** for GitOps and **Traefik** for ingress.

---

## What It Does

Two GitHub Actions workflows (`workflow_dispatch`):

### Forge K8s Cluster
1. Installs **kOps**, **kubectl**, and **AWS CLI** on the runner
2. Creates an IAM group/user (`kops`) with required AWS policies
3. Provisions an S3 state store bucket with versioning + encryption
4. Creates a **kOps Kubernetes cluster** with Calico networking
5. Validates the cluster and exports the kubeconfig
6. Uploads credentials + kubeconfig to a separate S3 bucket

### Install ArgoCD + Traefik
1. Downloads kubeconfig from S3
2. Installs **Traefik** with a reusable Let's Encrypt certificate resolver
3. Creates **Route53 DNS record** for ArgoCD
4. Installs **ArgoCD v3.4.3** from the vendored chart in `charts/argo-cd`
5. Passes TLS through Traefik so ArgoCD serves its native certificate
6. Outputs the initial admin password

---

## Repository Structure

```
the-forge/
├── .github/workflows/
│   ├── kops-create-cluster.yml    # Workflow 1 — creates the K8s cluster
│   └── install-argocd.yml         # Workflow 2 — installs Traefik + ArgoCD
├── manifests/
│   ├── traefik/
│   │   └── values.yaml            # Traefik values (ACME + TLS passthrough)
│   └── argocd/
│       ├── values.yaml            # ArgoCD Helm values (native TLS)
│       └── ingress-route.yaml     # Traefik TCP route for ArgoCD
├── charts/
│   ├── argo-cd/                   # Vendored ArgoCD Helm chart
│   └── traefik/                   # Vendored Traefik Helm chart
├── scripts/
│   ├── setup-gh-env.sh            # First-time setup — sets all 13 vars + 1 secret
│   └── update-vars.sh             # Quick update — changes only the 5 rotating values
├── .gitignore
└── README.md
```

---

## Download Helm Charts

The workflows install Helm charts only from the local `charts/` directory.
Download the pinned charts manually before committing chart updates:

```bash
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update

rm -rf charts/traefik charts/argo-cd

helm pull traefik/traefik \
  --version 40.3.0 \
  --untar \
  --untardir charts/

helm pull argo/argo-cd \
  --version 9.5.21 \
  --untar \
  --untardir charts/
```

Chart `argo-cd` version `9.5.21` installs ArgoCD `v3.4.3`.

---

## Quick Start

### 1. Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "kops@the-forge" -f ~/.ssh/kops_ed25519 -N ""
```

### 2. First-Time Setup

Run the interactive setup script to create the `forge-k8s` GitHub environment and set all variables:

```bash
./scripts/setup-gh-env.sh
```

This will prompt for all values and configure:
- **13 environment variables** (region, cluster sizing, networking, AWS creds, SSH key)
- **1 secret** (`AWS_SEC_KEY`)

### 3. Trigger the Workflow

```bash
# Via CLI
gh workflow run "Forge K8s cluster" --repo SHreyank4Real/the-forge

# Watch the run
gh run watch --repo SHreyank4Real/the-forge
```

Or go to **Actions** tab → **Forge K8s cluster** → **Run workflow**.

### 4. Install ArgoCD + Traefik

After the cluster is running:

```bash
# Via CLI
gh workflow run "Install ArgoCD + Traefik" \
  --repo SHreyank4Real/the-forge \
  -f acme_email="your-email@example.com"

# Watch the run
gh run watch --repo SHreyank4Real/the-forge
```

Once complete, access ArgoCD at: `https://argocd.<HOSTED_ZONE_ID>.realhandsonlabs.net`

**Architecture:**
```
Browser → HTTPS (ArgoCD certificate) → Traefik TCP passthrough (NLB) → ArgoCD Server (HTTPS)
```

ArgoCD uses a self-signed certificate by default, so browsers will show a
certificate warning until you configure a trusted certificate in ArgoCD.

---

## Application Certificates

Traefik's `letsencrypt` certificate resolver remains available for applications
deployed after ArgoCD. For example:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: example-app
  namespace: example
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.example.com`)
      kind: Rule
      services:
        - name: example-app
          port: 80
  tls:
    certResolver: letsencrypt
```

This setup uses Traefik ACME, so it does not require cert-manager or a
`ClusterIssuer`. ArgoCD separately uses TCP TLS passthrough.

---

## Updating Variables

When you rotate AWS credentials or change the cluster/bucket/zone, use the quick update script instead of re-running full setup:

```bash
./scripts/update-vars.sh
```

This only prompts for the **5 frequently changing values**:

| Variable | Type |
|----------|------|
| `AWS_ACCESS_KEY` | Variable |
| `AWS_SEC_KEY` | Secret |
| `BUCKET_NAME` | Variable |
| `CLUSTER_NAME` | Variable |
| `HOSTED_ZONE_ID` | Variable |

---

## Environment Variables Reference

All variables live in the **`forge-k8s`** GitHub environment.

### Variables (13)

| Variable | Description | Default |
|----------|-------------|---------|
| `REGION` | AWS region | `us-east-1` |
| `BUCKET_NAME` | S3 bucket prefix for kOps state store | `kops-state-store-*` |
| `CLUSTER_NAME` | Cluster FQDN | — |
| `MASTER_COUNT` | Control plane node count | `3` |
| `NODE_COUNT` | Worker node count | `4` |
| `NODE_SIZE` | Worker EC2 instance type | `t3a.medium` |
| `MASTER_SIZE` | Control plane EC2 instance type | `t3a.medium` |
| `VOL_SIZE` | EBS volume size (GB) | `100` |
| `SSH_PUBLIC_KEY` | Public key for SSH access to nodes | — |
| `VPC_CIDR` | VPC network CIDR | `10.0.0.0/16` |
| `HOSTED_ZONE_ID` | Route53 hosted zone ID | — |
| `AWS_ACCESS_KEY` | AWS access key ID (bootstrap user) | — |
| `CREDS_BUCKET_NAME` | S3 bucket prefix for storing generated creds | `the-forge-creds` |

### Secrets (1)

| Secret | Description |
|--------|-------------|
| `AWS_SEC_KEY` | AWS secret access key (bootstrap user) |

---

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) — installed and authenticated
- An AWS account with IAM permissions to create users, groups, S3 buckets, and EC2 instances
- A Route53 hosted zone for cluster DNS

---

## Security Notes

- **Never commit** AWS credentials, SSH private keys, or kubeconfigs — the `.gitignore` blocks them
- The workflow creates a dedicated `kops` IAM user with scoped policies
- Generated credentials and kubeconfig are uploaded to a **separate** S3 bucket, not the state store
