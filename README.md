# Projectriff Shopping Demo

## Initial Setup

### Software prerequisites

Have the following installed:

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) version v1.15 or later
- [kapp](https://github.com/k14s/kapp#kapp) version v0.15.0 or later
- [ytt](https://github.com/k14s/ytt#ytt-yaml-templating-tool) version v0.22.0 or later
- [helm](https://github.com/helm/helm#install) Helm v2, recommend using v2.16.1 or later

### Install riff CLI

You need the latest [riff CLI](https://github.com/projectriff/cli/). You can run the following and then place the executable on your path.

For macOS:

```
wget https://storage.googleapis.com/projectriff/riff-cli/releases/v0.5.0-snapshot/riff-darwin-amd64.tgz
tar xvzf riff-darwin-amd64.tgz
rm riff-darwin-amd64.tgz
sudo mv ./riff /usr/local/bin/riff
```

for Linux:

```
wget https://storage.googleapis.com/projectriff/riff-cli/releases/v0.5.0-snapshot/riff-linux-amd64.tgz
tar xvzf riff-linux-amd64.tgz
rm riff-linux-amd64.tgz
sudo mv ./riff /usr/local/bin/riff
```

### Kubernetes cluster

Follow the riff instructions for:

- [GKE](https://projectriff.io/docs/v0.5/getting-started/gke)
- [Minikube](https://projectriff.io/docs/v0.5/getting-started/minikube)

> NOTE: kapp can't install keda on a Kubernetes cluster running version 1.16 so we need to force the Kubernetes version to be 1.14 or 1.15

### Initialize the Helm Tiller server in your cluster

```
kubectl create serviceaccount tiller -n kube-system
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount kube-system:tiller
helm init --wait --service-account tiller
```

### Install NGINX Ingress Controller

On GKE:

```
helm install --name nginx-ingress --namespace nginx-ingress stable/nginx-ingress --wait
```

The NGINX ingress controller is exposed as LoadBalancer with external IP address


On Minikube:

```
minikube addons enable ingress
```

The NGINX ingress controller is exposed on port 80 on the minikube ip address

### Clone the demo repo

Clone this repo:

```
git clone https://github.com/projectriff-demo/demo.git
cd demo
```

### Install riff

Install riff and all dependent packages including cert-manager, kpack, keda, riff-build, istio and core, knative and streaming runtimes

### Add Docker Hub credentials for builds

```
DOCKER_USER=$USER
riff credentials apply docker-push --docker-hub $DOCKER_USER --set-default-image-prefix
```

## Run the demo

### Install inventory database

```
helm install --name inventory-db --namespace default --set postgresqlDatabase=inventory stable/postgresql
```

### Build inventory-api app

```
riff app create inventory-api --git-repo https://github.com/projectriff-demo/inventory-management.git
```

### Deploy inventory-api service

```
riff core deployer create inventory-api --application-ref inventory-api \
  --service-name inventory-api \
  --env SPRING_PROFILES_ACTIVE=cloud \
  --env SPRING_DATASOURCE_URL=jdbc:postgresql://inventory-db-postgresql:5432/inventory \
  --env SPRING_DATASOURCE_USERNAME=postgres \
  --env-from SPRING_DATASOURCE_PASSWORD=secretKeyRef:inventory-db-postgresql:postgresql-password
```

### Load some test data

```
./curl-data.sh data/sample-data.json
```

### Access inventory-api service

For GKE:

```
host=$(kubectl get deployer.core inventory-api -ojsonpath={.status.serviceName})
ingress=$(kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
curl ${ingress}/api/article -H "Host: ${host}.default.example.com" -H 'Accept: application/json' ; echo
```

For Minikube:

```
host=$(kubectl get deployer.core inventory-api -ojsonpath={.status.serviceName})
ingress=$(minikube ip)
curl ${ingress}/api/article -H "Host: ${host}.default.example.com" -H 'Accept: application/json' ; echo
```

### Build inventory-gui app

For build instruction see: https://github.com/projectriff-demo/inventory-management/blob/master/README.md#frontend

We have a pre-built image available as `projectriff/inventory-gui` and will use that for these instructions.

```
riff container create inventory-gui --image projectriff/inventory-gui
```

### Deploy inventory-gui service

```
riff core deployer create inventory-gui --container-ref inventory-gui --container-port 4200 --service-name inventory-gui
```

Add an entry in `/etc/hosts` for `http://inventory-gui.default.example.com`.

Enter the IP address for the entry based on the following:

For GKE:

```
kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].ip}'
```

For Minikube:

```
minikube ip
```

### Build storefront app

For build instruction see: https://github.com/projectriff-demo/storefront/blob/master/README.md

We have a pre-built image available as `projectriff/storefront` and will use that for these instructions.

```
riff container create storefront --image projectriff/storefront
```

### Deploy storefront service

```
riff core deployer create storefront --container-ref storefront --container-port 4200 --service-name storefront
```

Add an entry in `/etc/hosts` for `http://storefront.default.example.com`.

Enter the IP address for the entry based on the following:

For GKE:

```
kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].ip}'
```

For Minikube:

```
minikube ip
```
