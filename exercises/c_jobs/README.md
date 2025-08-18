# Jobs & CronJobs

__Note:__ Remember you can use `kubectl create job` and `kubectl create cronjob` to create templates for these resources.

## Task 1

_Objective_: Create a Kubernetes Job that runs a single Pod to print "Hello CKAD" to standard output.

Requirements:

- Create a Job named `simple-job` in the namespace `default`.
- The Job should use the image `busybox:1.28`.
- The Job should execute the command `echo "Hello CKAD"`.
- Ensure the Job completes successfully.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: simple-job
spec:
  template:
    spec:
      containers:
      - image: busybox:1.28
        name: simple-job
        command:
        - /bin/sh
        - -c
        - echo "Hello CKAD"
      restartPolicy: Never
```

</details>

## Task 2

_Objective_: Create a Job to process data in parallel.

Requirements:

- Create a Job named `parallel-job` in the namespace `processor`.
- The Job should use the image `busybox:1.28` and the command `echo "Processing data"`.
- Configure the Job to run 3 parallel Pods at a time, and ensure 6 completions in total.
- Ensure all Pods complete successfully.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job
  namespace: processor
spec:
  parallelism: 3
  completions: 6
  template:
    spec:
      containers:
      - image: busybox:1.28
        name: parallel-job
        command:
        - /bin/sh
        - -c
        - echo "Processing data"
      restartPolicy: Never
```

</details>

## Task 3

_Objective_: Use a TTL (time-to-live) controller to clean up a completed Job automatically.

Requirements:

- Create a Job named `ttl-cleanup-job` in the namespace `cleanup`.
- Ensure the job resource file is named `t3job.yaml`.
- The Job should use the image `alpine:3.22` and the command `sleep 10`.
- Set the Job's TTL to 20 seconds so it gets automatically cleaned up after completion.
- Verify that the Job is deleted after 20 seconds post-completion.

<details><summary>help</summary>

Create and apply the resource (`t3job.yaml`).

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ttl-cleanup-job
  namespace: cleanup
spec:
  ttlSecondsAfterFinished: 20
  template:
    spec:
      containers:
      - image: alpine:3.22
        name: ttl-cleanup-job
        command:
        - sh
        - -c
        - sleep 10
      restartPolicy: Never
```

</details>

## Task 4

_Objective_: Configure a Job to handle failures.

Requirements:

- Create a Job named `failure-job` in the namespace `default`.
- The Job should use the image `busybox:1.28`.
- Configure the command to fail by running `ls /nonexistent-directory`.
- Limit the backoff retries to 2 attempts.
- Verify that the Job fails after 2 retries and does not run indefinitely.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: failure-job
  namespace: default
spec:
  backoffLimit: 2
  template:
    spec:
      containers:
      - image: busybox:1.28
        name: failure-job
        command:
        - sh
        - c
        - ls /nonexistent-directory
      restartPolicy: Never
```

</details>

## Task 5

_Objective_: Schedule a Job to run periodically.

Requirements:

- Create a CronJob named `scheduled-job` in the namespace `scheduled`.
- Use the image `busybox:1.28` with the command date.
- Schedule the CronJob to run every minute.
- Ensure that at least 2 successful Job runs are recorded.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scheduled-job
  namespace: scheduled
spec:
  jobTemplate:
    metadata:
      name: scheduled-job
    spec:
      template:
        spec:
          containers:
          - image: busybox:1.28
            name: scheduled-job
          restartPolicy: OnFailure
  schedule: '*/1 * * * *'
```

</details>

## Task 6

_Objective_: Create an Indexed Job to demonstrate the use of .spec.completionMode.

Requirements:

- Create a Job named `indexed-completion-job` in the `default` namespace.
- Configure the Job to use the image `busybox:1.28`.
- Set the command to `echo "This is task $JOB_COMPLETION_INDEX"`.
- Use `completionMode: Indexed` and configure the Job to require 3 completions.
- Verify the logs of each Pod to ensure the completion index is printed for all tasks.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: indexed-completion-job
  namespace: default
spec:
  completions: 3
  completionMode: Indexed
  template:
    spec:
      containers:
      - image: busybox:1.28
        name: indexed-completion-job
        command:
        - sh
        - -c
        - echo "This is task $JOB_COMPLETION_INDEX"
      restartPolicy: Never
```

</details>

## Task 7

_Objective_: Configure a Job with a custom Pod failure retry policy.

Requirements:

- Create a Job named `retry-policy-job` in the namespace `default`.
- The Job should use the image `busybox:1.28` and run the command `cat /nonexistent-file`.
- Limit the number of retries for failed Pods to 3 attempts.
- Configure the `PodFailurePolicy` such that the Job retries only if the Pod exits with ExitCode == 2 (indicating a specific error condition).
- Verify that the Job handles Pod failures and immediately stops retrying on other exit codes.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: retry-policy-job
  namespace: default
spec:
  backoffLimit: 3
  podFailurePolicy:
    rules:
    - action: FailJob
      onExitCodes:
        operator: NotIn
        values:
        - 2
  template:
    spec:
      containers:
      - image: busybox:1.28
        name: retry-policy-job
        command:
        - sh
        - -c
        - cat /nonexistent-file
      restartPolicy: Never
