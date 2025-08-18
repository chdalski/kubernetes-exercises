# RBAC

## Task 1

__Objective__:
Create a `ServiceAccount` named `pod-viewer-sa` in the `dev-team-1` namespace.
Grant this service account read-only access to view all pods within that same namespace.

Requirements:

- Create a new namespace called `dev-team-1`.
- Create a `ServiceAccount` named `pod-viewer-sa` in the `dev-team-1` namespace.
- Create a `Role` named `pod-reader-role` in the `dev-team-1` namespace that allows `get`, `watch`, and `list` verbs on the `pods` resource.
- Create a `RoleBinding` named `pod-viewer-binding` in the `dev-team-1` namespace to bind the `pod-reader-role` to the `pod-viewer-sa` `ServiceAccount`.
- Verify that the `pod-viewer-sa` can list pods in the `dev-team-1` namespace and cannot list pods in the `default` namespace.

<details><summary>help</summary>

Create the resources:

```bash
k create ns dev-team-1
k create sa pod-viewer-sa -n dev-team-1
k create role pod-reader-role -n dev-team-1 --verb get,watch,list --resource pods
k create rolebinding pod-viewer-binding -n dev-team-1 --role pod-reader-role --serviceaccount dev-team-1:pod-viewer-sa
```

Verify:

```bash
# Command to test permissions for a ServiceAccount
# kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<serviceaccount_name> -n <namespace>

# Example:
k auth can-i list pods --as=system:serviceaccount:dev-team-1:pod-viewer-sa -n dev-team-1
```

</details>

## Task 2

__Objective__:
A monitoring tool needs read-only access to `Node` resources across the entire cluster.
Create a `ServiceAccount` for this tool and grant it the necessary cluster-wide permissions.

Requirements:

- Create a new namespace called `monitoring`.
- Create a `ServiceAccount` named `node-inspector-sa` in the `monitoring` namespace.
- Create a `ClusterRole` named `node-reader-crole` that grants `get` and `list` permissions on `nodes`.
- Create a `ClusterRoleBinding` named `node-inspector-crbinding` to grant the `node-reader-crole` permissions to the `node-inspector-sa` `ServiceAccount`.

<details><summary>help</summary>

Create the resources:

```bash
k create ns monitoring
k create sa node-inspector-sa -n monitoring
k create clusterrole node-reader-crole --verb get,list --resource nodes
k create clusterrolebinding node-inspector-crbinding --clusterrole node-reader-crole --serviceaccount monitoring:node-inspector-sa
```

Verify:

```bash
# A ClusterRole is not namespaced. A ClusterRoleBinding is not namespaced.
# You bind a namespaced subject (like a ServiceAccount) to a ClusterRole using a ClusterRoleBinding.
# The 'subjects' section of a binding must specify the namespace of the ServiceAccount.

# Example subject for a ServiceAccount in a ClusterRoleBinding:
# subjects:
# - kind: ServiceAccount
#   name: node-inspector-sa
#   namespace: monitoring

# Test command
k auth can-i get nodes --as=system:serviceaccount:monitoring:node-inspector-sa --all-namespaces
```

</details>

## Task 3

__Objective__:
Create a `ServiceAccount` for a CI/CD pipeline that can only manage `Deployments` (and the `Pods` they create) within the `cicd-pipelines` namespace. It should not be able to interact with any other resource types.

Requirements:

- Create a new namespace called `cicd-pipelines`.
- Create a `ServiceAccount` named `cicd-agent-sa` in the `cicd-pipelines` namespace.
- Create a `Role` named `deployment-manager-role` in the `cicd-pipelines` namespace that allows full access (`*` verb) to `deployments`, `replicasets`, and `pods`.
- Create a `RoleBinding` to associate the `ServiceAccount` with the `Role`. Name it `cicd-agent-binding`.
- Verify that the `cicd-agent-sa` can create a `Deployment` but cannot create a `Service`.

<details><summary>help</summary>

Create the resources:

```bash
k create ns cicd-pipelines
k create sa cicd-agent-sa -n cicd-pipelines
k create role deployment-manager-role -n cicd-pipelines --verb '*' --resource deployments,replicasets,pods
k create rolebinding cicd-agent-binding -n cicd-pipelines --serviceaccount cicd-pipelines:cicd-agent-sa --role deployment-manager-role
```

Verify:

```bash
# You can grant all verbs for a resource using the wildcard '*'.
# apiGroups: ["apps"] is needed for Deployments and ReplicaSets.
# apiGroups: [""] is for core resources like Pods and Services.

# Example Role rule for deployments:
# - apiGroups: ["apps"]
#   resources: ["deployments"]
#   verbs: ["*"]

# Test commands
k auth can-i create deployments --as=system:serviceaccount:cicd-pipelines:cicd-agent-sa -n cicd-pipelines
k auth can-i create services --as=system:serviceaccount:cicd-pipelines:cicd-agent-sa -n cicd-pipelines
```

