# Operations Runbook

This guide covers day-to-day operations for managing the EKS infrastructure and applications.

## 📋 Daily Operations Checklist

### Morning Checks

- [ ] Check cluster health
- [ ] Review overnight alerts
- [ ] Verify backup completion
- [ ] Check resource utilization

### Evening Checks

- [ ] Review day's deployments
- [ ] Verify no failed pods
- [ ] Check security alerts
- [ ] Review cost metrics

## 🔍 Health Checks

### Cluster Health

```bash
# Check cluster status
kubectl cluster-info

# Check node status
kubectl get nodes -o wide

# Check node resource usage
kubectl top nodes

# Check all pods
kubectl get pods --all-namespaces

# Check events
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

### Application Health

```bash
# Frontend
kubectl get pods -n frontend
kubectl get svc -n frontend
kubectl get ingress -n frontend

# Backend
kubectl get pods -n backend
kubectl get svc -n backend
kubectl get ingress -n backend

# Check application logs
kubectl logs -n frontend -l app.kubernetes.io/name=todo-frontend --tail=100
kubectl logs -n backend -l app.kubernetes.io/name=todo-backend --tail=100

# Check HPA status
kubectl get hpa -n frontend
kubectl get hpa -n backend
```

### System Component Health

```bash
# Check system pods
kubectl get pods -n kube-system

# Check cert-manager
kubectl get pods -n cert-manager

# Check Velero backups
velero backup get

# Check storage
kubectl get pvc --all-namespaces
kubectl get sc
```

## 🚀 Deployment Operations

### Manual Deployment

```bash
# Deploy frontend
helm upgrade --install todo-frontend ./helm_charts/todo-frontend \
  --namespace frontend \
  --set image.tag=v1.2.0 \
  --wait

# Deploy backend
helm upgrade --install todo-backend ./helm_charts/todo-backend \
  --namespace backend \
  --set image.tag=v1.2.0 \
  --wait
```

### Rollback Deployment

```bash
# Rollback to previous version
helm rollback todo-frontend 1 -n frontend

# Or using kubectl
kubectl rollout undo deployment/todo-frontend -n frontend

# Check rollout status
kubectl rollout status deployment/todo-frontend -n frontend

# View rollout history
kubectl rollout history deployment/todo-frontend -n frontend
```

### Scale Application

```bash
# Manual scale
kubectl scale deployment todo-frontend --replicas=5 -n frontend

# Edit HPA
kubectl edit hpa todo-frontend -n frontend
```

## 🔧 Troubleshooting

### Pod Issues

#### Pod Stuck in Pending

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Insufficient resources: Check node capacity
kubectl top nodes

# - PVC not bound: Check storage
kubectl get pvc -n <namespace>

# - Image pull errors: Check image exists
kubectl get events -n <namespace> | grep Failed

# Check resource quotas
kubectl describe resourcequota -n <namespace>
```

#### Pod CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n <namespace> --previous

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Application error: Check logs
# - Liveness probe failing: Adjust probe settings
# - Resource limits: Increase memory/CPU limits
```

#### Image Pull Errors

```bash
# Verify image exists
aws ecr describe-images --repository-name todo-frontend

# Check image pull secrets
kubectl get secrets -n <namespace>

# Verify IAM permissions
aws sts get-caller-identity
```

### Network Issues

#### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Test from within cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- /bin/bash
# Then: curl http://<service-name>.<namespace>.svc.cluster.local

# Check ALB status
kubectl get ingress -n <namespace>
kubectl describe ingress <ingress-name> -n <namespace>

# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

#### DNS Resolution Issues

```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check DNS configmap
kubectl get configmap coredns -n kube-system -o yaml
```

### Storage Issues

#### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Describe PVC
kubectl describe pvc <pvc-name> -n <namespace>

# Check storage class
kubectl get storageclass

# Check EBS CSI driver
kubectl get pods -n kube-system -l app=ebs-csi-controller
```

### Performance Issues

#### High CPU/Memory

```bash
# Top resource consumers
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Check resource limits
kubectl describe pod <pod-name> -n <namespace>

# Check node pressure
kubectl describe node <node-name>
```

#### Slow Response Times

```bash
# Check HPA scaling
kubectl get hpa -n <namespace>

# Check pod resource usage
kubectl top pods -n <namespace>

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check application logs for slow queries
kubectl logs -n <namespace> -l app.kubernetes.io/name=<app-name> | grep -i "slow"
```

## 📊 Monitoring

### Accessing Grafana

```bash
# Port-forward to Grafana
kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring

# Access at http://localhost:3000
# Default credentials: admin/admin
```

### Key Metrics to Monitor

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| CPU Usage | > 70% | > 90% | Scale pods or nodes |
| Memory Usage | > 80% | > 95% | Scale or optimize |
| Disk Usage | > 80% | > 90% | Clean up or expand |
| Pod Restarts | > 3/hr | > 10/hr | Investigate crashes |
| API Latency | > 200ms | > 500ms | Check bottlenecks |
| Error Rate | > 1% | > 5% | Check application |

### CloudWatch Logs

```bash
# View cluster logs
aws logs tail /aws/eks/<cluster-name>/cluster --follow

# View specific log stream
aws logs get-log-events \
  --log-group-name /aws/eks/<cluster-name>/cluster \
  --log-stream-name <stream-name>
```

## 💾 Backup Operations

### Manual Backup

```bash
# Create backup
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S) \
  --include-namespaces frontend,backend \
  --wait

# Check backup status
velero backup get

# Describe backup
velero backup describe <backup-name>

# View backup logs
velero backup logs <backup-name>
```

### Scheduled Backups

