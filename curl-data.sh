set -euo pipefail
set -x

ingress=$(kubectl get svc/istio-ingressgateway -n istio-system -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ "$ingress" = "" ]; then
  ingress=$(kubectl get svc/istio-ingressgateway -n istio-system -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi
if [ "$ingress" = "" ]; then
  ingress=$(minikube ip)
fi
if [ "$ingress" = "" ]; then
  echo "Couldn't find the Istio ingress gateway :("
  exit
fi
while read line; do curl -i -X POST -H "Content-Type:application/json" -H "Host: inventory-api.default.example.com" --data "$line" ${ingress}/api/article; done < $1
exit
