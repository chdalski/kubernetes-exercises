# ReplicaSets

## Task 1

_Objective_: Create a ReplicaSet named "web-rs" to manage 3 replicas of an NGINX web server.

Requirements:

- Create a ReplicaSet named `web-rs` in the `default` namespace.
- The ReplicaSet should maintain 3 replicas.
- Use the image `nginx:1.25`.
- The pods should be labeled with `app=web`.
- Expose port 80 in the pod specification.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-rs
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
```

</details>

## Task 2

_Objective_: Deploy a ReplicaSet named "api-backend" with a custom label and a specific image version.

Requirements:

- Create a ReplicaSet named `api-backend` in the `affinity` namespace.
- The ReplicaSet should maintain 2 replicas.
- Use the image `nginx:1.29`.
- The pods should be labeled with `tier=backend` and `env=prod`.
- Pods should preferably run on nodes where there are already pods with the label `service=cache-server`.
- Expose port 8080 in the pod specification.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: api-backend
  namespace: affinity
spec:
  replicas: 2
  selector:
    matchLabels:
      tier: backend
      env: prod
  template:
    metadata:
      labels:
        tier: backend
        env: prod
    spec:
      containers:
      - name: api
        image: nginx:1.29
        ports:
        - containerPort: 8080
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: service
                  operator: In
                  values:
                  - cache-server
              topologyKey: kubernetes.io/hostname
```

</details>

## Task 3

_Objective_: Create a ReplicaSet named "redis-cache" with a custom selector.

Requirements:

- Create a ReplicaSet named `redis-cache` in the `default` namespace.
- The ReplicaSet should maintain 4 replicas.
- Use the image `redis:7.2-alpine`.
- The ReplicaSet selector should match pods with the label `role=cache`.
- The pods should be labeled with `role=cache` and `component=redis`.
- Expose port 6379 in the pod specification.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: redis-cache
  namespace: default
spec:
  replicas: 4
  selector:
    matchLabels:
      role: cache
  template:
    metadata:
      labels:
        role: cache
        component: redis
    spec:
      containers:
      - name: redis
        image: redis:7.2-alpine
        ports:
        - containerPort: 6379
```

</details>

## Task 4

_Objective_: Deploy a ReplicaSet named "frontend-rs" with resource limits.

Requirements:

- Create a ReplicaSet named `frontend-rs` in the `default` namespace.
- The ReplicaSet should maintain 2 replicas.
- Use the image `httpd:2.4`.
- The pods should be labeled with `app=frontend`.
- Set CPU limit to `200m` and memory limit to `256Mi` for each pod.
- Expose port 3000 in the pod specification.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend-rs
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: httpd
        image: httpd:2.4
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
        ports:
        - containerPort: 3000
```

</details>

## Task 5

_Objective_: Create a ReplicaSet named "logger-rs" with environment variables.

Requirements:

- Create a namespace named `logger`.
- Create a ReplicaSet named `logger-rs` in the `logger` namespace.
- The ReplicaSet should maintain 1 replica.
- Use the image `busybox:1.36`.
- The pods should be labeled with `app=logger`.
- Set an environment variable `LOG_LEVEL=debug` in the pod.
- The pod should run the command `["sleep", "28800"]`.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: logger-rs
  namespace: logger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logger
  template:
    metadata:
      labels:
        app: logger
    spec:
      containers:
      - name: busybox
        image: busybox:1.36
        env:
        - name: LOG_LEVEL
          value: debug
        command: ["sleep", "28800"]
```

</details>

## Task 6

_Objective_: Create a ReplicaSet named "worker-rs" with node affinity.

Requirements:

- Create a ReplicaSet named `worker-rs` in the `default` namespace.
- The ReplicaSet should maintain 3 replicas.
- Use the image `alpine:3.20`.
- The pods should be labeled with `role=worker`.
- Add a node affinity rule to schedule pods only on nodes with the label `disk=ssd`.
- The pod should run the command `["sh", "-c", "echo Hello from worker; sleep 28800"]`.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: worker-rs
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      role: worker
  template:
    metadata:
      labels:
        role: worker
    spec:
      containers:
      - name: alpine
        image: alpine:3.20
        command: ["sh", "-c", "echo Hello from worker; sleep 28800"]
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: disk
                operator: In
                values:
                - ssd
```

</details>

## Task 7

_Objective_: Deploy a ReplicaSet named "db-rs" with a readiness probe.

Requirements:

- Create a ReplicaSet named `db-rs` in the `default` namespace.
- The ReplicaSet should maintain 2 replicas.
- Use the image `postgres:16.3`.
- The pods should be labeled with `app=database`.
- Add a readiness probe that checks TCP socket on port 5432.
- Expose port 5432 in the pod specification.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: db-rs
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:16.3
        readinessProbe:
          tcpSocket:
            port: 5432
        ports:
        - containerPort: 5432
```

</details>

## Task 8

_Objective_: Create a ReplicaSet named "job-runner" with a custom restart policy.

Requirements:

- Create a ReplicaSet named `job-runner` in the `default` namespace.
- The ReplicaSet should maintain 2 replicas.
- Use the image `python:3.12-slim`.
- The pods should be labeled with `app=job`.
- The pod should run the command `["python", "-m", "http.server", "8000"]`.
- Set the restart policy to `Always`.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: job-runner
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: job
  template:
    metadata:
      labels:
        app: job
    spec:
      containers:
      - name: app
        image: python:3.12-slim
        command: ["python", "-m", "http.server", "8000"]
      restartPolicy: Always
```

</details>

## Task 9

_Objective_: Deploy a ReplicaSet named "static-files" with a volume mount.

Requirements:

- Create a ReplicaSet named `static-files` in the `default` namespace.
- The ReplicaSet should maintain 2 replicas.
- Use the image `nginx:1.25`.
- The pods should be labeled with `app=static`.
- Mount an emptyDir volume at `/usr/share/nginx/html`.
- Expose port 80 in the pod specification.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: static-files
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: static
  template:
    metadata:
      labels:
        app: static
    spec:
      containers:
      - name: app
        image: nginx:1.25
        volumeMounts:
        - name: empty-vol
          mountPath: /usr/share/nginx/html
        ports:
        - containerPort: 80
      volumes:
      - name: empty-vol
        emptyDir: {}
```

</details>
