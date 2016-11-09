# This file should be kept in sync with cluster/gce/coreos/kube-manifests/addons/dashboard/dashboard-controller.yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: kubernetes-dashboard-v1.4.0
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    version: v1.4.0
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
        version: v1.4.0
        kubernetes.io/cluster-service: "true"
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
        scheduler.alpha.kubernetes.io/tolerations: '[{"key":"CriticalAddonsOnly", "operator":"Exists"}]'
    spec:
      containers:
      - name: kubernetes-dashboard
        image: gcr.io/google_containers/kubernetes-dashboard-amd64:v1.4.0
        resources:
          # keep request = limit to keep this container in guaranteed class
          limits:
            cpu: 100m
            memory: 50Mi
          requests:
            cpu: 100m
            memory: 50Mi
        #env:
        #- name: KUBECONFIG
        #  value: /etc/kubernetes/kubecfg.conf
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: "secret-volume"
          mountPath: "/etc/kubernetes"
          readOnly: true
        #args:
        #-  --apiserver-host=https://$MASTER_NODE_IP:443
        #-   --kubeconfig=/etc/kubernetes/kubecfg.conf
        livenessProbe:
          httpGet:
            path: /
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: secret-volume
        secret:
          secretName: dashboard-config
          items:
          - key: ca.crt
            path: pki/ca.crt
          - key: kubecfg.conf
            path: kubecfg.conf
