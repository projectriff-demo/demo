# Projectriff Shopping Demo

## No-buy detector function

First install [riff and the shopping demo](README.md)

#### Create the no-buy stream

```
riff streaming stream create no-buy --provider franz-kafka-provisioner --content-type 'application/json'
```

### Build the no-buy-detector function

```
riff function create no-buy \
  --git-repo https://github.com/projectriff-demo/no-buy-detector.git \
  --handler io.projectriff.cartprocessor.NoBuyDetector \
  --tail
```

### Create a stream processor for the trend-detector

Use this command to create the processor:

```
riff streaming processor create no-buy \
  --function-ref no-buy \
  --input cart-events \
  --input checkout-events \
  --output no-buy \
  --tail
```

### Watch the no-buy stream

Set up service account (skip if you already have this configured)

```
kubectl create serviceaccount dev-utils --namespace default
kubectl create rolebinding dev-utils --namespace default --clusterrole=view --serviceaccount=default:dev-utils
```

Run dev-utils pod:

```
kubectl run dev-utils --image=projectriff/dev-utils:latest --generator=run-pod/v1 --serviceaccount=dev-utils
```

Subscribe to the no-buy events:

```
kubectl exec dev-utils -it -n default -- subscribe no-buy -n default --payload-as-string
```
> Hit `ctrl-c` to stop subscribing
