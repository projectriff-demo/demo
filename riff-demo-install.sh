set -euo pipefail
set -x

# version
riff_version=0.6.0-snapshot

# namespace
kubectl create ns apps || true

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
kapp deploy -y -n apps -a cert-manager -f https://storage.googleapis.com/projectriff/release/${riff_version}/cert-manager.yaml
kapp deploy -y -n apps -a riff-build \
  -f https://storage.googleapis.com/projectriff/release/${riff_version}/kpack.yaml \
  -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-builders.yaml \
  -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-build.yaml

# contour -- use '--node-port' for clusters that don't support LoadBalancer 
kapp deploy -y -n apps -a contour -f https://storage.googleapis.com/projectriff/release/${riff_version}/contour.yaml
if [ $type = "NodePort" ]; then
  echo "Patch Contour with NodePort"
  kubectl patch svc -n projectcontour envoy-external --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"}]'
fi

# riff knative runtime
kapp deploy -y -n apps -a riff-knative-runtime \
  -f https://storage.googleapis.com/projectriff/release/${riff_version}/knative.yaml \
  -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-knative-runtime.yaml

# riff streaming runtime
kapp deploy -y -n apps -a riff-streaming-runtime \
  -f https://storage.googleapis.com/projectriff/release/${riff_version}/keda.yaml \
  -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-streaming-runtime.yaml

# postgresql
kubectl create namespace postgresql || true
helm repo add stable https://storage.googleapis.com/kubernetes-charts
helm install inventory-db --namespace postgresql --set postgresqlDatabase=inventory stable/postgresql

# kafka
kubectl create namespace kafka || true
helm repo add incubator https://storage.googleapis.com/kubernetes-charts-incubator
helm install kafka --namespace kafka incubator/kafka --set replicas=1 --set zookeeper.replicaCount=1 --wait

# riff-dev
kubectl create serviceaccount riff-dev --namespace=default
kubectl create rolebinding riff-dev-edit --namespace=default --clusterrole=edit --serviceaccount=default:riff-dev
kubectl run riff-dev --namespace=default --image=projectriff/dev-utils --serviceaccount=riff-dev --generator=run-pod/v1
