# Networking

## Task 1

_Objective_: Create a service with IP whitelisting using NetworkPolicy.

Requirements:

- There is a deployment named `internal-api` in the `internal` namespace.
- The deployment uses the image `nginx:1.25`.
- The container exposes port 80.
- Create a service named `internal-api-svc` of type `ClusterIP` in the `internal` namespace.
- The service should expose port 8080 and target port 80.
- Create a NetworkPolicy named `allow-from-admin` that only allows ingress to the service from pods with the label `role: admin` in the same namespace.

**Predefined Resources:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: internal-api
  namespace: internal
spec:
  replicas: 2
  selector:
    matchLabels:
      app: internal-api
  template:
    metadata:
      labels:
        app: internal-api
    spec:
      containers:
      - name: api
        image: nginx:1.25
        ports:
        - containerPort: 80
```

<details><summary>help</summary>

Expose the deployment:

```bash
k expose -n internal deployment internal-api --name internal-api-svc --port 8080 --target-port 80
```

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-admin
  namespace: internal
spec:
  podSelector:
    matchLabels:
      app: internal-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: admin
    ports:
    - protocol: TCP
      port: 80
```

**Note:**
If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects the pods matching podSelector in the Namespaces selected by NamespaceSelector.
[_Otherwise it selects the pods matching podSelector in the policy's own namespace._](https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/#NetworkPolicySpec)

So you could also use (snippet):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
# ...
spec:
  # ...
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: admin
      namespaceSelector: # AND concatenated, so no extra '-' (list entry) at the beginning
        matchLabels:
          kubernetes.io/metadata.name: internal
    ports:
      # ...
```

</details>

## Task 2

_Objective_: Restrict pod communication using NetworkPolicy.

Requirements:

- Create a namespace `net-policy`.
- Deploy two pods: `frontend` (image: `nginx:1.25`) and `backend` (image: `hashicorp/http-echo:1.0`, args: `["-text=backend"]`, port 5678).
- Create a service `backend-svc` for the backend pod on port 8080.
- Create a NetworkPolicy named `deny-all` that denies all ingress to backend except from frontend.

<details><summary>help</summary>

Create the namespace:

```bash
k create ns net-policy
```

Create the frontend pod:

```bash
k run frontend --image nginx:1.25 -n net-policy
```

Create the backend pod template:

```bash
k run backend --image hashicorp/http-echo:1.0 -n net-policy --port 5678 --dry-run=client -o yaml > t2pod_backend.yaml
```

Edit the backend pod template and add the args (snippet):

```yaml
apiVersion: v1
kind: Pod
# ...
spec:
  containers:
  - image: hashicorp/http-echo:1.0
    name: backend
    args: ["-text=backend"]
    ports:
    - containerPort: 5678
    resources: {}
  # ...
```

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: net-policy
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 5678
```

</details>

## Task 3

_Objective_: Restrict pod access to a backend service to only pods with a specific label.

Requirements:

- There are two pods named `frontend` and `backend` in the `netpol-demo1` namespace.
- Create a NetworkPolicy named `allow-frontend` that only allows pods with label `role=frontend` to connect to the `backend` pod on port 80.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: netpol-demo1
  labels:
    app: backend
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: netpol-demo1
  labels:
    role: frontend
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "28800"]
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: netpol-demo1
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 80
```

</details>

## Task 4

_Objective_: Deny all ingress and egress traffic to a pod except DNS.

Requirements:

- There is a pod named `isolated` in the `netpol-demo2` namespace.
- Create a NetworkPolicy named `deny-all-except-dns` that denies all ingress and egress except egress to DNS (UDP port 53).

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: isolated
  namespace: netpol-demo2
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "28800"]
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-except-dns
  namespace: netpol-demo2
spec:
  podSelector: {} # select all pods
  policyTypes:
  - Ingress
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
```

</details>

## Task 5

_Objective_: Allow traffic to a pod only from a specific namespace.

Requirements:

- There is a pod named `api-server` in the `netpol-demo3` namespace.
- Create a NetworkPolicy named `allow-from-trusted-ns` that only allows ingress traffic to `api-server` from pods in the `trusted-ns` namespace.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: netpol-demo3
  labels:
    app: api-server
spec:
  containers:
  - name: httpd
    image: httpd:2.4
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-trusted-ns
  namespace: netpol-demo3
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: trusted-ns
```

</details>

## Task 6

_Objective_: Allow only HTTP (port 80) traffic to a pod from pods with a specific label in the same namespace.

Requirements:

- There are two pods named `web` and `client` in the `netpol-demo4` namespace.
- Create a NetworkPolicy named `http-only-from-client` that allows only pods with label `access=web` to access `web` on port 80.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: netpol-demo4
  labels:
    app: web
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: netpol-demo4
  labels:
    access: web
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: http-only-from-client
  namespace: netpol-demo4
spec:
  podSelector: # What can be accessed
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from: # From where can it be accessed
    - podSelector:
        matchLabels:
          access: web
    ports:
    - protocol: TCP
      port: 80
```

