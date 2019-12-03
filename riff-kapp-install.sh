set -euo pipefail
set -x

# version and namespace
riff_version=0.5.0-snapshot
kubectl create ns apps || true

# check for '--node-port'
# check for '--node-port'
if [ ${1-Missing} = "Missing" ]; then
  type="LoadBalancer"
else
  if [ ${1} = "--node-port" ]; then
    type="NodePort"
  else
    echo "Invalid flag: $1"
	exit 1
  fi
fi

# build
kapp deploy -y -n apps -a cert-manager -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/cert-manager.yaml
kapp deploy -y -n apps -a kpack -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/kpack.yaml
kapp deploy -y -n apps -a riff-builders -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/riff-builders.yaml
kapp deploy -y -n apps -a riff-build -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/riff-build.yaml

# istio -- use '--node-port' for clusters that don't support LoadBalancer 
if [ $type = "NodePort" ]; then
  echo "Installing Istio with NodePort"
  ytt -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/istio.yaml -f https://storage.googleapis.com/projectriff/charts/overlays/service-nodeport.yaml --file-mark istio.yaml:type=yaml-plain | kapp deploy -n apps -a istio -f - -y
else
  echo "Installing Istio with LoadBalancer"
  kapp deploy -y -n apps -a istio -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/istio.yaml
fi

# riff core runtime
kapp deploy -y -n apps -a riff-core-runtime -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/riff-core-runtime.yaml

# riff knative runtime
kapp deploy -y -n apps -a knative -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/knative.yaml
kapp deploy -y -n apps -a riff-knative-runtime -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/riff-knative-runtime.yaml

# riff streaming runtime
kapp deploy -y -n apps -a keda -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/keda.yaml
kapp deploy -y -n apps -a riff-streaming-runtime -f https://storage.googleapis.com/projectriff/charts/uncharted/${riff_version}/riff-streaming-runtime.yaml
