# Services

## Task 1

_Objective_: Expose an existing deployment using a ClusterIP service.

Requirements:

- There is a deployment named `web-deploy` in the `default` namespace.
- The deployment uses the image `nginx:1.25`.
- Create a service named `web-svc` of type `ClusterIP`.
- The service should expose port 80 and target port 80 on the pods.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deploy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

<details><summary>help</summary>

Expose the deployment:

```bash
k expose deployment web-deploy --name web-svc
```

</details>

## Task 2

_Objective_: Create a NodePort service for an existing deployment.

Requirements:

- There is a deployment named `api-deploy` in the `dev` namespace.
- The deployment uses the image `httpd:2.4`.
- Create a service named `api-nodeport` of type NodePort.
- The service should expose port 8080 and target port 80 on the pods.
- The NodePort should be set to 30080.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deploy
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: httpd
        image: httpd:2.4
        ports:
        - containerPort: 80
```

<details><summary>help</summary>

Expose the deployment:

```bash
k expose deployment -n dev api-deploy --port 8080 --target-port 80 --type NodePort --name api-nodeport
```

Update the nodePort definition of the service:

```bash
k edit -n dev svc api-nodeport
```

```yaml
# ...
spec:
  ports:
  - nodePort: 30080
  # ...
```

</details>

## Task 3

_Objective_: Create a headless service for a StatefulSet.

Requirements:

- There is a StatefulSet named `db-set` in the `database` namespace.
- The StatefulSet uses the image `mongo:6.0`.
- Create a headless service named `db-headless`.
- The service should expose port 27017 and have no cluster IP.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-set
  namespace: database
spec:
  serviceName: "db-headless"
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: mongo
        image: mongo:6.0
        ports:
        - containerPort: 27017
```

<details><summary>help</summary>

Create the service:

```bash
k create svc clusterip db-headless --clusterip None --tcp 27017 -n database
```

Update the selector definition of the service:

```bash
k edit -n database svc db-headless
```

```yaml
# ...
spec:
  selector:
    app: db
# ...
```

</details>

## Task 4

_Objective_: Create an ExternalName service.

Requirements:

- Create a service named `external-svc` in the `default` namespace.
- The service should resolve to the external DNS name `example.com`.
- No selector or ports are required.

<details><summary>help</summary>

Create the service:

```bash
k create svc externalname external-svc --external-name example.com -n default
```

</details>

## Task 5

_Objective_: Expose a deployment with a service using custom labels and selectors.

Requirements:

- There is a deployment named `custom-app` in the `prod` namespace.
- The deployment uses the image `python:3.12-slim`.
- The pods have the label `tier: backend`.
- Create a service named `custom-svc` of type `ClusterIP`.
- The service should select pods with the label `tier: backend`.
- The service should expose port 9000 and target port 9000.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-app
  namespace: prod
spec:
  replicas: 2
  selector:
    matchLabels:
      tier: backend
  template:
    metadata:
      labels:
        tier: backend
    spec:
      containers:
      - name: app
        image: python:3.12-slim
        command: ["python", "-m", "http.server", "9000"]
        ports:
        - containerPort: 9000
```

<details><summary>help</summary>

Expose the deployment:

```bash
k expose -n prod deployment custom-app --name custom-svc
```

</details>

## Task 6

_Objective_: Create a service with multiple ports.

Requirements:

- There is a deployment named `multi-port-app` in the `default` namespace.
- The deployment uses the image `nginx:1.25`.
- The container exposes ports 80 and 443.
- Create a service named `multi-port-svc` of type `ClusterIP`.
- The service should expose ports 80 and 443, targeting the same ports on the pods.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multi-port
  template:
    metadata:
      labels:
        app: multi-port
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        - containerPort: 443
```

<details><summary>help</summary>

Expose the deployment:

```bash
k expose deployment multi-port-app --name multi-port-svc
```

</details>

## Task 7

_Objective_: Create a service with session affinity.

