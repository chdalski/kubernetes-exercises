# Persistent and Ephemeral Volumes

## Task 1

_Objective_: Create and use a PersistentVolume (PV) and PersistentVolumeClaim (PVC) to mount storage into a pod.

Requirements:

- Define a PersistentVolume (PV) named `data-pv` that provides 1Gi of storage.
- Use accessMode `ReadWriteOnce` to access the volume.
- Ensure the PV uses the `hostPath` storage type at the path `/mnt/data`.
- Create a PersistentVolumeClaim (PVC) named `data-pvc` that requests 500Mi of storage.
- Deploy a pod named `data-pod` with image `nginx:1.29.0`.
- Use the PVC to mount the storage at the path `/data` inside the pod's container.

<details><summary>help</summary>

Create and apply the resources:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-pv
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 1Gi
  hostPath:
    path: /mnt/data
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  volumeName: data-pv
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
spec:
  containers:
  - image: nginx:1.29.0
    name: data-pod
    volumeMounts:
    - name: data-vol
      mountPath: /data
  volumes:
  - name: data-vol
    persistentVolumeClaim:
      claimName: data-pvc
```

</details>

## Task 2

_Objective_: Configure an ephemeral volume using an emptyDir.

Requirements:

- Create pod named `init-cache` that uses an `emptyDir` volume.
- Mount the `emptyDir` volume with a init container at `/cache`.
- Create a file named `index.html` with content `hello cache` inside the directory.
- Create a container named `app` with the `nginx:1.29.0` image and mount the directory at `/usr/share/nginx/html`.
- Also mount the config map `app-config` to path `/etc/nginx/conf.d`.
- Exec `curl localhost` interactively in the nginx container at least once.

<details><summary>help</summary>

Create and apply the resources:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-cache
  namespace: default
spec:
  initContainers:
  - name: init
    image: alpine
    command:
    - sh
    - -c
    - echo "hello cache" > /cache/index.html
    volumeMounts:
    - name: empty-vol
      mountPath: /cache
  containers:
  - name: app
    image: nginx:1.29.0
    volumeMounts:
    - name: empty-vol
      mountPath: /usr/share/nginx/html
    - name: app-config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: empty-vol
    emptyDir: {}
  - name: app-config
    configMap:
      name: app-config
```

Exec the curl command:

```bash
k exec -it init-cache -- curl localhost
```

</details>

## Task 3

_Objective_: Set up a PersistentVolume with access mode restrictions.

Requirements:

- Define a PersistentVolume (PV) named `task3-pv` with the following properties:
  - Size: `2Gi`
  - Storage type: `hostPath` pointing to `/tmp/storage`
  - Access mode: Allow only `ReadWriteOnce`.
  - Set the reclaim policy to `Delete`
- Create a PersistentVolumeClaim (PVC) named `task3-pvc` that matches the PV and requests `1Gi` of storage.
- Create a Pod named `task3-app` and ensure that the storage is correctly mounted at `/app`.
  - Use the `nginx:1.29.0` image for the container.
  - Make sure the container runs the command `['/bin/bash', '-c', 'echo -n "$(nginx -v 2>&1)" >> /app/task3.txt']` exactly one time.
- Make sure the Pod has status `Completed`.
- Delete the Pod and PersistentVolumeClaim.

<details><summary>help</summary>

Create and apply the resources:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task3-pv
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 2Gi
  hostPath:
    path: /tmp/storage
  persistentVolumeReclaimPolicy: Delete
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task3-pvc
spec:
  storageClassName: standard
  volumeName: task3-pv
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: task3-app
spec:
  containers:
  - image: nginx:1.29.0
    name: task3-app
    volumeMounts:
    - name: app-vol
      mountPath: /app
    command: ['/bin/bash', '-c', 'echo -n "$(nginx -v 2>&1)" >> /app/task3.txt']
  volumes:
  - name: app-vol
    persistentVolumeClaim:
      claimName: task3-pvc
  restartPolicy: Never
