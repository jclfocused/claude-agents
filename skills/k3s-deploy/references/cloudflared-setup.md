# cloudflared Tunnel Setup

Complete procedure for exposing a k8s service via Cloudflare Tunnel on the Hetzner server.

## Prerequisites

- `cloudflared` CLI installed locally (Mac: `brew install cloudflared`)
- Cloudflare account with the target domain
- SSH access to Hetzner server

## Step 1: Create the Tunnel

On your local machine:

```bash
# Login to Cloudflare (one-time)
cloudflared tunnel login

# Create the tunnel
cloudflared tunnel create <tunnel-name>
# Example: cloudflared tunnel create hyperglot-hetzner

# Output: Created tunnel <tunnel-name> with id <tunnel-id>
# Credentials file: ~/.cloudflared/<tunnel-id>.json
```

Note the tunnel ID — needed for the ConfigMap.

## Step 2: Add DNS Route

```bash
cloudflared tunnel route dns <tunnel-name> <hostname>
# Example: cloudflared tunnel route dns hyperglot-hetzner api.hyperglot.io

# This creates a CNAME: api.hyperglot.io → <tunnel-id>.cfargotunnel.com
```

## Step 3: Copy Credentials to Server

```bash
scp -P 48291 ~/.cloudflared/<tunnel-id>.json justin@46.4.220.172:~/tunnel-credentials.json
```

## Step 4: Create k8s Secret from Credentials

On the server (or via script):

```bash
#!/usr/bin/env bash
# create-cloudflared-secrets.sh
set -euo pipefail

NAMESPACE="my-namespace"
SECRET_NAME="cloudflared-tunnel-credentials"
CREDS_FILE="${1:?Usage: $0 <path-to-credentials.json>}"

[ ! -f "$CREDS_FILE" ] && echo "Error: File not found: $CREDS_FILE" && exit 1

TUNNEL_ID=$(jq -r '.TunnelID // .AccountTag' "$CREDS_FILE" 2>/dev/null || echo "unknown")
echo "Tunnel ID: $TUNNEL_ID"
echo "Update TUNNEL_ID in cloudflared ConfigMap with this value."

kubectl -n "$NAMESPACE" delete secret "$SECRET_NAME" 2>/dev/null || true
kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" \
    --from-file=credentials.json="$CREDS_FILE"

echo "Secret '${SECRET_NAME}' created."
```

## Step 5: Create k8s Manifests

### ConfigMap (ingress routing)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: my-namespace
data:
  config.yaml: |
    tunnel: <tunnel-id>
    credentials-file: /etc/cloudflared/credentials.json
    ingress:
      - hostname: api.example.com
        service: http://my-service.my-namespace.svc.cluster.local:3001
      - hostname: chat.example.com
        service: http://another-service.my-namespace.svc.cluster.local:8010
      - service: http_status:404
```

The last `- service: http_status:404` is the mandatory catch-all rule.

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: my-namespace
  labels:
    app: cloudflared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:2025.2.1  # Pin version!
          args:
            - tunnel
            - --config
            - /etc/cloudflared/config.yaml
            - run
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared/config.yaml
              subPath: config.yaml
              readOnly: true
            - name: credentials
              mountPath: /etc/cloudflared/credentials.json
              subPath: credentials.json
              readOnly: true
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
          livenessProbe:
            httpGet:
              path: /ready
              port: 2000
            initialDelaySeconds: 10
            periodSeconds: 30
      volumes:
        - name: config
          configMap:
            name: cloudflared-config
        - name: credentials
          secret:
            secretName: cloudflared-tunnel-credentials
```

## Step 6: Apply and Verify

```bash
kubectl apply -f cloudflared-deployment.yaml
kubectl -n my-namespace get pods -l app=cloudflared
kubectl -n my-namespace logs deploy/cloudflared --tail=20
# Look for "Connection registered" or "Registered tunnel connection"
```

Also verify in Cloudflare Dashboard → Networks → Tunnels → tunnel shows "Healthy".

## Adding More Hostnames

To route additional hostnames through the same tunnel:

1. Add DNS route: `cloudflared tunnel route dns <tunnel-name> <new-hostname>`
2. Update the ConfigMap ingress rules (add new `- hostname:` entry)
3. `kubectl apply -f cloudflared-deployment.yaml` (ConfigMap change triggers pod restart if using `kubectl rollout restart`)

## Troubleshooting

**Tunnel shows "Down" in dashboard:**
- Check pod logs: `kubectl -n <ns> logs deploy/cloudflared`
- Verify credentials secret exists: `kubectl -n <ns> get secret cloudflared-tunnel-credentials`
- Verify tunnel ID in ConfigMap matches the credentials file

**502 Bad Gateway:**
- The target service is unreachable from the cloudflared pod
- Check service exists: `kubectl -n <ns> get svc`
- Check service DNS: use full form `<svc>.<ns>.svc.cluster.local:<port>`
- Check target pod is ready: `kubectl -n <ns> get pods`

**DNS not resolving:**
- Verify CNAME exists: `dig api.example.com CNAME`
- Should return `<tunnel-id>.cfargotunnel.com`
