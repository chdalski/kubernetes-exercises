# Pods

## Task 1

Create a pod called `nginx` in namespace `task1` using the `nginx:1.21` image.

_Optionally:_ verify that the pod is running.

<details><summary>help</summary>

```bash
k run nginx --image=nginx:1.21 --restart=Never -n task1
```

</details>

## Task 2

Create a pod called `nginx` in namespace `task2` using the `nginx:1.21` image.
Use port `80` and `expose` the container.
Also add the label `exposed` with value `true`.

<details><summary>help</summary>

```bash
k run nginx --image nginx:1.21 --restart=Never -n task2 --port 80 --expose --labels=exposed=true
```

</details>

## Task 3

Run a container called `busybox` with the command `env`.
Use the `busybox:1.37.0` image and automatically delete the pod after executing.
Save the output to a file called `busybox-env.txt`.

<details><summary>help</summary>

```bash
k run busybox --image busybox:1.37.0 -it --rm --restart Never --command -- env > busybox-env.txt
```

</details>

## Task 4

Create a pod named `envpod` with a container named `ckadenv`, image `nginx` and an environment variable called `CKAD` with value `task4`.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: envpod
spec:
  containers:
  - name: ckadenv
    image: nginx
    env:
    - name: CKAD
      value: task4
```

</details>

## Task 5

Create a pod `task5-app` with a named container `busybox`, image `busybox` and load the environment variables from a config map called `app-config`.
Also make sure the container always restarts and configure it to run the command `["/bin/sh", "-c", "sleep 7200"]`.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: task5-app
spec:
  containers:
  - name: busybox
    image: busybox
    envFrom:
    - configMapRef:
        name: app-config
    command: ["/bin/sh", "-c", "sleep 7200"]
  restartPolicy: Always
```

</details>

## Task 6

Create a pod called `nginx-init` in namespace `task6`.

Define a init container named `busy-init` with image `busybox:1.37.0` and command `["/bin/sh", "-c", "echo 'hello ckad' > /data/index.html]`.
Also mount an `emptyDir` volume called `shared` on path `/data`.

Define a container named `nginx` with image `nginx:1.21` and mount the shared volume on path `/usr/share/nginx/html`.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-init
  namespace: task6
spec:
  initContainers:
  - name: busy-init
    image: busybox:1.37.0
    volumeMounts:
    - name: shared
      mountPath: /data
    command: ["/bin/sh", "-c", "echo 'hello ckad' > /data/index.html"]
  containers:
  - name: nginx
    image: nginx:1.21
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  volumes:
  - name: shared
    emptyDir: {}
```

</details>

## Task 7

Create a multi-container pod called `log-processor` in the `default` namespace, which contains two containers.

An application container called `app`, using the `alpine` image.
It should log the current date to the file `/var/log/app.log` every 10 seconds.

A sidecar container called `log-forwarder`, using a `busybox:1.34` image.
The sidecar container should continuously run the command to tail the log file: `tail -F /var/log/app.log`.

Make sure the directory `/var/log` is persistent between containers using an `emptyDir` volume.

<details><summary>help</summary>

__Note:__
sidecar containers are implemented as init containers with restart policy set to "Always", see the [docs](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/#sidecar-containers-and-pod-lifecycle) for more details.

Create the resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: log-processor
  namespace: default
spec:
  volumes:
  - name: logs
    emptyDir: {}
  containers:
  - name: app
    image: alpine
    command:
    - /bin/sh
    - -c
    - while true; do echo "$(date)" >> /var/log/app.log; sleep 10; done;
    volumeMounts:
    - name: logs
      mountPath: /var/log
  initContainers:
  - name: log-forwarder
    image: busybox:1.34
    command:
    - /bin/sh
    - -c
    - tail -F /var/log/app.log
    volumeMounts:
    - name: logs
      mountPath: /var/log
    restartPolicy: Always
```

</details>

## Task 8

In namespace `task8` is a pod called `liveness-exec`.
The pod restarts because of a wrong liveness probe.
Fix the liveness probe and redeploy the container.

<details><summary>help</summary>

Extract the yaml definition of the pod to a file.

```bash
k get -n task8 pod liveness-exec -o yaml > t8pod.yaml
```

Delete the current pod from the cluster.

```bash
k delete -f t8pod.yaml --force
```

The liveness probe fails because of the pod command `rm -rf /tmp/healthy; sleep 15; touch /tmp/healthy; sleep 7200`.
The script sleeps for 15 seconds before the file `/tmp/healthy` is created.
Therefore the liveness probe fails.

Update the liveness probe in the yaml file (snippet):

```yaml
# ...
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      failureThreshold: 1
      initialDelaySeconds: 15 # example solution
      periodSeconds: 5
      successThreshold: 1
      timeoutSeconds: 1
# ...
```

