# Provider 配置：鉴权信息从环境变量注入，不硬编码任何凭据
#   export HW_ACCESS_KEY="<your-access-key>"
#   export HW_SECRET_KEY="<your-secret-key>"
#   （或使用临时安全令牌 export HW_SECURITY_TOKEN="..."）
provider "huaweicloud" {
  region = var.region
}
