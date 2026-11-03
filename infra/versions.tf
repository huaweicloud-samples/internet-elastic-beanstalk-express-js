terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.97"
    }
  }

  # 生产环境建议将状态文件存入 OBS 桶，此处使用本地后端便于演示
  backend "local" {}
}
