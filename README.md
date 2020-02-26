# Projectriff Shopping Demo

In this demo we will build a music store ecommerce application by using project riff. The high level architecture of this demo is as follows:

![riff-demo-architecture](images/riff-demo-2.png)

## Initial Setup

### Software prerequisites

Have the following installed:

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) version v1.15 or later
- [kapp](https://github.com/k14s/kapp#kapp) version v0.15.0 or later
- [ytt](https://github.com/k14s/ytt#ytt-yaml-templating-tool) version v0.22.0 or later
- [helm](https://github.com/helm/helm#install) Helm 3

### Install riff CLI

You need the latest [riff CLI](https://github.com/projectriff/cli/). You can run the following commands to download the latest snapshot executable archive for your OS, extract the executable and then place it on your path.

#### Download and extract the riff CLI executable

For macOS:

```
wget https://storage.googleapis.com/projectriff/riff-cli/releases/v0.6.0-snapshot/riff-darwin-amd64.tgz
tar xvzf riff-darwin-amd64.tgz
rm riff-darwin-amd64.tgz
```

for Linux:

```
wget https://storage.googleapis.com/projectriff/riff-cli/releases/v0.6.0-snapshot/riff-linux-amd64.tgz
tar xvzf riff-linux-amd64.tgz
rm riff-linux-amd64.tgz
```

#### Move the riff CLI executable to your PATH

```
sudo mv ./riff /usr/local/bin/riff
```

### Kubernetes cluster

Follow the riff instructions for:

- [GKE](https://projectriff.io/docs/latest/getting-started/gke)
- [Minikube](https://projectriff.io/docs/latest/getting-started/minikube)
- [Docker Desktop](https://projectriff.io/docs/latest/getting-started/docker-for-mac)

### Install NGINX Ingress Controller for a local cluster

On local clusters that don't provide support for `LoadBalancer` services we need to enable NGINX Ingress Controller so we can access the service URLs without specifying the node port for the Contour ingress gateway.

#### NGINX Ingress on Docker Desktop

> NOTE: We are taking advantage of Docker Desktop supporting a single `LoadBalancer` service and exposing that on port 80 on `localhost`. To be able to use this feature it requires that you don't already have a service running on this port.

Install NGINX Ingress using Helm 3:

```
helm repo add stable https://storage.googleapis.com/kubernetes-charts
kubectl create namespace nginx-ingress
helm install nginx-ingress --namespace nginx-ingress stable/nginx-ingress --wait
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

### Install riff demo

Install riff with Knative and Streaming runtimes plus their dependencies. Also installs Kafka and PostgreSQL using helm charts.

Download the installation script:

```
wget https://raw.githubusercontent.com/projectriff-demo/demo/symposium/riff-demo-install.sh
chmod +x riff-demo-install.sh
```

Run the installation for the Kubernetes cluster that `.kube/config` is pointing to:

For GKE run:

```
./riff-demo-install.sh
```

For Docker Desktop or Minikube run:

```
./riff-demo-install.sh --node-port
```

### Add Docker Hub credentials for builds

```
DOCKER_USER=$USER
riff credentials apply docker-push --docker-hub $DOCKER_USER --set-default-image-prefix
```

### Create the Kafka gateway

```
riff streaming kafka-gateway create franz --bootstrap-servers kafka.kafka:9092 --tail
```

## Run the demo

#### Look up ingress

For GKE:

```
export INGRESS=$(kubectl get svc/envoy-external -n projectcontour -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
```

For Docker Desktop:

```
export INGRESS=$(kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

For Minikube:

```
export INGRESS=$(minikube ip)
```

### Build inventory-api app

For build instruction see: https://github.com/projectriff-demo/inventory-management/blob/master/README.md

We have a pre-built image available as `projectriffdemo/inventory-api` and will use that for these instructions.

```
riff container create inventory-api --image projectriffdemo/inventory-api:latest
```

### Deploy inventory-api service

```
riff knative deployer create inventory-api --container-ref inventory-api \
  --min-scale 1 \
  --ingress-policy External \
  --env SPRING_PROFILES_ACTIVE=cloud \
  --env SPRING_DATASOURCE_URL=jdbc:postgresql://inventory-db-postgresql:5432/inventory \
  --env SPRING_DATASOURCE_USERNAME=postgres \
  --env-from SPRING_DATASOURCE_PASSWORD=secretKeyRef:inventory-db-postgresql:postgresql-password \
  --tail
```

### Load some test data

We set the `INGRESS` variable previously and  we can issue curl commands to access the api and add some articles:

```
curl -i -X POST -H "Content-Type:application/json" -H "Host: inventory-api.default.example.com" ${INGRESS}/api/article --data '{"sku" : "12345-00001", "name" : "Trumpet", "description" : "A fine musical instrument, perfect for playing Jazz riffs.", "priceInUsd" : 545, "imageUrl" : "https://free-images.com/tn/4fa5/trumpet_music_brass_orchestra.jpg", "quantity" : 3}'
curl -i -X POST -H "Content-Type:application/json" -H "Host: inventory-api.default.example.com" ${INGRESS}/api/article --data '{"sku" : "12345-00002", "name" : "Guitar", "description" : "A nice guitar, great for riffing.", "priceInUsd" : 315, "imageUrl" : "https://free-images.com/sm/1b40/guitar_electric_guitar_music.jpg", "quantity" : 7}'
curl -i -X POST -H "Content-Type:application/json" -H "Host: inventory-api.default.example.com" ${INGRESS}/api/article --data '{"sku" : "12345-00003", "name" : "Drums", "description" : "A good set of drums for riffing with your buddies.", "priceInUsd" : 229, "imageUrl" : "https://free-images.com/sm/c7b2/drums_music_cymbal_brass.jpg", "quantity" : 2 }'
```

### Access inventory-api service

We set the `INGRESS` variable previously and  we can issue curl command to access the api to list the inventory:

```
curl ${INGRESS}/api/article -H "Host: inventory-api.default.example.com" -H 'Accept: application/json' && echo
```

### The shopping streams

#### Create three streams

```
riff streaming stream create cart-events --gateway franz --content-type 'application/json'
riff streaming stream create checkout-events --gateway franz --content-type 'application/json'
riff streaming stream create orders --gateway franz --content-type application/json
```

#### Create an events-api HTTP source

Create a `container` resource using the HTTP Source image:

```
riff container create http-source --image 'gcr.io/projectriff/http-source/github.com/projectriff/http-source/cmd:0.1.0-snapshot-20191127171015-8b9d7934ec77a183'
```

Lookup the gateway name for the kafka-gateway:

```
gateway=$(kubectl get svc --no-headers -o custom-columns=NAME:.metadata.name \
  -l streaming.projectriff.io/kafka-gateway=franz)
```

Once we have the `gateway` variable set, we can create the HTTP source:

```
riff knative deployer create events-api --container-ref http-source \
  --min-scale 1 \
  --ingress-policy External \
  --env OUTPUTS=/cart-events=${gateway}:6565/default_cart-events,/checkout-events=${gateway}:6565/default_checkout-events \
  --env OUTPUT_CONTENT_TYPES=application/json,application/json \
  --tail
```

### Build storefront app

For build instruction see: https://github.com/projectriff-demo/storefront/blob/master/README.md

We have a pre-built image available as `projectriffdemo/storefront` and will use that for these instructions.

```
riff container create storefront --image projectriffdemo/storefront:latest
```

### Deploy storefront service

```
riff knative deployer create storefront --container-ref storefront \
  --target-port 4200 \
  --min-scale 1 \
  --ingress-policy External \
  --tail
```

Add an entry in `/etc/hosts` for `storefront.default.example.com`.

Enter the IP address for the entry based on the following:

For GKE:

```
kubectl get svc/envoy-external -n projectcontour -ojsonpath='{.status.loadBalancer.ingress[0].ip}' && echo
```

For Docker Desktop:

`127.0.0.1`


For Minikube:

```
minikube ip
```

### Build cart processing function

For build instruction see: https://github.com/projectriff-demo/cart-processor/blob/master/README.md

We have a pre-built image available as `projectriffdemo/cart` and will use that for these instructions.

```
riff container create cart --image projectriffdemo/cart:latest
```

### Create a stream processor for the cart

```
riff streaming processor create cart \
  --container-ref cart \
  --input cart-events \
  --input checkout-events \
  --output orders \
  --tail
```

### Watch the orders stream

We make use of a `dev-utils` pod named `riff-dev` that was installed by the script.

Subscribe to the orders:

```
kubectl exec riff-dev -it -- subscribe orders --payload-encoding raw
```
> Hit `ctrl-c` to stop subscribing

### Go shopping!

Open http://storefront.default.example.com in your browser.

## Some additional functions to experiment with

- [trend-detector](trend-detector.md)
- [no-buy-detector](no-buy-detector.md)

## Manually testing streams and events-api

See the [Manually testing streams and events-api](manual-test.md)
