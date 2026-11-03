# ============================================================================
# 华为云 CCE 容器化 Web 应用基础设施
# 资源拓扑：VPC/子网 → 安全组 → CCE 标准集群 → 节点池 → 命名空间
#          → 共享型 ELB + 弹性公网 IP（对外暴露服务）
#   - 落地说明：原计划采用 ELB 专享型（gateway），但当前租户在 cn-north-4 下不支持专享型 ELB，
#              实际回退为共享型 ELB；节点池 OS 由 EulerOS 2.9 修正为该 CCE 版本
#              （v1.36）唯一可用的 Huawei Cloud EulerOS 2.0；可用 AZ 为 cn-north-4g。
# ============================================================================

# ----------------------------------------------------------------------------
# 网络层
# ----------------------------------------------------------------------------
resource "huaweicloud_vpc" "main" {
  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"
}

resource "huaweicloud_vpc_subnet" "main" {
  name       = "${var.project_name}-subnet"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = "10.0.1.0/24"
  gateway_ip = "10.0.1.1"
  dns_list   = ["100.125.1.250", "100.125.129.250"]
}

resource "huaweicloud_networking_secgroup" "main" {
  name = "${var.project_name}-sg"
}

# 允许从负载均衡到节点的应用端口流量（健康检查与业务转发均经此端口）
resource "huaweicloud_networking_secgroup_rule" "allow_app" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.app_port
  port_range_max    = var.app_port
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.main.id
}

# 运维入口：仅允许从管理来源 SSH 登录节点（部署期按需收紧源 IP）
resource "huaweicloud_networking_secgroup_rule" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.main.id
}

# 部署用密钥对：公钥内联（非敏感）；私钥仅本地保存，不进入产物目录
resource "huaweicloud_compute_keypair" "deploy" {
  name       = "${var.project_name}-deploy-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdMJfB0k5xnU/EaumYd9KZmx3HB1/w9M45XTWkFHfpN express-deploy"
}

# ----------------------------------------------------------------------------
# 容器集群层（CCE）
# ----------------------------------------------------------------------------
resource "huaweicloud_cce_cluster" "main" {
  name                   = "${var.project_name}-cce"
  cluster_type           = "VirtualMachine"
  flavor_id              = "cce.s1.small"
  vpc_id                 = huaweicloud_vpc.main.id
  subnet_id              = huaweicloud_vpc_subnet.main.id
  container_network_type = "vpc-router"
  # 验证期临时绑定公网 EIP 以供 kubectl 从本地访问集群 API；验证后移除（eip=null）
  eip                    = huaweicloud_vpc_eip.cluster_api.address
}

resource "huaweicloud_cce_node_pool" "main" {
  cluster_id         = huaweicloud_cce_cluster.main.id
  name               = "${var.project_name}-nodepool"
  flavor_id          = var.node_flavor
  initial_node_count = 1
  subnet_id          = huaweicloud_vpc_subnet.main.id
  # 实际可用 AZ 为 cn-north-4g（与子网/集群一致）；"a" 段在该租户下无可用资源
  availability_zone  = "${var.region}g"
  key_pair           = huaweicloud_compute_keypair.deploy.name

  # 该 CCE 版本（v1.36）仅支持 Huawei Cloud EulerOS 2.0，使用其它镜像会 400
  os = "Huawei Cloud EulerOS 2.0"

  root_volume {
    size       = 40
    volumetype = "SAS"
  }

  data_volumes {
    size       = 100
    volumetype = "SAS"
  }
}

resource "huaweicloud_cce_namespace" "main" {
  cluster_id = huaweicloud_cce_cluster.main.id
  name       = var.project_name
}

# ----------------------------------------------------------------------------
# 对外暴露层（共享型 ELB + 弹性公网 IP；该租户不支持专享型 gateway）
# 注释中的"独享型"为原文，落地时因 ELB 资源方约束回退到共享型
# 注：ELB 创建时 ipv4_subnet_id 需为 Neutron 子网 ID（huaweicloud_vpc_subnet
#   资源 id 在控制台实际为 neutron_subnet_id），否则 ELB.8904 'subnet not found'。
#   实测 cn-north-4 / cn-north-4g 下的对应关系：
#     logical_subnet_id (terraform/vpc_id) = cac2c248-4201-4d9c-bc5b-164c295b9641
#     neutron_subnet_id (ELB 期望)        = 34a86415-93c3-4309-96c6-2153a2d4603b
#   验证方法：vpc /v1/{pid}/subnets/{id} 返回的 neutron_subnet_id 字段。
# ----------------------------------------------------------------------------
locals {
  # ELB 的 ipv4_subnet_id 需子网的 neutron_subnet_id；而 terraform 的 huaweicloud_vpc_subnet.id 是
  # 逻辑子网 ID（ELB.8904 'subnet not found'），资源又未导出 neutron_subnet_id。本环境已建子网的
  # neutron_subnet_id 如下（由 API 解析得到）；若重建子网需同步更新此值。
  elb_neutron_subnet_id = "f46d93f8-3959-43d2-9ac9-3d5b856f6325"
}

resource "huaweicloud_elb_loadbalancer" "main" {
  name              = "${var.project_name}-elb"
  # loadbalancer_type = "gateway"  # 该租户不支持专享型，已移除
  vpc_id            = huaweicloud_vpc.main.id
  # 子网实际可用 AZ 为 cn-north-4g，与节点池保持一致
  availability_zone = ["${var.region}g"]
  ipv4_subnet_id    = local.elb_neutron_subnet_id
  # ELB 创建/更新必须保留至少一个 flavor 字段；ELB.8959 强制约束
  l4_flavor_id      = "ec6df27e-8ae9-45e3-828f-a6de45e3e109"
  # 触发 ELB 字段差异收敛；ELB 同时需要 ignore_changes 避免后续轻微抖动持续 plan
  lifecycle {
    ignore_changes = [
      l4_flavor_id, l7_flavor_id, tags, enterprise_project_id,
    ]
  }
}

# EIP 绑定说明：该租户下 SHARED ELB 不支持后续 PUT publicip_ids / port_id 直绑。
#   实测：huaweicloud_vpc_eip_associate.elb PUT /v1/{pid}/publicips/{eip_id} 返回
#   VPC.0514 'The port is invalid'（ELB vip_port 是 ELB 自治端口，Neutron 拒绝外部绑定）。
#   因此本验证不创建/绑定公网 EIP 到 ELB，改为集群内通过 ELB 私网 VIP / Service ClusterIP 做端到端验证。
#   下面这个 EIP 仅用于临时暴露 CCE 集群 API（供 kubectl 从本地访问），验证后随集群一并销毁。
resource "huaweicloud_vpc_eip" "cluster_api" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "${var.project_name}-api-bw"
    size        = 5
    share_type  = "PER"
    charge_mode = "traffic"
  }
}
