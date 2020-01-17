set -euo pipefail
set -x

# version
riff_version=0.5.0-snapshot

# borrowed from fats https://github.com/projectriff/fats/blob/master/.util.sh
# derived from https://github.com/travis-ci/travis-build/blob/4f580b238530108cdd08719c326cd571d4e7b99f/lib/travis/build/bash/travis_retry.bash
# MIT licenced https://github.com/travis-ci/travis-build/blob/4f580b238530108cdd08719c326cd571d4e7b99f/LICENSE
retry() {
  local result=0
  local count=1
  while [[ "${count}" -le 3 ]]; do
    [[ "${result}" -ne 0 ]] && {
      echo -e "\\n${ANSI_RED}The command \"${*}\" failed. Retrying, ${count} of 3.${ANSI_RESET}\\n" >&2
    }
    "${@}" && { result=0 && break; } || result="${?}"
    count="$((count + 1))"
    sleep 1
  done

  [[ "${count}" -gt 3 ]] && {
    echo -e "\\n${ANSI_RED}The command \"${*}\" failed 3 times.${ANSI_RESET}\\n" >&2
  }

  return "${result}"
}

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
retry kapp deploy -y -n apps -a cert-manager -f https://storage.googleapis.com/projectriff/release/${riff_version}/cert-manager.yaml
kapp deploy -y -n apps -a kpack -f https://storage.googleapis.com/projectriff/release/${riff_version}/kpack.yaml
kapp deploy -y -n apps -a riff-builders -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-builders.yaml
kapp deploy -y -n apps -a riff-build -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-build.yaml

# istio -- use '--node-port' for clusters that don't support LoadBalancer 
if [ $type = "NodePort" ]; then
  echo "Installing Istio with NodePort"
  ytt -f https://storage.googleapis.com/projectriff/release/${riff_version}/istio.yaml -f https://storage.googleapis.com/projectriff/charts/overlays/service-nodeport.yaml --file-mark istio.yaml:type=yaml-plain | kapp deploy -n apps -a istio -f - -y
else
  echo "Installing Istio with LoadBalancer"
  kapp deploy -y -n apps -a istio -f https://storage.googleapis.com/projectriff/release/${riff_version}/istio.yaml
fi

# riff core runtime
kapp deploy -y -n apps -a riff-core-runtime -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-core-runtime.yaml

# riff knative runtime
kapp deploy -y -n apps -a knative -f https://storage.googleapis.com/projectriff/release/${riff_version}/knative.yaml
kapp deploy -y -n apps -a riff-knative-runtime -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-knative-runtime.yaml

# riff streaming runtime
kapp deploy -y -n apps -a keda -f https://storage.googleapis.com/projectriff/release/${riff_version}/keda.yaml
kapp deploy -y -n apps -a riff-streaming-runtime -f https://storage.googleapis.com/projectriff/release/${riff_version}/riff-streaming-runtime.yaml
