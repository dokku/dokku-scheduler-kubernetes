# dokku-scheduler-kubernetes

A Dokku plugin to integrate with kubernetes.

## Requirements

- The `dokku-registry` plugin should be installed and configured for your app
- A configured kubectl (`/home/dokku/.kube/config`) that can talk to your cluster

## Installation

You can install this plugin by issuing the command:

```shell
dokku plugin:install https://github.com/dokku/dokku-scheduler-kubernetes
```

After the plugin has successfully been installed you need to install the plugin's dependencies by running the command:

```shell
dokku plugin:install-dependencies
```

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

## Notes

- Dockerfile deploys are not currently supported.
- Each `Procfile` entry will be turned into a kubernetes `Deployment` object.
- The `web` process will also create a `Service` object.
- All created Kubernetes objects are tracked to completion via `kubedog`.
- Templates for `Deployment` and `Service` objects are hardcoded in the plugin.
- Environment variables are set plaintext in the deployment object.
- Resource limits and requests are supported from the `resource` plugin (Kubernetes requests are Dokku reservations).
- The Dokku commands `run`, `enter`, and `logs:failed` are not supported.
- A custom nginx configuration - or a different proxy plugin implementation - will be needed in order to talk to the Kubernetes `Service` upstream.
- Custom docker-options are not supported.
