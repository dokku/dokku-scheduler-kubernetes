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

- Deployment and Service annotations
- Domain proxy support via the Nginx Ingress Controller
- Environment variables
- Letsencrypt SSL Certificate integration via CertManager
- Pod Disruption Budgets
- Resource limits and reservations (reservations == kubernetes requests)
- Zero-downtime deploys via Deployment healthchecks

Unsupported at this time:

- Custom docker-options (not applicable)
- Deployment timeouts
- Dockerfile support
- Encrypted environment variables (unimplemented, requires kubernetes secrets)
- Proxy port integration
- Manual SSL Certificates
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

#### Automated SSL Integration via CertManager

> This functionality assumes a helm-installed `cert-manager` CRD:
>
> ```shell
> kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager.crds.yaml
> kubectl create namespace cert-manager
> helm repo add jetstack https://charts.jetstack.io
> helm install cert-manager --version v0.14.1 --namespace cert-manager jetstack/cert-manager
> ```

At this time, the `scheduler-kubernetes` does not have support for custom SSL certificates. However, domains associated with an app can have a Letsencrypt SSL certificate provisioned automatically via the [CertManager](https://github.com/jetstack/cert-manager) Kubernetes add-on.

To start using the CertManager, we'll first need to set the issuer email

```shell
dokku config:set --global CERT_MANAGER_EMAIL=your@email.tld
```

Next, any apps that will require cert-manager integration will need to have that enabled:

```shell
dokku scheduler-kubernetes:set APP cert-manager-enabled true
```

On the next deploy or domain name change, the CertManager entry will be automatically updated to fetch an SSL certificate for all domains associated with all applications on the same ingress object.

### Pod Disruption Budgets

A PodDisruptionBudget object can be created, and will apply to all process types in an app. To configure this, the `pod-max-unavailable` and `pod-min-available` properties can be set:

```shell
dokku scheduler-kubernetes:set APP pod-min-available 1

# available in kubernetes 1.7+
dokku scheduler-kubernetes:set APP pod-max-unavailable 1
```

Pod Disruption Budgets will be updated on next deploy.

### Deployment Autoscaling

> This feature requires an installed metric server, uses the `autoscaling/v2beta2` api, and will apply immediately.

By default, Kubernetes deployments are not set to autoscale, but a HorizontalPodAutoscaler object can be managed for an app on a per-process type basis. At a minimum, both a min/max number of replicas must be set.

```shell
# set the min number of replicas
dokku scheduler-kubernetes:autoscale-set APP PROC_TYPE min-replicas 1

# set the max number of replicas
dokku scheduler-kubernetes:autoscale-set APP PROC_TYPE max-replicas 10
```

You also need to add autoscaling rules. These can be managed via the `:autoscale-rule-add` command. Adding a rule for a target-name/metric-type combination that already exists will override the existing rule with a warning message on stderr.

Rules can be added for the following metric types (specified by the `--metric-type` flag):

- `ingress`: A rule that allows autoscaling based on ingress metrics.
  - options:
    - `--ingress-name` (default: `app-ingress`): The name of the ingress resource to track.
    - `--target-name` (required: true): The name of the metric from the ingress resource to track.
    - `--target-value` (required: true): The value to track.
- `pod`
  - options:
    - `--target-name` (required: true): The name of the metric from the pod resource to track.
    - `--target-type` (default: `targetAverageUtilization`, options: `[targetAverageUtilization, targetAverageValue]`): The type of the target.
    - `--target-value`: The value to track.
- `resource`
  - options:
    - `--target-name` (options: `[cpu, memory]`, required: true): The name of the metric to track. 
    - `--target-type` (default: `targetAverageUtilization`, options: `[targetAverageUtilization, targetAverageValue]`): The type of the target.
    - `--target-value` (required: true): The value to track.

```shell
# set the cpu average utilization target
dokku scheduler-kubernetes:autoscale-rule-add APP PROC_TYPE --target-name cpu --target-value 50 --target-type targetAverageUtilization --metric-type resource
```

Rules can be listed via the `autoscale-rule-list` command:

```shell
dokku scheduler-kubernetes:autoscale-rule-list APP PROC_TYPE
```

And finally, rules can be removed via the `:autoscale-rule-remove` command. Note that this command takes the same flags as the `autoscale-rule-add` command. If a rule matching the specified flags does not exist, the command will still return 0.

```shell
# remove the cpu rule
dokku scheduler-kubernetes:autoscale-rule-remove APP PROC_TYPE --target-name cpu --target-value 50 --target-type targetAverageUtilization --metric-type resource
```

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
