#!/bin/bash
set -e # 에러나면 즉시 종료

echo "🛑 [1/6] 모든 ArgoCD Application 삭제"
kubectl delete applications --all --all-namespaces --ignore-not-found=true || true

echo "🧹 [2/6] 모든 리소스(Service, PVC, ConfigMap, Secret) 삭제 중..."
kubectl delete svc --all --all-namespaces --ignore-not-found=true || true
kubectl delete pvc --all --all-namespaces --ignore-not-found=true || true
kubectl delete configmap --all --all-namespaces --ignore-not-found=true || true
kubectl delete secret --all --all-namespaces --ignore-not-found=true || true

echo "⌛ PVC detach 대기 (최대 60초)..."
for i in {1..12}; do
  remaining=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)
  if [ "$remaining" -eq 0 ]; then
    echo "✅ 모든 PVC가 삭제 완료됨."
    break
  else
    echo "⏳ 아직 $remaining개의 PVC가 남아 있음... (5초 대기)"
    sleep 5
  fi
done

echo "🧹 [3/6] PersistentVolume(PV) 정리 중..."
kubectl delete pv --all --ignore-not-found=true || true

echo "🧹 [4/6] 사용자 정의 네임스페이스 삭제 중..."
for ns in $(kubectl get ns --no-headers | awk '{print $1}' | grep -v "kube-system\|kube-public\|default"); do
  echo "  ➜ 네임스페이스 삭제 중: $ns"
  kubectl delete ns $ns --ignore-not-found=true || true
done

echo "🧹 [5/6] ArgoCD 네임스페이스 삭제"
kubectl delete ns argocd --ignore-not-found=true || true

echo "🧹 [6/6] 확인: 남은 네임스페이스 및 PV/PVC 상태"
kubectl get ns
kubectl get pv
kubectl get pvc -A

echo "✅ 모든 리소스 정리 완료"
echo "-------------------------------------------"
echo "Terraform으로 EKS 인프라 삭제하려면 다음을 실행하세요:"
echo "cd ~/eks"
echo "terraform destroy -auto-approve"
echo "-------------------------------------------"