</details>

## Task 7

_Objective_: Allow egress traffic from a pod only to an external IP on a specific port.

Requirements:

- There is a pod named `egress-pod` in namespace `netpol-demo5`.
- Create a NetworkPolicy named `allow-egress-external` that allows egress from `egress-pod` only to IP `8.8.8.8` on TCP port 53.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: egress-pod
  namespace: netpol-demo5
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "3600"]
```

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-external
  namespace: netpol-demo5
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 8.8.8.8/32
    ports:
    - protocol: TCP
      port: 53
```

</details>

## Task 8

_Objective_: Allow all pods in a namespace to communicate with each other, but deny all ingress from other namespaces.

Requirements:

- There are two pods named `pod-a` and `pod-b` in namespace `netpol-demo6`.
- Create a NetworkPolicy named `internal-only` that allows all pods in `netpol-demo6` to communicate with each other, but denies all ingress from other namespaces.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-a
  namespace: netpol-demo6
  labels:
    app: pod-a
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-b
  namespace: netpol-demo6
  labels:
    app: pod-b
spec:
  containers:
  - name: nginx
    image: nginx:1.25
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: internal-only
  namespace: netpol-demo6
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
```

</details>

## Task 9

_Objective_: Allow ingress to a pod from a specific IP block only.

Requirements:

- There is a pod named `restricted-pod` in namespace `netpol-demo7`.
- Create a NetworkPolicy named `allow-specific-ipblock` that allows ingress to `restricted-pod` only from IP block `10.10.0.0/16`.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: netpol-demo7
  labels:
    app: restricted
spec:
  containers:
  - name: nginx
    image: nginx:1.25
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-specific-ipblock
  namespace: netpol-demo7
spec:
  podSelector:
    matchLabels:
      app: restricted
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 10.10.0.0/16
```

</details>

## Task 10

_Objective_: Allow ingress to a pod on multiple ports from different sources.

Requirements:

- There is a pod named `multi-port-pod` in namespace `netpol-demo8`.
- Create a NetworkPolicy named `allow-frontend-and-admin` that allows
- Allow ingress on port 80 from pods with label `role=frontend`.
- Allow ingress on port 443 from pods with label `role=admin`.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-port-pod
  namespace: netpol-demo8
  labels:
    app: multi-port
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - name: http
      containerPort: 80
      protocol: TCP
    - name: https
      containerPort: 443
      protocol: TCP
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: netpol-demo8
  labels:
    role: frontend
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: admin
  namespace: netpol-demo8
  labels:
    role: admin
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-and-admin
  namespace: netpol-demo8
spec:
  podSelector:
    matchLabels:
      app: multi-port
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 80
  - from:
    - podSelector:
        matchLabels:
          role: admin
    ports:
    - protocol: TCP
      port: 443
```

**Note:**
There are multiple pods in the namespace. Therefore we can't use an empty podSelector in this case.

</details>

## Task 11

_Objective_: Allow egress from a pod to another pod in a different namespace.

Requirements:

- There are two namespaces named `netpol-demo9` and `external-ns`.
- In namespace `netpol-demo9` is a pod named `source-pod`.
- In namespace `external-ns` is a pod named `target-pod`.
- Create a NetworkPolicy named `external-target` in `netpol-demo9` that allows egress from `source-pod` to `target-pod` on port 80.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: source-pod
  namespace: netpol-demo9
  labels:
    app: source
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: target-pod
  namespace: external-ns
  labels:
    app: target
spec:
  containers:
  - name: nginx
    image: nginx:1.25
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: external-target
  namespace: netpol-demo9
spec:
  podSelector:
    matchLabels:
      app: source
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: target
      namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: external-ns
    ports:
    - protocol: TCP
      port: 80
```

</details>

## Task 12

_Objective_: Deny all ingress and egress traffic to a pod.

Requirements:

- There is a pods named `locked-down` in the `netpol-demo10` namespace.
- Create a NetworkPolicy named `deny-all` that denies all ingress and egress to `locked-down`.

**Predefined Resources:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-demo10
---
apiVersion: v1
kind: Pod
metadata:
  name: locked-down
  namespace: netpol-demo10
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "3600"]
```

<details><summary>help</summary>

Create the networkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: netpol-demo10
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

or:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: netpol-demo10
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress: []
  egress: []
```

</details>
