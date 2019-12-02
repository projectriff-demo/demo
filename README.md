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

- [GKE](https://projectriff.io/docs/v0.4/getting-started/gke)
- [Minikube](https://projectriff.io/docs/v0.4/getting-started/minikube)
- [Docker for Mac](https://projectriff.io/docs/v0.4/getting-started/docker-for-mac)

> NOTE: kapp can't install keda on a Kubernetes cluster running version 1.16 so we need to force the Kubernetes version to be 1.14 or 1.15

### Clone the demo repo

Clone this repo:

```
git clone https://github.com/tanzu-mkondo/demo.git
cd demo
```

### Install riff

Install riff and all dependent packages including cert-manager, kpack, keda, riff-build, istio and core, knative and serving runtimes

### Add Docker Hub credentiasl for builds

```
DOCKER_USER=$USER
riff credentials apply docker-push --docker-hub $DOCKER_USER --set-default-image-prefix
```


## Run the demo

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


### Install inventory database

```
helm install --name inventory-db --namespace default --set postgresqlDatabase=inventory stable/postgresql
```

### Build inventory-api app

```
riff app create inventory-api --git-repo https://github.com/tanzu-mkondo/inventory-management.git
```

### Deploy inventory-api service

riff core deployer create inventory-api --application-ref inventory-api \
  --service-name inventory-api \
  --env SPRING_PROFILES_ACTIVE=cloud \
  --env SPRING_DATASOURCE_URL=jdbc:postgresql://inventory-db-postgresql:5432/inventory \
  --env SPRING_DATASOURCE_USERNAME=postgres \
  --env-from SPRING_DATASOURCE_PASSWORD=secretKeyRef:inventory-db-postgresql:postgresql-password

### Load some test data

./curl-data.sh data/sample-data.json

### Access inventory-api service

For GKE:

```
host=$(kubectl get deployer.core inventory-api -ojsonpath={.status.serviceName})
ingress=$(kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
curl ${ingress} -H "Host: ${host}.default.example.com" -H 'Content-Type: text/plain' -H 'Accept: text/plain' -d riff ; echo
```

For Minikube:

```
host=$(kubectl get deployer.core inventory-api -ojsonpath={.status.serviceName})
ingress=$(minikube ip)
curl ${ingress} -H "Host: ${host}.default.example.com" -H 'Content-Type: text/plain' -H 'Accept: text/plain' -d riff ; echo
```
