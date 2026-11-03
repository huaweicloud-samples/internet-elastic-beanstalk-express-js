variable "region" {
  description = "华为云区域"
  type        = string
  default     = "cn-north-4" # 北京四
}

variable "project_name" {
  description = "项目名称，用于资源命名前缀"
  type        = string
  default     = "express-cce-practice"
}

variable "admin_key_pair" {
  description = "节点登录密钥对名称（需为已存在的弹性云服务器密钥对）"
  type        = string
  default     = "default-keypair"
}

variable "node_flavor" {
  description = "节点池规格（显式声明，便于管控与复现）"
  type        = string
  default     = "s6.large.2"
}

variable "app_port" {
  description = "应用容器监听端口"
  type        = number
  default     = 8080
}

variable "swr_image" {
  description = "SWR 容器镜像地址，格式：swr.<region>.myhuaweicloud.com/<组织>/<仓库>:<标签>"
  type        = string
  default     = "swr.cn-north-4.myhuaweicloud.com/express-cce-practice/express-app:latest"
}
