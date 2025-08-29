#!/usr/bin/env bash
set -e

ECR_IMAGE="$1"           # passed from CI, full ECR image: <account>.dkr.ecr.../mvp-service:tag
HOSTNAME="$2"            # e.g. app.${ELASTIC_IP}.nip.io

# install docker (if not present)
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y docker.io
  sudo usermod -aG docker ubuntu || true
fi

# install k3s if not installed
if ! command -v kubectl >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | sh -s - --docker
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
fi

# install helm
if ! command -v helm >/dev/null 2>&1; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# login to ECR (assumes instance has IAM role) - else configure awscli
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-central-1.amazonaws.com

# pull image and load to k3s
docker pull "${ECR_IMAGE}"
# tag for local k3s registry format if needed; k3s runs docker so should be available

# prepare k8s manifest replacement
TMP_DIR=/tmp/mvp-k8s
mkdir -p $TMP_DIR
cp -r ~/mvp-repo/k8s/* $TMP_DIR/
sed -i "s#REPLACE_WITH_ECR_URL#${ECR_IMAGE}#g" $TMP_DIR/deployment.yaml
sed -i "s#__HOST_PLACEHOLDER__#${HOSTNAME}#g" $TMP_DIR/ingress.yaml

kubectl apply -f $TMP_DIR/deployment.yaml
kubectl apply -f $TMP_DIR/service.yaml
kubectl apply -f $TMP_DIR/ingress.yaml

# install prometheus+grafana via Helm (if not present)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update

if ! helm status monitoring >/dev/null 2>&1; then
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --create-namespace --namespace monitoring \
    --set grafana.adminPassword="admin" --wait
fi

# apply alerting rules (if using Prometheus operator)
kubectl apply -f $TMP_DIR/alerting-rule.yaml || true

echo "Deployment complete. App should be available at: http://${HOSTNAME}"
