# Projectriff Shopping Demo

## Initial Setup

### Software prerequisites

Have the following installed:

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) version v1.15 or later
- [kapp](https://github.com/k14s/kapp#kapp) version v0.15.0 or later
- [ytt](https://github.com/k14s/ytt#ytt-yaml-templating-tool) version v0.22.0 or later
- [helm](https://github.com/helm/helm#install) Helm v2, recommend using v2.16.1 or later

### Install riff CLI

You need the latest [riff CLI](https://github.com/projectriff/cli/). You can run the following commands to download the latest snapshot executable archive for your OS, extract executable and then place it on your path.

#### Download and extract the riff CLI executable

For macOS:

```
wget https://storage.googleapis.com/projectriff/riff-cli/releases/v0.5.0-snapshot/riff-darwin-amd64.tgz
tar xvzf riff-darwin-amd64.tgz
rm riff-darwin-amd64.tgz
```

for Linux:

```
wget https://storage.googleapis.com/projectriff/riff-cli/releases/v0.5.0-snapshot/riff-linux-amd64.tgz
tar xvzf riff-linux-amd64.tgz
rm riff-linux-amd64.tgz
```

#### Move the riff CLI executable to your PATH

```
sudo mv ./riff /usr/local/bin/riff
```

### Kubernetes cluster

Follow the riff instructions for:

- [GKE](https://projectriff.io/docs/v0.5/getting-started/gke)
- [Minikube](https://projectriff.io/docs/v0.5/getting-started/minikube)
- [Docker Desktop](https://projectriff.io/docs/v0.5/getting-started/docker-for-mac)

> NOTE: kapp can't install keda on a Kubernetes cluster running version 1.16 so we need to force the Kubernetes version to be 1.14 or 1.15

### Initialize the Helm Tiller server in your cluster

```
kubectl create serviceaccount tiller -n kube-system
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount kube-system:tiller
helm init --wait --service-account tiller
```

### Install NGINX Ingress Controller

#### NGINX Ingress on GKE or Docker Desktop

Install NGINX Ingress using:

```
helm install --name nginx-ingress --namespace nginx-ingress stable/nginx-ingress --wait
```

The NGINX ingress controller is exposed as LoadBalancer with external IP address. For "Docker Desktop" it should be exposed on port 80 on `localhost`.

Run the following to verify:

```
kubectl get services --namespace nginx-ingress
```

#### NGINX Ingress on Minikube

Install NGINX Ingress using:

```
minikube addons enable ingress
```

The NGINX ingress controller is exposed on port 80 on the minikube ip address

### Clone the demo repo

Clone this repo:

```
git clone https://github.com/projectriff-demo/demo.git riff-shopping-demo
cd riff-shopping-demo
```

### Install riff

Install riff and all dependent packages including cert-manager, kpack, keda, kafka, riff-build, istio and core, knative and streaming runtimes.

For a cluster that supports LoadBalancer use:

```
./riff-kapp-install.sh
```

For a cluster like "Minikube" or "Docker Desktop" that doesn't support LoadBalancer use:

```
./riff-kapp-install.sh --node-port
```

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

### Create kafka-provider

```
riff streaming kafka-provider create franz --bootstrap-servers kafka.kafka:9092
```

### Build inventory-api app

```
riff app create inventory-api --git-repo https://github.com/projectriff-demo/inventory-management.git --tail
```

### Deploy inventory-api service

```
riff core deployer create inventory-api --application-ref inventory-api \
  --service-name inventory-api \
  --ingress-policy External \
  --env SPRING_PROFILES_ACTIVE=cloud \
  --env SPRING_DATASOURCE_URL=jdbc:postgresql://inventory-db-postgresql:5432/inventory \
  --env SPRING_DATASOURCE_USERNAME=postgres \
  --env-from SPRING_DATASOURCE_PASSWORD=secretKeyRef:inventory-db-postgresql:postgresql-password \
  --tail
```

### Load some test data

```
./curl-data.sh data/sample-data.json
```

### Access inventory-api service

#### Look up ingress

For GKE:

```
ingress=$(kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
```

For Docker Desktop:

```
ingress=$(kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

For Minikube:

```
ingress=$(minikube ip)
```

#### Look up host and access api service

Once we have the `ingress` variable set, we can look up the host for the app and issue curl command to access the api:

```
host=$(kubectl get deployer.core inventory-api -ojsonpath={.status.serviceName})
curl ${ingress}/api/article -H "Host: ${host}.default.example.com" -H 'Accept: application/json' && echo
```

### Build storefront app

For build instruction see: https://github.com/projectriff-demo/storefront/blob/master/README.md

We have a pre-built image available as `projectriff/storefront` and will use that for these instructions.

```
riff container create storefront --image projectriff/storefront
```

### Deploy storefront service

```
riff core deployer create storefront --container-ref storefront \
  --target-port 4200 \
  --service-name storefront \
  --ingress-policy External \
  --tail
```

Add an entry in `/etc/hosts` for `http://storefront.default.example.com`.

Enter the IP address for the entry based on the following:

For GKE:

```
kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].ip}' && echo
```

For Docker Desktop:

`127.0.0.1`


For Minikube:

```
minikube ip && echo
```

### Add a new article

```
./curl-data.sh data/new-article-flute.json
```