</details>

## Task 4

__Objective__:
You need to set up a `ServiceAccount` that can only view the logs of pods in the `app-prod` namespace. It should not have any other permissions.

Requirements:

- Use the existing `default` namespace for the `ServiceAccount`.
- Create a `ServiceAccount` named `log-scraper-sa` in the `default` namespace.
- Create a `Role` named `log-reader-role` in the `app-prod` namespace. This role should only grant permission to access the `logs` subresource of `pods`.
- Create a `RoleBinding` named `log-scraper-binding` in the `app-prod` namespace. This binding must grant the `log-reader-role` to the `log-scraper-sa` `ServiceAccount` from the `default` namespace.

__Predefined Resources:__

- Namespace: `app-prod`

<details><summary>help</summary>

Create the resources:

```bash
k create sa -n default log-scraper-sa
k create role log-reader-role -n app-prod --verb get --resource pods/log
k create rolebinding log-scraper-binding -n app-prod --role log-reader-role --serviceaccount default:log-scraper-sa
```

Verify:

```bash
# Subresources are specified in the 'resources' field of a rule, like 'pods/log'.
# To bind a ServiceAccount from one namespace (e.g., 'default') to a Role in another ('app-prod'),
# the RoleBinding must exist in the target namespace ('app-prod') and explicitly state the
# source namespace of the ServiceAccount in its 'subjects' section.

# Example subject for cross-namespace binding

# subjects
# - kind: ServiceAccount
#   name: log-scraper-sa
#   namespace: default # <-- Important

# Test command
k auth can-i -n app-prod get pods --subresource log --as=system:serviceaccount:default:log-scraper-sa
```

</details>

## Task 5

__Objective__:
A developer, represented by the `ServiceAccount` `dev-user-1`, reports they are unable to list `ConfigMaps` in their namespace, `project-alpha`.
An existing `Role` and `RoleBinding` are supposed to grant this permission.
Find the issue and fix it.

Requirements:

- Inspect the provided `Role` and `RoleBinding`.
- Identify the misconfiguration that prevents the `ServiceAccount` from listing `ConfigMaps`.
- Correct the misconfiguration directly on the cluster. Do not delete and recreate the resources.
- Verify that `dev-user-1` can now list `ConfigMaps` in the `project-alpha` namespace.

__Predefined Resources:__

- Namespace: `project-alpha`
- ServiceAccount: `dev-user-1` in namespace `project-alpha`
- Role `config-reader` in namespace `project-alpha`
- RoleBinding `dev-user-1-binding` in namespace `project-alpha`

<details><summary>help</summary>

The resource statement in the role `config-reader` is defined as _configmap_ (singular), but must be defined as _configmaps_ (plural).
The resource names to use can be listed with `k api-resources --sort-by name --output name`.

```bash
# First, use 'kubectl auth can-i' to confirm the problem.
k auth can-i list configmaps --as=system:serviceaccount:project-alpha:dev-user-1 -n project-alpha

# Use 'kubectl api-resources' to find the correct plural name for resources.
k api-resources | grep config

# Use 'kubectl edit <resource_type> <resource_name> -n <namespace>' to fix the live object.
k edit role config-reader -n project-alpha
```

</details>

## Task 6

__Objective__:
Create a `ServiceAccount` named `specific-secret-reader-sa` in the `finance` namespace.
This account must be granted read-only (`get`) access to a _specific_ `Secret` named `api-key-v2`, and no other secrets in the namespace.

Requirements:

- Create a `Secret` named `api-key-v2` in the `finance` namespace. The content does not matter.
- Create a `ServiceAccount` named `specific-secret-reader-sa` in the `finance` namespace.
- Create a `Role` named `single-secret-getter-role` that uses the `resourceNames` field to restrict `get` access to only the `api-key-v2` `Secret`.
- Create a `RoleBinding` named `single-secret-getter-binding` to grant this role to the `ServiceAccount`.

__Predefined Resources:__

- Namespace: `finance`

<details><summary>help</summary>

Create the resources:

```bash
k create secret generic api-key-v2 --from-literal key=something -n finance
k create sa -n finance specific-secret-reader-sa
k create role -n finance single-secret-getter-role --verb get --resource secret --resource-name api-key-v2
```

Verify:

```bash
# The `resourceNames` field in a Role's rule is an array of strings that specifies the names of the
# resources this rule applies to.

# Example rule with resourceNames:
# rules:
# - apiGroups: [""]
#   resources: ["secrets"]
#   verbs: ["get"]
#   resourceNames: ["api-key-v2"]

# Test commands
# This should succeed
kubectl auth can-i get secrets/api-key-v2 --as=system:serviceaccount:finance:specific-secret-reader-sa -n finance

# This should fail
kubectl auth can-i get secrets/some-other-secret --as=system:serviceaccount:finance:specific-secret-reader-sa -n finance

# This should also fail
kubectl auth can-i get secrets --as=system:serviceaccount:finance:specific-secret-reader-sa -n finance
```

