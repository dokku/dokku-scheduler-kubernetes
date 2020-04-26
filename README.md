# dokku-scheduler-kubernetes

A Dokku plugin to integrate with kubernetes.

## Requirements

- The `dokku-registry` plugin should be installed and configured for your app
- A configured kubectl (`/home/dokku/.kube/config`) that can talk to your cluster
- Dokku 0.20.4+

## Installation

You can install this plugin by issuing the command:

```shell
dokku plugin:install https://github.com/dokku/dokku-scheduler-kubernetes
```

After the plugin has successfully been installed you need to install the plugin's dependencies by running the command:

```shell
dokku plugin:install-dependencies
```

## Functionality

The following functionality has been implemented

- Domain proxy support via the Nginx Ingress Controller
- Zero-downtime deploys via Deployment healthchecks
- Pod Disruption Budgets
- Deployment and Service annotations
- Environment variables
- Resource limits and reservations (reservations == kubernetes requests)

Unsupported at this time:

- Autoscaling management
- Custom docker-options (not applicable)
- Deployment timeouts
- Dockerfile support
- Encrypted environment variables (unimplemented, requires kubernetes secrets)
- Proxy port integration
- SSL Certificates
- The following scheduler commands are unimplemented:
  - `enter`
  - `logs:failed`
  - `run`
- Traffic to non-web containers (requires service object creation)

### Notes

- Each `Procfile` entry will be turned into a kubernetes `Deployment` object.
- Each `Procfile` entry name _must_ be a valid DNS subdomain.
- The `web` process will also create a `Service` object.
- All created Kubernetes objects are tracked to completion via `kubedog`.
- All manifest templates are hardcoded in the plugin.

## Usage

Set the scheduler to `kubernetes`. This can be done per-app or globally:

```shell
# globally
dokku config:set --global DOKKU_SCHEDULER=kubernetes

# per-app
dokku config:set APP DOKKU_SCHEDULER=kubernetes
```

You also need to ensure your kubectl has the correct context specified:

```shell
kubectl config use-context YOUR_NAME
```

And configure your registry:

```shell
dokku registry:set APP server gcr.io/dokku/
```

Assuming your Dokku installation can push to the registry and your kubeconfig is valid, Dokku will deploy the app against the cluster.

The namespace in use for a particular app can be customized using the `scheduler-kubernetes:set` command. This will apply to all future invocations of the plugin, and will not modify any existing resources. The `scheduler-kubernetes` will create the namespace via a `kubectl apply`.

```shell
dokku scheduler-kubernetes:set APP namespace test
```

If deploying from a private docker registry and the cluster needs does not have open access to the registry, an `imagePullSecrets` value can be specified. This will be injected into the kubernetes deployment spec at deploy time.

```shell
dokku scheduler-kubernetes:set APP imagePullSecrets registry-credential
```

> See [this doc](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) for more details on creating an `imagePullSecrets` secret file.

### Service Ingress

> This functionality assumes a helm-installed `nginx-ingress` controller:
>
> ```shell
> helm install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true
> ```

A Kubernetes service object is created for each `web` process. Additionally, if the app has it's `proxy-type` set to `nginx-ingress`, then we will also create or update a Kubernetes ingress object within the namespace configured for the app. This can be set as follows:

```shell
dokku config:set APP DOKKU_APP_PROXY_TYPE=nginx-ingress
```

The ingress object has the following properties:

- The name of the ingress object will be `app-ingress`.
- All kubernetes-deployed apps within the same namespace are added to the ingress object.
- Configured app domains are respected as unique rules.
- The configured service port for each rule is hardcoded to `5000`.

To modify the manifest before it gets applied to the cluster, use the `pre-kubernetes-ingress-apply` plugin trigger.

### Pod Disruption Budgets

A PodDisruptionBudget object can be created, and will apply to all process types in an app. To configure this, the `pod-max-unavailable` and `pod-min-available` properties can be set:

```shell
dokku scheduler-kubernetes:set APP pod-min-available 1

# available in kubernetes 1.7+
dokku scheduler-kubernetes:set APP pod-max-unavailable 1
```

Pod Disruption Budgets will be updated on next deploy.

### Kubernetes Manifests

> Warning: Running this command exposes app environment variables to stdout.

The kubernetes manifest for a deployment or service can be displayed using the `scheduler-kubernetes:show-manifest` command. This manifest can be used to inspect what would be submitted to Kubernetes.

```shell
# show the deployment manifest for the `web` process type
dokku scheduler-kubernetes:show-manifest APP PROC_TYPE MANIFEST_TYPE
```

This command can be used like so:

```shell
# show the deployment manifest for the `web` process type
dokku scheduler-kubernetes:show-manifest node-js-sample web


# implicitly specify the deployment manifest
dokku scheduler-kubernetes:show-manifest node-js-sample web deployment

# show the service manifest for the `web` process type
dokku scheduler-kubernetes:show-manifest node-js-sample web service
```

