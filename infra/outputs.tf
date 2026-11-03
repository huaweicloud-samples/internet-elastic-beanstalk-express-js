output "cce_cluster_id" {
  description = "CCE 集群 ID"
  value       = huaweicloud_cce_cluster.main.id
}

output "cce_kubeconfig" {
  description = "CCE 集群 kubeconfig（含敏感信息，仅本地使用）"
  value       = huaweicloud_cce_cluster.main.kube_config_raw
  sensitive   = true
}

output "namespace" {
  description = "部署命名空间"
  value       = huaweicloud_cce_namespace.main.name
}

output "elb_id" {
  description = "共享型 ELB ID（用于 Service 注解 kubernetes.io/elb.id）"
  value       = huaweicloud_elb_loadbalancer.main.id
}
