# Projectriff Shopping Demo

## Manually testing streams and events-api

First install [riff and the shopping demo](README.md)

### Look up ingress

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

### Send some data on the events streams

Once we have the `ingress` variable set, we can issue curl command to post data to the HTTP sources:

For the `cart-events`:

```
curl ${ingress}/cart-events -H "Host: events-api.default.example.com" -H 'Content-Type: application/json' -d '{"user": "demo", "product": "12345-00001", "quantity": 2}'
curl ${ingress}/cart-events -H "Host: events-api.default.example.com" -H 'Content-Type: application/json' -d '{"user": "demo", "product": "12345-00002", "quantity": 1}'
```

For the `ckeckout-events`:

```
curl ${ingress}/checkout-events -H "Host: events-api.default.example.com" -H 'Content-Type: application/json' -d '{"user": "demo"}'
```

### Check the events published on the orders stream

#### Run dev-utils pod

Set up service account (skip if you already have this configured)

```
kubectl create serviceaccount dev-utils --namespace default
kubectl create rolebinding dev-utils --namespace default --clusterrole=view --serviceaccount=default:dev-utils
```

Create dev-utils pod:

```
kubectl run dev-utils --image=projectriff/dev-utils:latest --generator=run-pod/v1 --serviceaccount=dev-utils
```

#### Subscribe to streams

Subscribe to the orders:

```
kubectl exec dev-utils -n default -- subscribe orders -n default --payload-as-string
```

#### Stop the subscription

> Hit `ctrl-c` to stop subscribing

Kill the subscription:

```
kubectl exec dev-utils -- pkill -SIGTERM subscribe
```