```

</details>

## Task 8

_Objective_: Create a Job Pod with memory and CPU constraints.

Requirements:

- Create a Job named `resource-limited-job` in the `default` namespace.
- Use the image `busybox:1.28` and the command `echo "Resource handled"`.
- Configure resource requests and limits as follows:
  - Memory request: 32Mi
  - Memory limit: 64Mi
  - CPU request: 250m
  - CPU limit: 500m
- Verify that the Job completes successfully and check resource usage using kubectl describe pod.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: resource-limited-job
spec:
  template:
    spec:
      containers:
      - image: busybox:1.28
        name: resource-limited-job
        command:
        - /bin/sh
        - -c
        - echo "Resources handled"
        resources:
          requests:
            memory: 32Mi
            cpu: 250m
          limits:
            memory: 64Mi
            cpu: 500m
      restartPolicy: Never
```

</details>

## Task 9

_Objective_: Add custom labels to track Job Pods.

Requirements:

- Create a Job named `label-job` in the `default` namespace.
- Use the image `busybox:1.28`.
- Add a custom label `purpose=testing` to the Pod template in the Job spec.
- Verify that the Pods created by the Job include the custom label.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: label-job
  namespace: default
spec:
  template:
    metadata:
      labels:
        purpose: testing
    spec:
      containers:
      - image: busybox:1.28
        name: label-job
      restartPolicy: Never
```

</details>

## Task 10

_Objective_: Configure a Job with Pod affinity rules.

Requirements:

- Create a Job named `affinity-job` in the `affinity` namespace.
- Use the image `busybox:1.28`.
- Configure Pod affinity so that the Job's Pods will only run on the same node where a Pod with the label `app=web-server` is already running.
- Verify that the Job creates Pods only if the required affinity conditions are met.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: affinity-job
  namespace: affinity
spec:
  template:
    spec:
      containers:
      - image: busybox:1.28
        name: affinity-job
      restartPolicy: Never
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - web-server
            topologyKey: "kubernetes.io/hostname"
```

</details>

## Task 11

_Objective_: Configure a Job to handle long-running tasks.

Requirements:

- Create a Job named `long-job` in the `default` namespace.
- Use the image `busybox:1.28` and the command `for i in $(seq 1 60); do echo "Running step $i"; sleep 1; done`.
- Ensure that the Job does not restart Pods unnecessarily and completes successfully after 60 seconds.
- Verify that logs from the long-running Job's Pods include the full execution output of all steps.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: long-job
  namespace: default
spec:
  template:
    spec:
      containers:
      - image: busybox:1.28
        name: long-job
        command:
        - /bin/sh
        - -c
        - for i in $(seq 1 60); do echo "Running step $i"; sleep 1; done
      restartPolicy: Never
```

</details>

## Task 12

_Objective_: Create a CronJob that runs every 5 minutes and prints the date.

Requirements:

- Create a CronJob named `print-date` in the `default` namespace.
- Make sure it starts the job every 5 minutes.
- Use the image `busybox:1.28` with command `/bin/sh -c`.
- Use the arguments field to print the current date to stdout (`echo "Current date: $(date)"`)
- Make sure the Job doesn't restarts on failures.

<details><summary>help</summary>

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: print-date
  namespace: default
spec:
  jobTemplate:
    metadata:
      name: print-date
    spec:
      template:
        spec:
          containers:
          - image: busybox:1.28
            name: print-date
            command:
            - /bin/sh
            - -c
            args:
            - 'echo "Current date: $(date)"'
          restartPolicy: Never
  schedule: '*/5 * * * *'
```

</details>

## Task 13

_Objective_: Create a Job with a sidecar container that processes it's logs.

Requirements:

- Create a job called `sidecar-job` using image `alpine:3.22` in namespace `sidecar`.
- Write the text `app log` to the file `/opt/logs.txt`.
- Mount an shared volume called `data` of type `emptyDir` on path `/opt`.
- Also create a sidecar `initContainer` called `log-forwarder` with image `busybox:1.28`
- Tail the file from the shared volume with command `tail -F /opt/logs.txt`.

<details><summary>help</summary>

__Note:__
sidecar containers are implemented as init containers with restart policy set to "Always", see the [docs](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/#jobs-with-sidecar-containers) for more details.

Create and apply the resource.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sidecar-job
  namespace: sidecar
spec:
  template:
    spec:
      containers:
        - name: sidecar-job
          image: alpine:3.22
          command:
          - /bin/sh
          - -c
          - echo "app log" > /opt/logs.txt
          volumeMounts:
            - name: data
              mountPath: /opt
      initContainers:
        - name: log-forwarder
          image: busybox:1.28
          restartPolicy: Always
          command: ['/bin/sh', '-c', 'tail -F /opt/logs.txt']
          volumeMounts:
            - name: data
              mountPath: /opt
      restartPolicy: Never
      volumes:
        - name: data
          emptyDir: {}
```

</details>