The command will exit non-zero if the specific manifest for the given app/process type combination is not found.

### Annotations

> Warning: There is no validation for on annotation keys or values.

#### Deployment Annotations

These can be managed by the `scheduler-kubernetes:deployment-annotations-set` command.

```shell
# command structure
dokku scheduler-kubernetes:deployment-annotations-set APP name value

# set example
dokku scheduler-kubernetes:deployment-annotations-set node-js-sample pod.kubernetes.io/lifetime 86400s

# unset example, leave the value empty
dokku scheduler-kubernetes:deployment-annotations-set node-js-sample pod.kubernetes.io/lifetime
```

Currently, these apply globally to all processes within a deployed app.

#### Pod Annotations

These can be managed by the `scheduler-kubernetes:pod-annotations-set` command.

```shell
# command structure
dokku scheduler-kubernetes:pod-annotations-set APP name value

# set example
dokku scheduler-kubernetes:pod-annotations-set node-js-sample pod.kubernetes.io/lifetime 86400s

# unset example, leave the value empty
dokku scheduler-kubernetes:pod-annotations-set node-js-sample pod.kubernetes.io/lifetime
```

Currently, these apply globally to all processes within a deployed app.

#### Service Annotations

These can be managed by the `scheduler-kubernetes:service-annotations-set` command.

```shell
# command structure
dokku scheduler-kubernetes:service-annotations-set APP name value

# set example
dokku scheduler-kubernetes:service-annotations-set node-js-sample pod.kubernetes.io/lifetime 86400s

# unset example, leave the value empty
dokku scheduler-kubernetes:service-annotations-set node-js-sample pod.kubernetes.io/lifetime
```

Currently, they are applied to the `web` process, which is the only process for which a Kubernetes Service is created.

### Rolling Updates

For deployments that use a `rollingUpdate` for rollouts, a `rollingUpdate` may be triggered at a later date via the `scheduler-kubernetes:rolling-update` command.

```shell
dokku scheduler-kubernetes:rolling-update APP
```

### Health Checks

Health checks for the app may be configured in `app.json`, based on [Kubernetes
liveness and readiness
probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/).
All Kubernetes options that can occur within a [Probe
object](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.14/#probe-v1-core)
are supported, though syntax is JSON rather than YAML. The variable `$APP` may
be used to represent the app name.

If a process type is not configured for a given probe type (liveness or
readiness), any probe of the same type for the `"*"` default process type is
used instead.

<details><summary>Here (click the triangle to expand) is an example JSON for
Kubernetes health checks.</summary><p>

```json
{
	"healthchecks": {
		"web": {
			"readiness": {
				"httpGet": {
					"path": "/{{ $APP }}/readiness_check",
					"port": 5000
				},
				"initialDelaySeconds": 5,
				"periodSeconds": 5
			}
		},
		"*": {
			"liveness": {
				"exec": {
					"command": ["/bin/pidof", "/start"]
				},
				"initialDelaySeconds": 5,
				"periodSeconds": 5
			},
			"readiness": {
				"httpGet": {
					"path": "web processes override this.",
					"port": 5000
				},
				"initialDelaySeconds": 5,
				"periodSeconds": 5
			}
		}
	}
}
```
</p></details>

## Plugin Triggers

The following custom triggers are exposed by the plugin:

### `post-deploy-kubernetes-apply`

- Description: Allows a user to interact with the `deployment` manifest after it has been submitted.
- Invoked by:
- Arguments: `$APP` `$PROC_TYPE` `$MANIFEST_FILE` `MANIFEST_TYPE`
- Example:

```shell
#!/usr/bin/env bash

set -eo pipefail; [[ $DOKKU_TRACE ]] && set -x

# TODO
```

### `pre-ingress-kubernetes-apply`

- Description: Allows a user to interact with the `ingress` manifest before it has been submitted.
- Invoked by: `core-post-deploy`, `post-domains-update`, `post-proxy-ports-update`, and `proxy-build-config` triggers
- Arguments: `$APP` `$MANIFEST_FILE`
- Example:

```shell
#!/usr/bin/env bash

set -eo pipefail; [[ $DOKKU_TRACE ]] && set -x

# TODO
```

### `pre-deploy-kubernetes-apply`

- Description: Allows a user to interact with the `deployment|service` manifest before it has been submitted.
- Invoked by: `scheduler-deploy` trigger and `scheduler-kubernetes:show-manifest`
- Arguments: `$APP` `$PROC_TYPE` `$MANIFEST_FILE` `MANIFEST_TYPE`
- Example:

```shell
#!/usr/bin/env bash

set -eo pipefail; [[ $DOKKU_TRACE ]] && set -x

# TODO
```