```

Delete the Pod and PersistentVolumeClaim:

```bash
k delete po task3-app --force
k delete pvc task3-pvc --force
```

</details>

## Task 4

_Objective_: Use a ConfigMap-backed ephemeral volume.

Requirements:

- Create a pod named `app` with image `nginx:1.29.0` in namespace `config`.
- Mount the key `config` of ConfigMap `app-config` to `/etc/app/config.json`.
- Verify that the `config.json` file is present in the `/etc/app` directory inside the container.

<details><summary>help</summary>

Create and apply the resources:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: config
spec:
  containers:
  - image: nginx:1.29.0
    name: app
    volumeMounts:
    - name: cfg-vol
      mountPath: /etc/app
  volumes:
  - name: cfg-vol
    configMap:
      name: app-config
      items:
      - key: config
        path: config.json
```

Verify the file is mounted:

```bash
k exec -n config -it app -- cat /etc/app/config.json
```

</details>

## Task 5

_Objective_: Set up a Secret-backed ephemeral volume.

Requirements:

- Create a Pod named `app` in namespace `database` with image `redis:8.0.2`.
- Mount the Secret `db-credentials` as a volume and mounts it's values individual files at `/etc/credentials` inside the container.
- Verify that the Secret contents are available as individual files in `/etc/credentials` inside the container.

<details><summary>help</summary>

Create and apply the resources:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: database
spec:
  containers:
  - image: redis:8.0.2
    name: app
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/credentials
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: db-credentials
```

Verify the files are mounted:

```bash
k exec -n database -it app -- ls /etc/credentials
```

</details>

## Task 6

_Objective_: Define storage quotas for a namespace.

Requirements:

- Create a namespace named `storage-limited`.
- Apply a ResourceQuota to the namespace to restrict:
  - Total number of PersistentVolumeClaims to 2.
  - Total storage requests to 2Gi.
- Create a PersistentVolume `quota` with:
  - A capacity of 3Gi storage.
  - Type `local` and point to `/tmp/backend`.
  - An affinity to the `backend` node.
- Attempt to create PVCs in the namespace to test the quota enforcement.

<details><summary>help</summary>

Create the Namespace:

```bash
k create ns storage-limited
```

Create the ResourceQuota:

```bash
k create quota storage --hard requests.storage=2Gi,persistentvolumeclaims=2 -n storage-limited
```

Create and apply the PersistentVolume (example):

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: quota
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 3Gi
  local:
    path: /tmp/backend
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: tier
          operator: In
          values:
          - backend
```

Create and apply the PersistentVolumeClaims (example):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim1
  namespace: storage-limited
spec:
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  volumeName: quota
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim2
spec:
 # ...
```

</details>

## Task 7

_Objective_: Use subPath mounting within a PersistentVolume.

Requirements:

- Create a PersistentVolume and PersistentVolumeClaim as follows:
  - The PV backs storage using `hostPath` located at `/mnt/projects`.
  - The PVC requests 2Gi of storage.
- Deploy a pod with image `nginx` that mounts the PVC at `/projects`.
- Use a `subPath` to mount only the subdirectory `project1` inside `/projects`.
- Test that the container can write files in `/projects` under the `project1` subdirectory.

<details><summary>help</summary>

Create and apply the resources:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: t7vol
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 2Gi
  hostPath:
    path: /mnt/projects
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: t7claim
spec:
  accessModes:
  - ReadWriteMany
  volumeName: t7vol
  resources:
    requests:
      storage: 2Gi
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: t7pod
spec:
  containers:
  - image: nginx
    name: t7pod
    volumeMounts:
    - name: projects-vol
      mountPath: /projects
      subPath: project1
  volumes:
  - name: projects-vol
    persistentVolumeClaim:
      claimName: t7claim
```

Create a file in the directory:

```bash
k exec -it <podname> -- touch /projects/some.file
```

</details>
