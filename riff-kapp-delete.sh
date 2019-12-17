set -euo pipefail
set -x

# delete riff/knative resources
kubectl delete riff --all-namespaces --all || true
kubectl delete knative --all-namespaces --all || true

# riff streaming runtime
kapp delete -y -n apps -a riff-streaming-runtime
kapp delete -y -n apps -a keda

# kafka
kapp delete -y -n apps -a kafka

# riff knative runtime
kapp delete -y -n apps -a riff-knative-runtime
kapp delete -y -n apps -a knative

# riff core runtime
kapp delete -y -n apps -a riff-core-runtime

# istio
kapp delete -y -n apps -a istio
kubectl get customresourcedefinitions.apiextensions.k8s.io -oname | grep istio.io | xargs -L1 kubectl delete || true

# build
kapp delete -y -n apps -a riff-builders
kapp delete -y -n apps -a riff-build
kapp delete -y -n apps -a kpack

# cert-manager
kapp delete -y -n apps -a cert-manager

# namespace
kubectl delete ns apps || true
