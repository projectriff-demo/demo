set -euo pipefail
set -x

ns=$(kubectl get ns nginx-ingress -oname) || true
echo $ns

host=$(kubectl get deployer.core inventory-api -ojsonpath={.status.serviceName})
if [ "$ns" = "" ]; then
  ingress=$(minikube ip)
else
  ingress=$(kubectl get svc/nginx-ingress-controller -n nginx-ingress -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
fi
while read line; do curl -i -X POST -H "Content-Type:application/json" -H "Host: ${host}.default.example.com" --data "$line" ${ingress}/api/article; done < $1
exit
