# Projectriff Shopping Demo

## Trend detector function

First install [riff and the shopping demo](README.md)

### Install Redis

```
helm install --name count --namespace default --set usePassword=false stable/redis
```

#### Create the trends stream

```
riff streaming stream create trends --provider franz-kafka-provisioner --content-type 'application/json'
```

### Build the trend-detector function

```
riff function create trends \
  --git-repo https://github.com/projectriff-demo/trend-detector.git \
  --artifact func.js \
  --tail
```

### Create a stream processor for the trend-detector

Use this command to create the processor:

```
riff streaming processor create trends \
  --function-ref trends \
  --input orders \
  --output trends \
  --tail
```

### Watch the trends stream

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
kubectl exec dev-utils -n default -- subscribe trends -n default --payload-as-string
```

#### When you're done watching the trends stream

> Hit `ctrl-c` to stop subscribing

Kill the subscription:

```
kubectl exec dev-utils -- sh -c 'kill $(pidof subscribe)'
```
