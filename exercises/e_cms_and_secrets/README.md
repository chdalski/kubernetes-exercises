# Kubernetes CKAD Exam - Config Resources Tasks

## Task 1

_Objective_: Create a ConfigMap and mount it as environment variables in a Pod.

Requirements:

- Create a ConfigMap named `app-config` with the following key-value pairs:
  - `APP_MODE`: `production`
  - `APP_VERSION`: `1.0`
- Create a Pod named `app-pod` that uses the `nginx:1.29.0` image.
- Mount the values from the `app-config` ConfigMap as environment variables:
  - `APP_MODE` -> `APP_MODE`
  - `APP_VERSION` -> `APP_VERSION`
- Verify using logs or a shell in the Pod that the environment variables are correctly set.

<details><summary>help</summary>

Create the ConfigMap:

```bash
k create cm app-config --from-literal APP_MODE=production --from-literal APP_VERSION=1.0
```

Create and apply the pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - image: nginx:1.29.0
    name: app-pod
    envFrom:
    - configMapRef:
        name: app-config
```

Verify:

```bash
k exec app-pod -it -- env | grep APP_
```

</details>

## Task 2

_Objective_: Create a ConfigMap and use it to mount directories/files into a Pod.

Requirements:

- Create a ConfigMap named `html-config` with the following data:
  - `index.html`: `<h1>Welcome to Kubernetes</h1>`
  - `error.html`: `<h1>Error Page</h1>`
- Create a Pod named `web-pod` that uses the `nginx:1.29.0` image.
- Mount the ConfigMap as a volume at `/usr/share/nginx/html`.
- Check that the files `index.html` and `error.html` are available in the container under the mounted path.

<details><summary>help</summary>

Create the ConfigMap:

```bash
k create cm html-config --from-literal index.html='<h1>Welcome to Kubernetes</h1>' --from-literal error.html='<h1>Error Page</h1>'
```

Create and apply the pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
spec:
  containers:
  - image: nginx:1.29.0
    name: web-pod
    volumeMounts:
    - name: conf-vol
      mountPath: /usr/share/nginx/html
  volumes:
  - name: conf-vol
    configMap:
      name: html-config
```

Verify:

```shell
k exec -it web-pod -- ls /usr/share/nginx/html
```

</details>

## Task 3

_Objective_: Create a Secret and inject it as environment variables in a Pod.

Requirements:

- Create a Secret named `db-credentials` with the following key-value pairs (use base64 encoding as required):
  - `username`: `admin`
  - `password`: `SuperSecretPassword`
- Create a Pod named `db-pod` that uses the `nginx:1.29.0` image.
- Inject the `username` and `password` from the Secret `db-credentials` as environment variables.
- Verify via shell or logs that the environment variables are set correctly.

<details><summary>help</summary>

Create the Secret:

```bash
k create secret generic db-credentials --from-literal username=admin --from-literal password=SuperSecretPassword
```

Create and apply the pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
spec:
  containers:
  - image: nginx:1.29.0
    name: db-pod
    envFrom:
    - secretRef:
        name: db-credentials
```

Verify:

```bash
k exec -it db-pod -- env | grep username
k exec -it db-pod -- env | grep password
```

</details>

## Task 4

_Objective_: Use a Secret as a volume in a Pod.

Requirements:

- Create a Secret named `tls-secret` with the following key-value pairs (use base64 encoding as required):
  - `tls.crt`: use file `task4.crt`
  - `tls.key`: use file `task4.key`
- Create a Pod named `secure-pod` that uses the `redis:8.0.2` image.
- Mount the Secret `tls-secret` as a volume at `/etc/tls`.
- Verify inside the Pod that the files `tls.crt` and `tls.key` are available at the mounted path.

<details><summary>help</summary>

Create the Secret:

```bash
k create secret tls tls-secret --key ./task4.key --cert ./task4.crt
```

Create and apply the pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  containers:
  - image: redis:8.0.2
    name: secure-pod
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/tls
  volumes:
  - name: secret-vol
    secret:
      secretName: tls-secret
```

Verify:

```bash
k exec -it secure-pod -- ls /etc/tls
```

</details>

## Task 5

_Objective_: Use a specific environment variable name for a ConfigMap key.

Requirements:

- Create a ConfigMap named `message-config` with the initial key-value pair:
  - `message`: `Hello, Kubernetes`
- Create a Pod named `message-pod` that uses the `busybox:1.37.0` image with the command: `["sh", "-c", "while true; do echo \"$MESSAGE\"; sleep 5; done"]`.
- Mount the ConfigMap `message-config` as an environment variable `MESSAGE`.
- Verify if the Pod reflects the value in its logs.

<details><summary>help</summary>

Create the ConfigMap:

```bash
k create cm message-config --from-literal message='Hello, Kubernetes'
```

Create and apply the Pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: message-pod
spec:
  containers:
  - image: busybox:1.37.0
    name: message-pod
    command: ["sh", "-c", "while true; do echo \"$MESSAGE\"; sleep 5; done"]
    env:
    - name: MESSAGE
      valueFrom:
        configMapKeyRef:
          name: message-config
          key: message
```

Verify:

```bash
k logs message-pod
```

</details>

## Task 6

_Objective_: Create and use multiple ConfigMaps and Secrets.

Requirements:

- Create two ConfigMaps:
  - `frontend-config`:
    - `TITLE`: `Frontend`
  - `backend-config`:
    - `ENDPOINT`: `http://backend.local`
- Create one Secret:
  - `api-secret`:
    - `API_KEY`: `12345`
- Create a Pod named `complex-pod` that uses the `nginx:1.29.0` image.
- Mount the values from:
  - `frontend-config` as environment variables `TITLE`.
  - `backend-config` as environment variables `ENDPOINT`.
  - `api-secret` as an environment variable `API_KEY`.
