# k8s Manifest Patterns

Complete examples from production deployments on the Hetzner k3s server.

## Deployment (Web Service)

From chatbot — includes HPA, security context, RollingUpdate.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-namespace
  labels:
    app: my-app
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
      containers:
        - name: my-app
          image: IMAGE_PLACEHOLDER
          imagePullPolicy: Never
          ports:
            - containerPort: 3001
          securityContext:
            allowPrivilegeEscalation: false
          envFrom:
            - secretRef:
                name: my-app-secrets
          env:
            - name: NODE_ENV
              value: "production"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "2000m"
              memory: "2Gi"
          readinessProbe:
            httpGet:
              path: /health
              port: 3001
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 3001
            initialDelaySeconds: 15
            periodSeconds: 30
            failureThreshold: 3
```

## Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: my-namespace
spec:
  selector:
    app: my-app
  ports:
    - port: 3001
      targetPort: 3001
```

## Headless Service (for sticky routing)

From chatbot — exposes individual pod IPs for nginx upstream discovery.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-headless
  namespace: my-namespace
spec:
  clusterIP: None
  selector:
    app: my-app
  ports:
    - port: 3001
      targetPort: 3001
```

## PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
  namespace: my-namespace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path  # k3s default
  resources:
    requests:
      storage: 2Gi
```

## Redis (Deployment + PVC + Service)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: my-namespace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: my-namespace
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          command: ["redis-server", "--appendonly", "yes"]
          ports:
            - containerPort: 6379
          volumeMounts:
            - name: redis-data
              mountPath: /data
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            exec:
              command: ["redis-cli", "ping"]
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            exec:
              command: ["redis-cli", "ping"]
            initialDelaySeconds: 5
            periodSeconds: 5
      volumes:
        - name: redis-data
          persistentVolumeClaim:
            claimName: redis-data
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: my-namespace
spec:
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
```

## RBAC (ServiceAccount + Role + RoleBinding)

From franklin — allows pods to create k8s Jobs.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: job-creator
  namespace: my-namespace
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: job-creator-role
  namespace: my-namespace
rules:
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["create", "get", "list", "watch", "delete"]
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: job-creator-binding
  namespace: my-namespace
subjects:
  - kind: ServiceAccount
    name: job-creator
    namespace: my-namespace
roleRef:
  kind: Role
  name: job-creator-role
  apiGroup: rbac.authorization.k8s.io
```

## CronJob

From franklin — runs periodic tasks.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: my-cron
  namespace: my-namespace
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: job-creator
          containers:
            - name: trigger
              image: IMAGE_PLACEHOLDER
              imagePullPolicy: Never
              command: ["node", "scripts/trigger.js"]
              envFrom:
                - secretRef:
                    name: my-app-secrets
              resources:
                requests:
                  cpu: "100m"
                  memory: "128Mi"
                limits:
                  cpu: "500m"
                  memory: "256Mi"
          restartPolicy: OnFailure
```

## HorizontalPodAutoscaler

From chatbot — memory-based scaling.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app
  namespace: my-namespace
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 120
```

## Secrets Template

```yaml
# secrets.yaml.template — NEVER commit with real values
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secrets
  namespace: my-namespace
type: Opaque
stringData:
  API_KEY: "<PLACEHOLDER>"
  DATABASE_URL: "<PLACEHOLDER>"
```

## Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
```

## GitHub Actions Deploy Workflow (Complete)

```yaml
name: Deploy to Hetzner

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
      - '!backend/**/*.md'
      - '!backend/.claude/**'

concurrency:
  group: deploy-my-app
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.HETZNER_HOST }}
          username: ${{ secrets.HETZNER_USER }}
          key: ${{ secrets.HETZNER_SSH_KEY }}
          port: ${{ secrets.HETZNER_SSH_PORT }}
          command_timeout: 10m
          script: |
            set -euo pipefail
            cd ~/code/my-project
            git fetch origin main
            git reset --hard origin/main
            bash path/to/deploy.sh
```
