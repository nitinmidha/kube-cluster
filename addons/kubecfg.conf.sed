apiVersion: v1
kind: Config
clusters:
- name: kubernetes
  cluster:
    certificate-authority: /etc/kubernetes/pki/ca.crt
    server: https://$MASTER_NODE_IP:443
users:
- name: kubedashboard
  user:
    --token: $DASHBOARD_TOKEN
contexts:
- context:
    cluster: kubernetes
    user: kubedashboard
  name: kubedashboard-context
current-context: kubedashboard-context