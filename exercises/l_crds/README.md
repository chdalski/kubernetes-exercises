# CRDs and Operators

## Task 1

__Objective__:
Extend the Kubernetes API by creating a new Custom Resource Definition (CRD) to define a Website resource. After creating the CRD, create an instance of this new resource.

Requirements:

- Create a namespaced CRD named `websites.stable.example.com`.
- The CRD should have a version of `v1`.
- The plural name should be `websites`, the singular name `website`, and the kind `Website`.
- Add a short name `ws`.
- The schema must enforce the following rules for the spec:
  - `gitRepo` (string): An optional field.
- After the CRD is created and established, create a new Website object named `my-site` in the default namespace.
- The Website object should have a `spec.gitRepo` field with the value `https://github.com/example/my-site.git`.

<details><summary>help</summary>

Create the CRD:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: websites.stable.example.com # is always <spec.names.plural>.<spec.group>
spec:
  group: stable.example.com
  scope: Namespaced
  names:
    plural: websites
    singular: website
    shortNames:
    - ws
    kind: Website
  versions:
  - name: v1 # determines the apiVersion (i.e. <spec.group>/<spec.versions.[0].name>) for resources of that kind
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec: # creates the "spec" section (see below)
            type: object # defines the type of the "spec" section
            properties:
              gitRepo: # creates the property "spec.gitRepo" (see below)
                type: string # define the type of "spec.gitRepo"
```

Create the definition:

```yaml
apiVersion: stable.example.com/v1
kind: Website
metadata:
  name: my-site
spec: # spec-section
  gitRepo: https://github.com/example/my-site.git # property spec.gitRepo
```

</details>

## Task 2

__Objective__:
Create a new CRD for a ScheduledRunner that includes a validation schema to enforce specific rules on its custom objects.

Requirements:

- Create a namespaced CRD named `scheduledrunners.apps.example.com`.
- The group must be `apps.example.com` and the version `v1alpha1`.
- The kind should be `ScheduledRunner` and the plural name `scheduledrunners`.
- Define an `openAPIV3Schema` for the spec of the custom resource.
- The schema must enforce the following rules for the spec:
  - `cronSpec` (string): A required field that must match the regex pattern `^(\d+|\*)(/\d+)?(\s+(\d+|\*)(/\d+)?){4}$`.
  - `image` (string): A required field.
  - `replicas` (integer): An optional field with a minimum value of `1` and a maximum value of `5`.
- Create a ScheduledRunner object named `nightly-job` that is valid.

_Optionally:_

- Attempt to create an invalid ScheduledRunner object named invalid-job with a cronSpec of every 5 minutes and verify that it is rejected by the API server.

<details><summary>help</summary>

The core of this task is building the openAPIV3Schema within the CRD definition.
See the [JSONSchemaProps](https://kubernetes.io/docs/reference/kubernetes-api/extend-resources/custom-resource-definition-v1/#JSONSchemaProps) documentation for help.

Create the CRD:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: scheduledrunners.apps.example.com
spec:
  group: apps.example.com
  scope: Namespaced
  names:
    plural: scheduledrunners
    kind: ScheduledRunner
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["cronSpec", "image"] # required properties of the spec-object
            properties:
              cronSpec:
                type: string
                pattern: '^(\d+|\*)(/\d+)?(\s+(\d+|\*)(/\d+)?){4}$' # pattern is used for regular expressions, while format defines types like date, password etc.
              image:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 5
```

Create a resource (example):

```yaml
apiVersion: apps.example.com/v1alpha1
kind: ScheduledRunner
metadata:
  name: nightly-job
spec:
  cronSpec: '* * * * *'
  image: some-image:v1
```

</details>

## Task 3

__Objective__:
Create a CustomResourceDefinition (CRD) for a "Book" resource and deploy a sample Book instance.

Requirements:

- Create a namespaced CRD named `books.myorg.io` with the following spec fields: `title` (string), `author` (string), `pages` (integer)
- Use `v1` as version name.
- Deploy a Book resource named `moby-dick` with title `Moby Dick`, author `Herman Melville`, and pages `635`
- No controller is required
- Use the namespace `library`.

<details><summary>help</summary>

Create the CRD:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: books.myorg.io
spec:
  group: myorg.io
  scope: Namespaced
  names:
    plural: books
    singular: book
    kind: Book
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              title:
                type: string
              author:
                type: string
              pages:
                type: integer
```

Create the namespace:

```bash
k create ns library
```

Create the resource:

```yaml
apiVersion: myorg.io/v1
kind: Book
metadata:
  name: moby-dick
  namespace: library
spec:
  title: Moby Dick
  author: Herman Melville
  pages: 635
```

</details>

## Task 4

__Objective__:
Create a CRD for a "Device" resource and add custom columns for `model` and `location` in `kubectl get`.

Requirements:

- Create a namespaced CRD named `devices.tech.io` with spec fields `model` (string) and `location` (string).
- Use `v1beta1` as version name.
- Add additional printer columns for `Model` and `Location`.
- Deploy a Device named `router-1` with model `RTX1000` and location `datacenter-1`.

_Optionally:_ Verify the custom columns are displayed

<details><summary>help</summary>

Create the CRD:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: devices.tech.io
spec:
  group: tech.io
  names:
    kind: Device
    plural: devices
    singular: device
  scope: Namespaced
  versions:
  - name: v1beta1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              model:
                type: string
              location:
                type: string
    additionalPrinterColumns:
    - jsonPath: .spec.model
      name: Model
      type: string
    - jsonPath: .spec.location
      name: Location
      type: string
```

Create the resource:

```yaml
apiVersion: tech.io/v1beta1
kind: Device
metadata:
  name: router-1
spec:
  model: RTX1000
  location: datacenter-1
```

Verify:

```bash
k get devices.tech.io
```

</details>

## Task 5

__Objective__:
Create a CRD for a "Setting" resource with a default and enum values.

Requirements:

- Define a CRD named `settings.config.io` with:
  - a spec field `enabled` (boolean, default: true)
  - a spec field `color` (string, allowed values: `red`, `green`, `blue`)
  - version name `v1`
  - kind `Settings`
- Deploy a Setting named `feature-x` without specifying `enabled` and color `blue`
- Verify that `enabled` is set to true by default

_Optionally:_ Attempt to deploy a Setting with color `yellow` (should fail).

<details><summary>help</summary>

Create the CRD:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: settings.config.io
spec:
  group: config.io
  names:
    kind: Settings
    plural: settings
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              enabled:
                type: boolean
                default: true
              color:
                type: string
                enum:
                - red
                - green
                - blue
```

Create the resource:

```yaml
apiVersion: config.io/v1
kind: Settings
metadata:
  name: feature-x
spec:
  color: blue
```

Verify:

```bash
k get settings.config.io feature-x -o yaml

# should display (snippet):
# ...
# spec:
#   color: blue
#   enabled: true
```

Try to create a resource with a invalid color should result in:

```bash
The Settings "feature-x" is invalid: spec.color: Unsupported value: "yellow": supported values: "red", "green", "blue"
```

</details>
