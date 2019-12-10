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

> NOTE: If you delete the database using `helm delete --purge inventory-db` then you also need to clear the persistent volume claim for the database, or you won't be able to log in if you create a new database instance with the same name.
>
> Delete the PVC with `kubectl delete pvc data-inventory-db-postgresql-0`.

### Create kafka-provider

```
riff streaming kafka-provider create franz --bootstrap-servers kafka.kafka:9092
```

### Build inventory-api app

For build instruction see: https://github.com/projectriff-demo/inventory-management/blob/master/README.md

We have a pre-built image available as `projectriffdemo/inventory-api` and will use that for these instructions.

```
riff container create inventory-api --image projectriffdemo/inventory-api:v001
```

### Deploy inventory-api service

```
riff core deployer create inventory-api --container-ref inventory-api \
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

#### Create three streams

```
riff streaming stream create cart-events --provider franz-kafka-provisioner --content-type 'application/json'
riff streaming stream create checkout-events --provider franz-kafka-provisioner --content-type 'application/json'
riff streaming stream create orders --provider franz-kafka-provisioner --content-type application/json
```

#### Create an events-api HTTP source

Create a `container` resource using the HTTP Source image:

```
riff container create http-source --image 'gcr.io/projectriff/http-source/github.com/projectriff/http-source/cmd:0.1.0-snapshot-20191127171015-8b9d7934ec77a183'
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

We have a pre-built image available as `projectriffdemo/storefront` and will use that for these instructions.

```
riff container create storefront --image projectriffdemo/storefront:v005
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

### Build cart processing function

```
riff function create cart \
  --git-repo https://github.com/projectriff-demo/cart-processor.git \
  --handler io.projectriff.cartprocessor.CartProcessor \
  --tail
```

### Create a stream processor for the cart

If you built the function yourself, then use this command to create the processor:

```
riff streaming processor create cart \
  --function-ref cart \
  --input cart-events \
  --input checkout-events \
  --output orders \
  --tail
```

If you didn't build the function, then can you use a pre-built image available as `projectriffdemo/cart`:

```
riff container create cart --image projectriffdemo/cart:v002
riff streaming processor create cart \
  --container-ref cart \
  --input cart-events \
  --input checkout-events \
  --output orders \
  --tail
```

> NOTE: If there are issues with processor scaling then you can use a plain Deployment resource instead of the riff Streaming Processor. Use the command below:

```
kubectl apply -f https://raw.githubusercontent.com/projectriff-demo/demo/master/deployment-cart-processor.yaml
```

### Watch the orders stream

Set up service account (skip if you already have this configured)

```
kubectl create serviceaccount dev-utils --namespace default
kubectl create rolebinding dev-utils --namespace default --clusterrole=view --serviceaccount=default:dev-utils
```

Run dev-utils pod:

```
kubectl run dev-utils --image=projectriff/dev-utils:latest --generator=run-pod/v1 --serviceaccount=dev-utils
```

Subscribe to the orders:

```
kubectl exec dev-utils -n default -- subscribe orders -n default --payload-as-string
```

#### When you're done watching the orders stream

> Hit `ctrl-c` to stop subscribing

Kill the subscription:

```
kubectl exec dev-utils -- sh -c 'kill $(pidof subscribe)'
```

### Go shopping!

Open http://storefront.default.example.com in your browser.

## Some additional functions to experiment with

- [trend-detector](trend-detector.md)

## Manually testing streams and events-api

See the [Manually testing streams and events-api](manual-test.md)