```bash
# View scheduled backups
velero schedule get

# Create new schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces frontend,backend,monitoring \
  --ttl 720h0m0s
```

### Restore Operations

```bash
# List available backups
velero backup get

# Create restore
velero restore create --from-backup <backup-name>

# Check restore status
velero restore get

# Describe restore
velero restore describe <restore-name>
```

## 🔐 Security Operations

### Rotate Credentials

```bash
# Rotate Kubernetes certificates
# (Managed by EKS, automatic)

# Update secrets
kubectl create secret generic db-credentials \
  --from-literal=password=<new-password> \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up new secrets
kubectl rollout restart deployment/<deployment-name> -n <namespace>
```

### Security Scanning

```bash
# Scan images with Trivy
trivy image <account>.dkr.ecr.<region>.amazonaws.com/todo-frontend:latest

# Scan Kubernetes manifests
trivy config ./helm_charts/

# Run kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench
```

### Network Policy Verification

```bash
# List network policies
kubectl get networkpolicies --all-namespaces

# Test connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- /bin/bash
# Then test connections between namespaces
```

## 📈 Scaling Operations

### Horizontal Pod Autoscaler

```bash
# View HPA status
kubectl get hpa -n frontend
kubectl describe hpa todo-frontend -n frontend

# Edit HPA
kubectl edit hpa todo-frontend -n frontend

# Watch scaling
kubectl get hpa -n frontend --watch
```

### Cluster Autoscaler

```bash
# Check autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# View node groups
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>

# Scale node group manually
aws eks update-nodegroup-config \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=2,maxSize=10,desiredSize=3
```

## 🔧 Maintenance Tasks

### Update Kubernetes Version

```bash
# Check current version
aws eks describe-cluster --name <cluster-name> --query 'cluster.version'

# Update control plane
aws eks update-cluster-version --name <cluster-name> --kubernetes-version 1.30

# Update node groups
aws eks update-nodegroup-version \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name>
```

### Certificate Renewal

```bash
# Check certificate expiry
kubectl get certificates -n cert-manager
kubectl describe certificate <cert-name> -n cert-manager

# Force renewal
kubectl cert-manager renew <cert-name> -n <namespace>
```

### Clean Up Resources

```bash
# Clean up completed jobs
kubectl delete jobs --field-selector status.successful=1 -n <namespace>

# Clean up old pods
kubectl get pods --all-namespaces | grep Evicted | awk '{print $2 " --namespace=" $1}' | xargs kubectl delete pod

# Clean up unused images on nodes
# (Automatic with EKS optimized AMIs)
```

## 🚨 Incident Response

### Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| P1 | Critical | 15 minutes | Complete outage, data loss |
| P2 | High | 1 hour | Partial outage, major feature broken |
| P3 | Medium | 4 hours | Minor feature broken, workarounds exist |
| P4 | Low | 24 hours | Cosmetic issues, documentation |

### Incident Response Procedure

1. **Detect**: Identify the issue through monitoring/alerting
2. **Assess**: Determine severity and impact
3. **Communicate**: Notify stakeholders via Slack/email
4. **Mitigate**: Apply immediate fix or workaround
5. **Resolve**: Implement permanent fix
6. **Post-mortem**: Document learnings and improvements

### Rollback Procedure

```bash
# 1. Identify problematic deployment
kubectl get deployments --all-namespaces

# 2. Rollback to previous version
helm rollback <release-name> 1 -n <namespace>

# 3. Verify rollback
kubectl get pods -n <namespace>
kubectl logs -n <namespace> -l app.kubernetes.io/name=<app-name>

# 4. Monitor metrics
kubectl top pods -n <namespace>
```

### Escalation Contacts

| Role | Contact | Responsibility |
|------|---------|----------------|
| On-call Engineer | oncall@company.com | Initial response |
| Platform Lead | platform-lead@company.com | Escalation |
| Engineering Manager | eng-mgr@company.com | Business impact |

## 📚 Runbooks

### Runbook: High Memory Usage

```bash
# 1. Identify high memory pods
kubectl top pods --all-namespaces --sort-by=memory

# 2. Check if limits are set
kubectl describe pod <pod-name> -n <namespace>

# 3. If no limits, add them
kubectl patch deployment <deployment-name> -n <namespace> --patch='{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "resources": {
            "limits": {"memory": "512Mi"},
            "requests": {"memory": "256Mi"}
          }
        }]
      }
    }
  }
}'

# 4. If OOMKilled, increase limits
kubectl patch deployment <deployment-name> -n <namespace> --patch='{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "resources": {
            "limits": {"memory": "1Gi"},
            "requests": {"memory": "512Mi"}
          }
        }]
      }
    }
  }
}'

# 5. Verify fix
kubectl get pods -n <namespace>
kubectl top pods -n <namespace>
```

### Runbook: ALB Not Creating

```bash
# 1. Check ingress events
kubectl describe ingress <ingress-name> -n <namespace>

# 2. Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# 3. Verify subnets are tagged
aws ec2 describe-subnets --subnet-ids <subnet-id> --query 'Subnets[*].Tags'

# Should have tags:
# - kubernetes.io/cluster/<cluster-name>: shared
# - kubernetes.io/role/elb: 1 (for public)
# - kubernetes.io/role/internal-elb: 1 (for private)

# 4. Fix subnet tags if missing
aws ec2 create-tags \
  --resources <subnet-id> \
  --tags Key=kubernetes.io/cluster/<cluster-name>,Value=shared

# 5. Recreate ingress
kubectl delete ingress <ingress-name> -n <namespace>
# Then reapply
```

---

**Next:** [Disaster Recovery Guide](DISASTER_RECOVERY.md)
