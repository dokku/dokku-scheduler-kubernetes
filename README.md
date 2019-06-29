# dokku-scheduler-kubernetes

A Dokku plugin to integrate with kubernetes.

## Requirements

- The `dokku-registry` plugin should be installed and configured for your application
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

Assuming your Dokku installation can push to the registry and your kubeconfig is valid, Dokku will deploy the application against the cluster.

The namespace in use for a particular app can be customized using the `scheduler-kubernetes:set` command. This will apply to all future invocations of the plugin, and will not modify any existing resources. The `scheduler-kubernetes` will create the namespace via a `kubectl apply`.

```shell
dokku scheduler-kubernetes:set APP namespace test
```

If deploying from a private docker registry and the cluster needs does not have open access to the registry, an `imagePullSecrets` value can be specified. This will be injected into the kubernetes deployment spec at deploy time.

```shell
dokku scheduler-kubernetes:set APP imagePullSecrets registry-credential
```

> See [this doc](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) for more details on creating an `imagePullSecrets` secret file.

## Notes

- Dockerfile deploys are not currently supported.
- Each `Procfile` entry will be turned into a kubernetes `Deployment` object.
- The `web` process will also create a `Service` object.
- All created Kubernetes objects are tracked to completion via `kubectl`.
- Templates for `Deployment` and `Service` objects are hardcoded in the plugin.
- Environment variables are set plaintext in the deployment object.
- Resource limits and requests are supported from the `resource` plugin (Kubernetes requests are Dokku reservations).
- The Dokku commands `run`, `enter`, and `logs:failed` are not supported.
- A custom nginx configuration - or a different proxy plugin implementation - will be needed in order to talk to the Kubernetes `Service` upstream.
- Custom docker-options are not supported.