__Note:__
There a multiple ways to fix the probe.

- you could increase the failure threshold
- you could increase the initial delay
- you could increase the period
- or a mix of these

Redeploy the pod.

```shell
k apply -f t8pod.yaml
```

</details>

## Task 9

Create a pod called `nginx-health` with image `nginx:1.21`.
Mount all files of the config map `nginx-health` to path `/etc/nginx/conf.d`.
Also create a readiness probe to check path `/healthz` on port `80` after an initial delay of `3` seconds.
The probe should be run every `5` seconds.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-health
spec:
  containers:
  - image: nginx:1.21
    name: nginx-health
    volumeMounts:
    - name: config-vol
      mountPath: "/etc/nginx/conf.d"
    readinessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 5
  dnsPolicy: ClusterFirst
  volumes:
  - name: config-vol
    configMap:
      name: nginx-health
```

</details>

## Task 10

In namespace `task10` is a failed pod.
Identify and fix the issue without deleting the pod.

<details><summary>help</summary>

The pod fails because of a typo in the image tag.
Update the tag in place using the `kubectl edit` command.

```bash
k edit -n task10 po help-me
```

</details>

## Task 11

Create a pod named `resource-pod` using the `nginx:1.29.0` image.
Make sure the pod only runs a single time.
The pod is supposed to run in namespace `limits`.
Set resource requests to `100m CPU` and `128Mi memory`.
Set resource limits to `200m CPU` and `256Mi memory`.

<details><summary>help</summary>

Create a pod template.

```bash
k run resource-pod --image nginx:1.29.0 --restart Never -n limits --dry-run=client -o yaml > t11pod.yaml
```

Modify the template and update the resources section for the container.

```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: resource-pod
  name: resource-pod
  namespace: limits
spec:
  containers:
  - image: nginx:1.29.0
    name: resource-pod
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
  dnsPolicy: ClusterFirst
  restartPolicy: Never # The container is supposed to run only once.
status: {}
```

Apply the pod definition.

```bash
k apply -f t11pod.yaml
```

</details>

## Task 12

Try to apply the following pod definition and see why it fails.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod2
  namespace: limits
spec:
  containers:
  - image: nginx:1.29.0
    name: resource-pod2
    resources:
      limits:
        cpu: 220m
        memory: 512Mi
```

Next, fix the definition and apply it.

_Optionally:_ Try to run another pod in the same namespace.

<details><summary>help</summary>

When trying to apply the pod definition as is it fails because the cpu limit and the memory limit is set to high.

Describe the namespace to see it's resource limits.

```bash
k describe ns limits
```

Alternatively you could get the limit definition for the namespace.

```bash
k get limitranges -n limits -o yaml
```

Modify the template and update the resources section for the container to not exceed the namespace limits and apply it.

</details>

## Task 13

Create a pod named `secret-logger` that reads the key `msg` of secret `task13-secret` to an environment variable.
Print the secret to `stdout` only once.

<details><summary>help</summary>

Create a pod definition (envFrom solution).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-logger
spec:
  containers:
  - name: secret-logger
    image: busybox
    command:
    - sh
    - -c
    - echo "$msg"
    envFrom:
    - secretRef:
        name: task13-secret
  restartPolicy: Never
```

Or create a pod definition (env solution).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-logger
spec:
  containers:
  - name: secret-logger
    image: busybox
    command:
    - sh
    - -c
    - echo "$SECRET_VALUE"
    env:
    - name: SECRET_VALUE
      valueFrom:
        secretKeyRef:
          name: task13-secret
          key: msg
  restartPolicy: Never
```

_Optionally:_ Verify the output.

```bash
k logs secret-logger
```

</details>

## Task 14

Create a pod named `selector` in namespace `task14` that only runs on nodes where the label `tier` has value `backend`.
Use a `nodeSelector` to accomplish the task.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: selector
  namespace: task14
spec:
  nodeSelector:
    tier: backend
  containers:
  - image: nginx
    name: selector
```

</details>

## Task 15

Create a pod named `affinity` in namespace `task15` that only runs on nodes where the label `tier` has value `frontend`.
Use a `nodeAffinity` to accomplish the task.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: affinity
  namespace: task15
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: tier
            operator: In
            values:
            - frontend
  containers:
  - name: nginx
    image: nginx
```

</details>

## Task 16

Create a pod named `tolerant`.
The pod should run only once and terminate after writing `I'm tolerant!` to the log."
Ensure the pod does not run on nodes with the label `tier` set to `frontend` or `backend`.
Schedule the pod on the control plane node.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tolerant
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: tier
            operator: NotIn
            values:
            - frontend
            - backend
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  containers:
  - name: tolerant
    image: busybox
    command: ["/bin/sh", "-c", "echo \"I'm tolerant!\""]
  restartPolicy: Never
```

</details>
