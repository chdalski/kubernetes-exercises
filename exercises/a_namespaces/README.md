# Namespaces

## Task 1

Create a new namespace `ckad`.

<details><summary>help</summary>

```bash
k create namespace ckad
```

</details>

## Task 2

Create a yaml for a new namespace `foo` called `foo.yaml` and apply it to the cluster.

<details><summary>help</summary>

```bash
k create namespace foo --dry-run=client -o yaml > foo.yaml
k apply -f foo.yaml
```

</details>

## Task 3

Add the annotations `learning: kubernetes` and `hello: world` to namespace `foo`.

<details><summary>help</summary>

```bash
k annotate ns foo learning=kubernetes hello=world
```

</details>

## Task 4

List all annotations on namespace `foo` as json using `jq` write the output to a new file `foo-annotations-jq.json`..

<details><summary>help</summary>

```bash
k get ns foo -o json | jq .metadata.annotations > foo-annotations-jq.json
```

</details>

## Task 5

List all annotations on namespace `foo` using jsonpath and write the output to a new file `foo-annotations-jsonpath.json`.

<details><summary>help</summary>

```bash
k get ns foo -o jsonpath="{.metadata.annotations}" > foo-annotations-jsonpath.json
```

</details>

## Task 6

Write the names of all namespaces to a new file called `all-namespaces.txt`.

<details><summary>help</summary>

```bash
k get ns -o name > all-namespaces.txt
```

</details>

## Task 7

Create a ResourceQuota called `berry-quota` for namespace `blueberry` with a hard quota of 2 cpus, 3 pods and 2G of memory.

_Optionally:_ describe the namespace to see the quota in place.

<details><summary>help</summary>

```bash
k create quota berry-quota --hard cpu=2,pods=3,memory=2G -n blueberry
```

</details>

## Task 8

Create a LimitRange in namespace `sunshine` called `cpu-limit` with a minimum cpu setting of 100m, a maximum cpu setting of 1 cpu, a default cpu setting of 200m and a default cpu-request setting of 100m. All settings should be applied per container.

_Optionally:_ describe the namespace to see the limits in place.

<details><summary>help</summary>

Create the resource:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: cpu-limit
  namespace: sunshine
spec:
  limits:
  - type: Container
    max:
      cpu: "1" # define the max cpu limit
    min:
      cpu: 100m # define the min cpu limit
    default:
      cpu: 200m # define the default cpu limit
    defaultRequest:
      cpu: 100m # define the default cpu request
```

</details>
