set -euo pipefail
set -x

# delete riff/knative resources
kubectl delete riff --all-namespaces --all || true
kubectl delete knative --all-namespaces --all || true

# riff streaming runtime
kapp delete -y -n apps -a riff-streaming-runtime

# riff knative runtime
kapp delete -y -n apps -a riff-knative-runtime

# contour
kapp delete -y -n apps -a contour

# build
kapp delete -y -n apps -a riff-build

# cert-manager
kapp delete -y -n apps -a cert-manager

# namespace
apps=$(kapp -n apps list | grep ' apps')
if [ "$apps" = "0 apps" ]; then
  echo "Deleting apps namespace"
  kubectl delete ns apps || true
else
  echo "Leaving 'apps' namespace since there are still some kapp apps: $apps"
fi

# postgresql
helm delete inventory-db --namespace postgresql || true
kubectl delete namespace postgresql || true

# kafka
helm delete kafka --namespace kafka || true
kubectl delete namespace kafka || true

# riff-dev
kubectl delete pod riff-dev --namespace=default || true
kubectl delete rolebinding riff-dev-edit --namespace=default || true
kubectl delete serviceaccount riff-dev --namespace=default || true