</details>

## Task 7

__Objective__:
A debugging tool, running as a pod, needs to be able to execute commands (`exec`) inside other application pods in the `qa-environment` namespace.
Create a `ServiceAccount` and the necessary RBAC permissions to allow this.

Requirements:

- Create a namespace named `qa-environment`.
- Create a `ServiceAccount` named `debugger-sa` in the `qa-environment` namespace.
- Create a `Role` named `pod-exec-role` in the `qa-environment` namespace. The role must grant the `create` verb on the `pods/exec` subresource. It should also grant `get` and `list` permissions on `pods` so the tool can find the pods to `exec` into.
- Create a `RoleBinding` named `debugger-binding` to bind the role to the service account.
- Verify that `debugger-sa` can use `exec` for Pods in namespace `qa-environment`.

<details><summary>help</summary>

Create the resources:

```bash
k create ns qa-environment
k create role -n qa-environment pod-exec-role --verb create --resource pods/exec
k create rolebinding -n qa-environment debugger-binding --role pod-exec-role --serviceaccount qa-environment:debugger-sa
```

Update the role in place (`k edit -n qa-environment role pod-exec-role`):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-exec-role
  namespace: qa-environment
rules:
- apiGroups:
  - ""
  resources:
  - pods/exec
  verbs:
  - create
# Add the following:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
```

Verify:

```bash
k auth can-i -n qa-environment get pods --as system:serviceaccount:qa-environment:debugger-sa
k auth can-i -n qa-environment list pods --as system:serviceaccount:qa-environment:debugger-sa
k auth can-i -n qa-environment create pods --subresource exec --as system:serviceaccount:qa-environment:debugger-sa
```

</details>

## Task 8

__Objective__:
A data science team needs permissions to manage the lifecycle of `CronJobs` in their dedicated namespace, `batch-processing`, but they should not be able to manage any other workload types like `Deployments` or `Pods` directly.

Requirements:

- Create a new namespace called `batch-processing`.
- Create a `ServiceAccount` named `cron-manager-sa` in the `batch-processing` namespace.
- Create a `Role` named `cronjob-lifecycle-role` in the `batch-processing` namespace that allows the verbs `get`, `list`, `watch`, `create`, `update`, `patch`, and `delete` on the `cronjobs` resource within the `batch` API group.
- Create a `RoleBinding` named `bind-cron-manager` to grant the `cronjob-lifecycle-role` to the `cron-manager-sa` `ServiceAccount`.
- Verify the service account can create a `CronJob` but cannot create a `Pod`.

<details><summary>help</summary>

Create the resources:

```bash
k create ns batch-processing
k create sa cron-manager-sa -n batch-processing
k create role -n batch-processing cronjob-lifecycle-role --verb get,list,watch,create,update,patch,delete --resource cronjobs.batch
k create rolebinding -n batch-processing bind-cron-manager --role cronjob-lifecycle-role --serviceaccount batch-processing:cron-manager-sa
```

Verify:

```bash
# This should succeed
k auth can-i create cronjobs.batch --as=system:serviceaccount:batch-processing:cron-manager-sa -n batch-processing
# This should fail
k auth can-i create pods --as=system:serviceaccount:batch-processing:cron-manager-sa -n batch-processing
```

</details>

## Task 9

__Objective__:
A new DevOps engineer, `<sara.jones@example.com>`, has joined the team.
Grant her cluster-wide read-only access to all `PersistentVolumeClaims` (PVCs) and `StorageClasses`.

Requirements:

- Create a `ClusterRole` named `storage-viewer-crole`.
- The `ClusterRole` must grant `get`, `list`, and `watch` permissions on `persistentvolumeclaims` (core API group) and `storageclasses` (`storage.k8s.io` API group).
- Create a `ClusterRoleBinding` named `sara-storage-viewer-crbinding`.
- The `ClusterRoleBinding` must bind the `storage-viewer-crole` to the `User` `sara.jones@example.com`.

<details><summary>help</summary>

Create the resources:

```bash
k create clusterrole storage-viewer-crole --verb get,list,watch --resource persistentvolumeclaims,storageclasses.storage.k8s.io
k create clusterrolebinding sara-storage-viewer-crbinding --user sara.jones@example.com --clusterrole storage-viewer-crole
```

Verify:

```bash
# When creating a binding for a human user, the subject 'kind' is 'User'.
# Unlike a ServiceAccount, a User is not namespaced.

# Example subject for a User:
# subjects:
# - kind: User
#   name: sara.jones@example.com
#   apiGroup: rbac.authorization.k8s.io

# Test command for a user
kubectl auth can-i list persistentvolumeclaims --as=sara.jones@example.com --all-namespaces
kubectl auth can-i list storageclasses --as=sara.jones@example.com
```

</details>