- Verify the Pod has all environment variables set as expected.

<details><summary>help</summary>

Create the ConfigMaps:

```bash
k create cm frontend-config --from-literal TITLE=Frontend
k create cm backend-config --from-literal ENDPOINT='http://backend.local'
```

Create the Secret:

```bash
k create secret generic api-secret --from-literal API_KEY=12345
```

Create and apply the Pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: complex-pod
spec:
  containers:
  - image: nginx:1.29.0
    name: complex-pod
    envFrom:
    - configMapRef:
        name: frontend-config
    - configMapRef:
        name: backend-config
    - secretRef:
        name: api-secret
```

Verify:

```bash
k exec -it complex-pod -- env | grep TITLE
k exec -it complex-pod -- env | grep ENDPOINT
k exec -it complex-pod -- env | grep API_KEY
```

</details>

## Task 7

_Objective_: Use ConfigMap and Secret together as volumes.

Requirements:

- All resources must be created in the `volume` namespace.
- Create a ConfigMap named `app-config` with the following data:
  - `config.yml`: "application: setting1"
- Create a Secret named `app-secret` with the following data (use base64 as required):
  - `password`: "awesome_and_secure"
- Create a Pod named `volume-pod` that uses the `redis:8.0.2` image.
- Mount `app-config` as a volume at `/etc/config`.
- Mount `app-secret` as a volume at `/etc/secret`.
- Verify the contents of the mounted files.

<details><summary>help</summary>

Create the ConfigMap:

```bash
k create -n volume cm app-config --from-literal config.yml='application: setting1'
```

Create the Secret:

```bash
k create -n volume secret generic app-secret --from-literal password=awesome_and_secure
```

Create and apply the Pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-pod
  namespace: volume
spec:
  containers:
  - image: redis:8.0.2
    name: volume-pod
    volumeMounts:
    - name: app-config
      mountPath: /etc/config
    - name: app-secret
      mountPath: /etc/secret
  volumes:
  - name: app-config
    configMap:
      name: app-config
  - name: app-secret
    secret:
      secretName: app-secret
```

Verify:

```bash
k exec -n volume pods/volume-pod -- cat /etc/config/config.yml
k exec -n volume pods/volume-pod -- cat /etc/secret/password
```

</details>

Create a script in the same manner for the following task:

## Task 8

_Objective_: Create ConfigMaps and Secrets using files.

Requirements:

- All resources must be created in the `files` namespace.
- Create a ConfigMap named `config-env` from the key-value pairs in the file `t8config.env`.
- Create a ConfigMap named `config-file` from the file `t8config.database`.
- Create a Secret named `secret-env` from the key-value pairs in the file `t8secret.env`.
- Create a Secret named `secret-file` from the file `t8secret.database`.
- Create a Pod named `app-pod` with the image `httpd:2.4` that.
  - Sets the following environment variables in the container:
    - `APP_ENV` from the `environment` key in ConfigMap `config-env`.
    - `APP_TITLE` from the `title` key in ConfigMap `config-env`.
    - `APP_USER` from the `user` key in Secret `secret-env`.
    - `APP_PASSWORD` from the `password` key in Secret `secret-env`.
  - Mount the key `t8config.database` from ConfigMap `config-file` as the file `/etc/database/config.properties` in the container.
  - Mount the key `t8secret.database` from Secret `secret-file` as the file `/etc/database/secret.properties` in the container.
- Verify that the environment variables are set and the files are mounted as specified.

<details><summary>help</summary>

Create the ConfigMap resources:

```bash
k create -n files cm config-env --from-env-file ./t8config.env
k create -n files cm config-file --from-file ./t8config.database
```

Create the Secret resources:

```bash
k create -n files secret generic secret-env --from-env-file ./t8secret.env
k create -n files secret generic secret-file --from-file ./t8secret.database
```

Create and apply the Pod resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: files
spec:
  containers:
  - image: httpd:2.4
    name: app-pod
    env:
    - name: APP_ENV
      valueFrom:
        configMapKeyRef:
          name: config-env
          key: environment
    - name: APP_TITLE
      valueFrom:
        configMapKeyRef:
          name: config-env
          key: title
    - name: APP_USER
      valueFrom:
        secretKeyRef:
          name: secret-env
          key: user
    - name: APP_PASSWORD
      valueFrom:
        secretKeyRef:
          name: secret-env
          key: password
    volumeMounts:
    - name: config-file
      mountPath: /etc/database/config.properties
      subPath: t8config.database
    - name: secret-file
      mountPath: /etc/database/secret.properties
      subPath: t8secret.database
  volumes:
  - name: config-file
    configMap:
      name: config-file
  - name: secret-file
    secret:
      secretName: secret-file
```

Verify:

```bash
k exec -n files -it app-pod -- env | grep APP_
k exec -n files -it app-pod -- cat /etc/database/config.properties
k exec -n files -it app-pod -- cat /etc/database/secret.properties
```

</details>

## Task 9

_Objective_: Create an immutable ConfigMap.

Requirements:

- Create a ConfigMap named `immutable-config` with the following key-value pair:
  - `APP_ENV`: `staging`
- Make the ConfigMap immutable.

_Optionally_:

- Attempt to edit the ConfigMap.

<details><summary>help</summary>

Create the ConfigMap resource:

```bash
k create cm immutable-config --from-literal APP_ENV=staging --dry-run=client -o yaml > t9cm.yaml
```

Mark it as immutable:

```bash
echo "immutable: true" >> t9cm.yaml
```

Apply it:

```bash
k apply -f t9cm.yaml
```

<details>
