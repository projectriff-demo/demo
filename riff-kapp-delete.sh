set -euo pipefail
set -x

# delete riff/knative resources
kubectl delete riff --all-namespaces --all || true
kubectl delete knative --all-namespaces --all || true

# riff streaming runtime
kapp delete -y -n apps -a riff-streaming-runtime
kapp delete -y -n apps -a keda

# riff knative runtime
kapp delete -y -n apps -a riff-knative-runtime
kapp delete -y -n apps -a knative

# contour
kapp delete -y -n apps -a contour

# build
kapp delete -y -n apps -a riff-builders
kapp delete -y -n apps -a riff-build
kapp delete -y -n apps -a kpack

# cert-manager
kapp delete -y -n apps -a cert-manager

# namespace
kubectl delete ns apps || true