Requirements:

- There is a deployment named `session-app` in the `default` namespace.
- The deployment uses the image `nginx:1.25`.
- Create a service named `session-svc` of type `ClusterIP`.
- The service should expose port 9080 and target port 80.
- Enable session affinity based on client IP.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: session-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: session
  template:
    metadata:
      labels:
        app: session
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
```

<details><summary>help</summary>

Expose the deployment:

```bash
k expose deployment session-app --name session-svc --port 9080 --target-port 80 --session-affinity ClientIP
```

</details>

## Task 8

_Objective_: Create a LoadBalancer service with health check and annotations.

Requirements:

- There is a deployment named `payment-api` in the `finance` namespace
- The deployment uses the image `python:3.12-slim`
- The container exposes port 5000
- Create a service named `payment-lb` of type `LoadBalancer` in the `finance` namespace
- The service should expose port 443 and target port 5000
- Add the annotation `service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http`

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  namespace: finance
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment
  template:
    metadata:
      labels:
        app: payment
    spec:
      containers:
      - name: payment
        image: python:3.12-slim
        command: ["python", "-m", "http.server", "5000"]
        ports:
        - containerPort: 5000
        readinessProbe:
          httpGet:
            path: /
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
```

<details><summary>help</summary>

Expose the deployment:

```bash
k expose -n finance deployment payment-api --name payment-lb --type LoadBalancer --port 443 --target-port 5000
```

Annotate the service:

```bash
k annotate -n finance svc payment-lb service.beta.kubernetes.io/aws-load-balancer-backend-protocol=http
```

</details>

## Task 9

_Objective_: Create a service that only exposes a specific pod using a unique label.

Requirements:

- There is a deployment named `audit-logger` in the `security` namespace.
- The deployment uses the image `alpine:3.20`.
- One pod in the deployment has the label `role: main` (manually patched).
- Create a service named `audit-main-svc` of type `ClusterIP` in the `security` namespace.
- The service should only select pods with the label `role: main`.
- The service should expose port 7000 and target port 7000.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-logger
  namespace: security
spec:
  replicas: 2
  selector:
    matchLabels:
      app: audit
  template:
    metadata:
      labels:
        app: audit
    spec:
      containers:
      - name: logger
        image: alpine:3.20
        command: ["nc", "-lk", "-p", "7000"]
        ports:
        - containerPort: 7000
```

<details><summary>help</summary>

Expose the deployment:

```bash
k expose -n security deployment audit-logger --name audit-main-svc
```

Update the service selector:

```bash
k edit -n security svc audit-main-svc
```

```yaml
# ...
spec:
  selector:
    role: main
# ...
```

</details>

## Task 10

_Objective_: Test DNS resolution between pods.

Requirements:

- There is a pod named `api-server` in the `dns-test` namespace.
- Deploy a service named `dns-svc` (ClusterIP) for the `api-server` pod.
- Create a pod `api-test` (image: `busybox:1.36`, command: `sleep 28800`).
- From `api-test`, verify DNS resolution to `dns-svc`.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: dns-test
  labels:
    app: api-server
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
```

<details><summary>help</summary>

Expose the pod:

```bash
k expose -n dns-test po api-server --port 80 --name dns-svc
```

Create the pod template:

```bash
k run -n dns-test api-test --image busybox:1.36 --dry-run=client -o yaml > t10pod.yaml
```

Add the command to the pod template (snippet):

```yaml
apiVersion: v1
kind: Pod
# ...
spec:
  containers:
  - image: busybox:1.36
    name: api-test
    command: ["sleep", "28800"]
  # ...
```

Apply the template:

```bash
k apply -f t10pod.yaml
```

Execute the test:

```bash
k exec -n dns-test pods/api-test -it -- wget -O- dns-svc
# or
k exec -n dns-test pods/api-test -it -- wget -O- dns-svc.dns-test.svc.cluster.local
```

</details>
