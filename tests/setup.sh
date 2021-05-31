#!/usr/bin/env bash
set -eo pipefail
[[ $TRACE ]] && set -x
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 762E3157
echo "deb http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -

sudo mkdir -p /etc/nginx
sudo curl https://raw.githubusercontent.com/dokku/dokku/master/tests/dhparam.pem -o /etc/nginx/dhparam.pem

echo "dokku dokku/skip_key_file boolean true" | sudo debconf-set-selections
curl -sfL -o /tmp/bootstrap.sh https://raw.githubusercontent.com/dokku/dokku/master/bootstrap.sh
if [[ "$DOKKU_VERSION" == "master" ]]; then
  sudo bash /tmp/bootstrap.sh
else
  sudo DOKKU_TAG="$DOKKU_VERSION" bash /tmp/bootstrap.sh
fi
echo "Dokku version $DOKKU_VERSION"

export DOKKU_LIB_ROOT="/var/lib/dokku"
export DOKKU_PLUGINS_ROOT="$DOKKU_LIB_ROOT/plugins/available"
source "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/config"
sudo rm -rf "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX"
sudo mkdir -p "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX" "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX/subcommands" "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX/scripts" "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX/templates"
sudo find ./ -maxdepth 1 -type f -exec cp '{}' "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX" \;
[[ -d "./scripts" ]] && sudo find ./scripts -maxdepth 1 -type f -exec cp '{}' "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX/scripts" \;
[[ -d "./subcommands" ]] && sudo find ./subcommands -maxdepth 1 -type f -exec cp '{}' "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX/subcommands" \;
[[ -d "./templates" ]] && sudo find ./templates -maxdepth 1 -type f -exec cp '{}' "$DOKKU_PLUGINS_ROOT/$PLUGIN_COMMAND_PREFIX/templates" \;
sudo mkdir -p "$PLUGIN_CONFIG_ROOT" "$PLUGIN_DATA_ROOT"
sudo dokku plugin:enable "$PLUGIN_COMMAND_PREFIX"
sudo dokku plugin:install

## k3s testing setup

# install the registry dependency
# TODO: use a `plugn` command
sudo dokku plugin:install git://github.com/dokku/dokku-registry.git registry

# install k3s
curl -sfL -o /tmp/k3s.sh https://get.k3s.io
sudo sh /tmp/k3s.sh

# setup kube config for dokku user
sudo mkdir -p /home/dokku/.kube
sudo cp -f /etc/rancher/k3s/k3s.yaml /home/dokku/.kube/config
sudo chown -R dokku:dokku /home/dokku/.kube

# ensure we can access the registry locally
# TODO: run the registry locally somehow
if [[ -n "$DOCKERHUB_USERNAME" ]] && [[ -n "$DOCKERHUB_PASSWORD" ]]; then
  export KUBECONFIG=/home/dokku/.kube/config
  sudo kubectl delete secret registry-credential || true
  sudo dokku registry:login docker.io "$DOCKERHUB_USERNAME" "$DOCKERHUB_PASSWORD"
  sudo kubectl create secret generic registry-credential \
      --from-file=.dockerconfigjson=/home/dokku/.docker/config.json \
      --type=kubernetes.io/dockerconfigjson
else
  echo "Dockerhub username or password missing, skipping login to registry"
fi
