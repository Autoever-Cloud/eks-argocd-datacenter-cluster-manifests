#!/bin/bash
set -e
# ================================
# Argo CD 자동 설치 스크립트
# ================================
# ⚙️ 환경: AWS EKS + NLB 기반 접근
# =================================

echo "🚀 [1/4] Creating namespace 'argocd'..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "📦 [2/4] Installing Argo CD (latest stable release)..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "🌐 [3/4] Patching argocd-server Service to LoadBalancer (NLB)..."
kubectl patch svc argocd-server -n argocd -p '{
  "spec": {
    "type": "LoadBalancer",
    "externalTrafficPolicy": "Cluster"
  }
}' || true

echo "🔧 [4/4] Annotating argocd-server Service for AWS NLB..."
kubectl annotate svc argocd-server -n argocd \
  service.beta.kubernetes.io/aws-load-balancer-type="nlb" \
  --overwrite || true

echo "⏳ Waiting for LoadBalancer hostname..."
while true; do
  ELB=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "$ELB" ]]; then
    echo "✅ LoadBalancer Ready: $ELB"
    break
  fi
  echo "⏳ Waiting for NLB to be provisioned..."
  sleep 5
done

echo ""
echo "========================================"
echo "✅ Argo CD successfully installed!"
echo "🌐 URL: https://$ELB"
echo "👤 Username: admin"
echo "🔐 Password: Run this command to see the initial password.
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo"
echo "========================================"