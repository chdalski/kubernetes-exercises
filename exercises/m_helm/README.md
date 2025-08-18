# Helm

## Task 1

__Objective__:
Add a bitnami helm chart repository in the cluster.

Requirements:

- Add the bitnami helm chart repository to the cluster
- Use the name `bitnami`
- Use the url <https://charts.bitnami.com/bitnami>

<details><summary>help</summary>

Add the repo with:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

</details>

## Task 2

__Objective__:
Install the Bitnami Apache Helm chart with custom values.

Requirements:

- Use the Bitnami Apache chart (`bitnami/apache`)
- Name the release `custom-apache`
- Install into the namespace `web`.
- Set the image tag to `2.4.58-debian-11-r0`
- Set the service type to `NodePort`
- Set the replica count to `3`

__Predefined Resources:__

- Namespace: `web`

<details><summary>help</summary>

Find the values in the Chart:

```bash
helm show values bitnami/apache | grep -iC4 "tag:" # image.tag
helm show values bitnami/apache | grep -iC4 "type:" # service.type
helm show values bitnami/apache | grep -iC4 "count:" # replicaCount
```

Install in namespace `web`:

```bash
helm install custom-apache bitnami/apache --set service.type=NodePort,image.tag=2.4.58-debian-11-r0,replicaCount=3 -n web
```

</details>

## Task 3

__Objective__:
Upgrade an existing Helm release to another version.

Requirements:

- The release is named `vault` in namespace `fort-knox`
- Upgrade the Chart version to `0.30.1`

<details><summary>help</summary>

Upgrade with:

```bash
helm upgrade vault hashicorp/vault --version 0.30.1 -n fort-knox
```

</details>

## Task 4

__Objective__:
Render the manifests for a Helm chart without installing it.

Requirements:

- Use the Bitnami Redis chart (`bitnami/redis`)
- Set the image tag to `7.2.0-debian-11-r0`
- Output the rendered manifests to a file named `redis-manifests.yaml`.

<details><summary>help</summary>

Render the manifest with:

```bash
helm template redis bitnami/redis --set image.tag=7.2.0-debian-11-r0 > redis-manifests.yaml
```

</details>

## Task 5

__Objective__:
Cleanly uninstall a Helm release and ensure all resources are deleted.

Requirements:

- The release is named `qdrant-db` in namespace `ai`
- Ensure all associated resources are deleted.

<details><summary>help</summary>

List the release with:

```bash
helm repo list -n ai
```

Uninstall with:

```bash
helm uninstall qdrant-db -n ai
```

</details>

## Task 6

__Objective__:
Rollback a Helm release to a previous revision.

Requirements:

- The release is named `terraform` in namespace `deployment`
- Rollback to revision 1.

<details><summary>help</summary>

Show the current revision:

```bash
helm history terraform -n deployment
# or
helm list -n deployment | grep terraform | awk '{print $3}'
```

Rollback with:

```bash
helm rollback terraform 1 -n deployment
```

Show the history again:

```bash
helm history terraform -n deployment
```

</details>

## Task 7

__Objective__:
Pull a Helm Chart and unpack the files.

Requirements:

- Pull the Helm Chart `hello-world`:
  - from repository `https://helm.github.io/examples`
  - use version `0.1.0`
  - untar the files

<details><summary>help</summary>

Pull and untar the Chart:

```bash
helm pull hello-world --repo https://helm.github.io/examples --version 0.1.0 --untar
```

</details>
