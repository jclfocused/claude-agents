---
name: k3s-deploy
description: Deploy applications to the Hetzner k3s server. This skill should be used when deploying to k3s, creating k8s manifests, setting up cloudflared tunnels, writing deploy scripts, creating GitHub Actions deploy workflows, managing k8s secrets, or writing rollback scripts. Triggers on "deploy to hetzner", "k3s", "k8s manifest", "cloudflared", "deploy script", "rollback script".
---

# Deploying to Hetzner k3s

Procedural knowledge for deploying applications to the shared Hetzner dedicated server running k3s. All patterns are proven in production across multiple projects (franklin-data-pipeline, chatbot, hyperglot).

## Server Reference

- **IP:** 46.4.220.172
- **SSH:** `ssh -p 48291 justin@46.4.220.172`
- **OS:** Ubuntu 24.04 LTS
- **Specs:** 32-core Ryzen 9 7950, 128GB RAM, 1.8TB NVMe
- **Orchestration:** k3s (Traefik + servicelb disabled)
- **Firewall:** UFW — 48291/SSH, 6443/k3s, 10250/kubelet only. No HTTP/HTTPS ports — use cloudflared tunnels.
- **Docker:** Installed for native image builds on server
- **Users:** `justin` (SSH key, no password), `root`

## Core Patterns

### 1. Docker Images: Build on Server, Import to k3s

Never use a container registry. Build natively on the Ryzen 9 (fast), import directly into k3s containerd. Tag with git SHA for rollback.

```bash
SHA=$(git rev-parse --short HEAD)
IMAGE="my-app:${SHA}"
docker build -t "${IMAGE}" ./path/
docker save "${IMAGE}" | sudo k3s ctr images import -
kubectl set image deployment/my-app my-app="docker.io/library/${IMAGE}" -n my-namespace
```

All deployments use `imagePullPolicy: Never`.

### 2. Deployments: kubectl set image (Not rollout restart)

Always use `kubectl set image` — it records which SHA is deployed and enables targeted rollback. Never use `rollout restart` (it just restarts the same image).

### 3. cloudflared Tunnels (Not Open Ports)

Expose services via Cloudflare Tunnels. No HTTP/HTTPS ports on the server.

Pattern: ConfigMap for ingress config + Secret for credentials file.

```yaml
# ConfigMap
data:
  config.yaml: |
    tunnel: <tunnel-id>
    credentials-file: /etc/cloudflared/credentials.json
    ingress:
      - hostname: api.example.com
        service: http://my-service.my-namespace.svc.cluster.local:3001
      - service: http_status:404
```

Pin cloudflared version (e.g., `cloudflare/cloudflared:2025.2.1`), never use `latest`.

Setup flow:
1. `cloudflared tunnel create <name>` (locally)
2. `cloudflared tunnel route dns <name> <hostname>`
3. Copy credentials.json to server
4. Create k8s secret from credentials file
5. Apply ConfigMap + Deployment

### 4. GitHub Actions: SSH Deploy via appleboy

All projects use `appleboy/ssh-action@v1` to SSH into the server, pull code, build, and deploy.

```yaml
on:
  push:
    branches: [main]  # or develop
    paths:
      - 'backend/**'
      - '!backend/**/*.md'

concurrency:
  group: deploy-my-app
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.HETZNER_HOST }}
          username: ${{ secrets.HETZNER_USER }}
          key: ${{ secrets.HETZNER_SSH_KEY }}
          port: ${{ secrets.HETZNER_SSH_PORT }}
          command_timeout: 10m
          script: |
            cd ~/code/my-project
            git fetch origin main && git reset --hard origin/main
            bash path/to/deploy.sh
```

Required GitHub secrets: `HETZNER_HOST` (46.4.220.172), `HETZNER_USER` (justin), `HETZNER_SSH_KEY` (private key), `HETZNER_SSH_PORT` (48291).

### 5. Secrets Management

Use interactive `create-secrets.sh` scripts that prompt for values with hidden input. Never store secrets in git. Template files use `<PLACEHOLDER>` values.

```bash
# Pattern: prompt, skip if env var set
read_secret() {
    local var_name="$1"
    local current_val="${!var_name:-}"
    if [ -n "$current_val" ]; then return; fi
    read -s -p "  ${var_name}: " val; echo
    [ -n "$val" ] && export "$var_name"="$val"
}
```

Create with: `kubectl -n <ns> create secret generic <name> --from-literal=KEY=value`

### 6. Security Context (Non-Root Containers)

All deployments run as non-root (UID 1001):

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
  containers:
    - securityContext:
        allowPrivilegeEscalation: false
```

Dockerfile must create the user:
```dockerfile
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser && \
    chown -R appuser:appgroup /app
USER appuser
```

### 7. Deploy Scripts

Standard deploy script pattern: build, import, set image, wait, cleanup.

```bash
#!/usr/bin/env bash
set -euo pipefail
NAMESPACE="my-namespace"
IMAGE_NAME="my-app"
DEPLOYMENT="my-app"
CONTAINER="my-app"
SHA=$(git rev-parse --short HEAD)
IMAGE="${IMAGE_NAME}:${SHA}"

docker build -t "${IMAGE}" ./path/
docker save "${IMAGE}" | sudo k3s ctr images import -
kubectl set image "deployment/${DEPLOYMENT}" "${CONTAINER}=docker.io/library/${IMAGE}" -n "${NAMESPACE}"
kubectl -n "${NAMESPACE}" rollout status "deployment/${DEPLOYMENT}" --timeout=120s

# Keep last 10 images for rollback
docker images "${IMAGE_NAME}" --format '{{.Tag}} {{.ID}}' | tail -n +11 | awk '{print $2}' | xargs -r docker rmi 2>/dev/null || true
docker image prune -f 2>/dev/null || true
```

### 8. Rollback Scripts

List available versions or rollback to a specific SHA:

```bash
#!/usr/bin/env bash
set -euo pipefail
if [ -z "${1:-}" ]; then
    echo "Available versions:"; docker images "my-app" --format '{{.Tag}}\t{{.CreatedAt}}' | head -10; exit 0
fi
SHA="$1"; IMAGE="my-app:${SHA}"
docker save "${IMAGE}" | sudo k3s ctr images import -
kubectl set image deployment/my-app my-app="docker.io/library/${IMAGE}" -n my-namespace
kubectl -n my-namespace rollout status deployment/my-app --timeout=120s
```

### 9. k8s Manifest Conventions

- `storageClassName: local-path` (k3s default provisioner)
- RollingUpdate with `maxUnavailable: 0, maxSurge: 1` (zero-downtime)
- Readiness + liveness probes on all deployments
- Resource requests AND limits on all containers
- All resources in project-specific namespace (never default)

## Existing Namespaces on Server

| Namespace | Project | Workloads |
|-----------|---------|-----------|
| `hyperglot` | hyperglot + hyperglot-book-reader | backend API, Redis, page-scheduler, cloudflared |
| `franklin` | franklin-data-pipeline + chatbot | pipeline-orchestrator, chatbot, nginx-sticky, cloudflared, Redis |

## Additional Resources

For detailed k8s manifest examples, cloudflared setup scripts, and GHA workflow patterns, see:
- **[references/manifest-patterns.md](references/manifest-patterns.md)** — Complete k8s manifest examples (Deployment, Service, PVC, RBAC, CronJob, HPA)
- **[references/cloudflared-setup.md](references/cloudflared-setup.md)** — Full cloudflared tunnel setup procedure and scripts
