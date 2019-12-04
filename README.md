# Projectriff Shopping Demo

## Initial Setup

### Software prerequisites

Have the following installed:

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) version v1.15 or later
- [kapp](https://github.com/k14s/kapp#kapp) version v0.15.0 or later
- [ytt](https://github.com/k14s/ytt#ytt-yaml-templating-tool) version v0.22.0 or later
- [helm](https://github.com/helm/helm#install) Helm v2, recommend using v2.16.1 or later

### Install riff CLI

You need the latest [riff CLI](https://github.com/projectriff/cli/). You can run the following commands to download the latest snapshot executable archive for your OS, extract the executable and then place it on your path.

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

#### Access inventory-api service

Once we have the `ingress` variable set, we can issue curl command to access the api:

```
curl ${ingress}/api/article -H "Host: inventory-api.default.example.com" -H 'Accept: application/json' && echo
```

### Add a new article

To add a new article to the inventory run the following:

```
./curl-data.sh data/new-article-flute.json
```

### The shopping streams

#### Create two streams

```
riff streaming stream create cart-events --provider franz-kafka-provisioner --content-type 'application/json'
riff streaming stream create checkout-events --provider franz-kafka-provisioner --content-type 'application/json'
```

#### Create an events-api HTTP source

Create a `container` resource using the HTTP Source image:

```
riff container create http-source --image 'gcr.io/projectriff/http-source/github.com/projectriff/http-source/cmd:0.1.0-snapshot-20191127171015-8b9d7934ec77a183@sha256:1f9a771b43b2a1c56580761e2bdd51c5dd56dc58f3d8d7583b75185ce01f83b0'
```

Lookup the gateway for the kafka-provider:

```
gateway=$(kubectl get svc --no-headers -o custom-columns=NAME:.metadata.name \
  -l streaming.projectriff.io/kafka-provider-gateway=franz)  
```

Once we have the `gateway` variable set, we can create the HTTP source:

```
riff core deployer create events-api --container-ref http-source \
  --ingress-policy External \
  --env OUTPUTS=/cart-events=${gateway}:6565/default_cart-events,/checkout-events=${gateway}:6565/default_checkout-events \
  --env OUTPUT_CONTENT_TYPES=application/json,application/json \
  --tail
```

### Build storefront app

For build instruction see: https://github.com/projectriff-demo/storefront/blob/master/README.md

We have a pre-built image available as `projectriff/storefront` and will use that for these instructions.

```
riff container create storefront --image projectriff/storefront:v002
```

### Deploy storefront service

```
riff core deployer create storefront --container-ref storefront \
  --target-port 4200 \
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

### Go shopping!

Open http://storefront.default.example.com in your browser.

### Manually test streams and events-api

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

#### Send some data

Once we have the `ingress` variable set, we can issue curl command to post data to the HTTP sources:

First the `cart-events-source`:

```
curl ${ingress}/cart-events -H "Host: events-api.default.example.com" -H 'Content-Type: application/json' -d "{\"action\":\"add\",\"sku\":\"12345-00002\",\"newCart\":{\"items\":[{\"sku\":\"12345-00002\",\"name\":\"Guitar\",\"description\":\"A nice guitar, great for riffing.\",\"priceInUsd\":315,\"quantity\":7,\"imageUrl\":\"https://free-images.com/sm/1b40/guitar_electric_guitar_music.jpg\",\"inCart\":1}]}}"
curl ${ingress}/cart-events -H "Host: events-api.default.example.com" -H 'Content-Type: application/json' -d "{\"action\":\"add\",\"sku\":\"12345-00001\",\"newCart\":{\"items\":[{\"sku\":\"12345-00002\",\"name\":\"Guitar\",\"description\":\"A nice guitar, great for riffing.\",\"priceInUsd\":315,\"quantity\":7,\"imageUrl\":\"https://free-images.com/sm/1b40/guitar_electric_guitar_music.jpg\",\"inCart\":1},{\"sku\":\"12345-00001\",\"name\":\"Trumpet\",\"description\":\"A fine musical instrument, perfect for playing Jazz riffs.\",\"priceInUsd\":545,\"quantity\":3,\"imageUrl\":\"https://free-images.com/tn/4fa5/trumpet_music_brass_orchestra.jpg\",\"inCart\":1}]}}"
curl ${ingress}/cart-events -H "Host: events-api.default.example.com" -H 'Content-Type: application/json' -d "{\"action\":\"remove\",\"sku\":\"12345-00001\",\"newCart\":{\"items\":[{\"sku\":\"12345-00002\",\"name\":\"Guitar\",\"description\":\"A nice guitar, great for riffing.\",\"priceInUsd\":315,\"quantity\":7,\"imageUrl\":\"https://free-images.com/sm/1b40/guitar_electric_guitar_music.jpg\",\"inCart\":1}]}}"
```

#### Check the events published on the cart-events stream

##### Run dev-utils pod

```
kubectl create serviceaccount dev-utils --namespace default
kubectl create rolebinding dev-utils --namespace default --clusterrole=view --serviceaccount=default:dev-utils
kubectl run dev-utils --image=projectriff/dev-utils:latest --generator=run-pod/v1 --serviceaccount=dev-utils
```

##### Subscribe to streams

Subscribe to the cart-events:

```
kubectl exec dev-utils -n default -- subscribe cart-events -n default --payload-as-string
```

Hit `ctrl-c` to stop subscribing
