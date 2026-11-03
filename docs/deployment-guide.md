# 部署指导书

本指导书说明如何将 Express Web 应用部署到华为云 CCE。整体流程：构建镜像并推送至 SWR → 用 Terraform 创建基础设施 → 获取集群 kubeconfig → 部署工作负载。

> 所有命令中的目录切换均使用相对路径（如 `cd infra`）。请在克隆本仓库后的根目录下执行。

## 前置准备

- 已安装：Terraform（>= 1.5）、kubectl、容器引擎（docker 或 nerdctl）、华为云命令行工具。
- 配置鉴权环境变量（凭据不入文件）：
  ```bash
  export HW_ACCESS_KEY="<your-access-key>"
  export HW_SECRET_KEY="<your-secret-key>"
  ```
- 已在镜像仓库服务（SWR）创建组织，并记录组织名。

## 步骤 1：构建并推送镜像

```bash
# 进入应用目录
cd src/app

# 构建镜像（请替换 <组织> 与 <区域>）
docker build -t swr.<区域>.myhuaweicloud.com/<组织>/express-app:latest .

# 登录镜像仓库并推送
docker login swr.<区域>.myhuaweicloud.com -u <访问密钥ID> -p <登录指令返回的密码>
docker push swr.<区域>.myhuaweicloud.com/<组织>/express-app:latest
```

推送完成后记录完整镜像地址，后续步骤会用到。

## 步骤 2：创建基础设施

```bash
# 进入基础设施目录
cd infra

# 初始化（如离线环境已配置 provider 本地覆盖，可跳过网络下载）
terraform init

# 预览将创建的资源
terraform plan

# 创建资源（将按配置创建上述基础设施）
terraform apply
```

`terraform apply` 完成后，记录以下输出（后续步骤使用）：

- `elb_id`：独享型 ELB 的 ID。
- `elb_eip_address`：绑定到 ELB 的弹性公网 IP 地址。
- `namespace`：部署命名空间。

## 步骤 3：获取集群访问配置

```bash
# 从 CCE 控制台或通过命令行工具下载 kubeconfig，配置到本地 kubectl
# 或使用 terraform 输出（敏感，仅本地使用）：
terraform output -raw cce_kubeconfig > /tmp/cce-kubeconfig.yaml
export KUBECONFIG=/tmp/cce-kubeconfig.yaml

# 校验集群连通性
kubectl get nodes
```

## 步骤 4：部署工作负载

```bash
# 回到仓库根目录
cd ../..

# 注入变量并部署（替换占位值为实际值）
export NAMESPACE=$(terraform -chdir=infra output -raw namespace)
export ELB_ID=$(terraform -chdir=infra output -raw elb_id)
export SWR_IMAGE=swr.<区域>.myhuaweicloud.com/<组织>/express-app:latest

envsubst < src/workloads/express-deployment.yaml | kubectl apply -f -
```

等待 Pod 进入 `Running` 且 Service 的 ELB 绑定完成：

```bash
kubectl -n "$NAMESPACE" get pods
kubectl -n "$NAMESPACE" get svc express-app
```

## 步骤 5：验证访问

见 README「使用方法 / 验证」章节。通过 `elb_eip_address` 对应的公网地址访问应用：

```bash
curl http://<elb_eip_address>/
# 预期输出：Hello World!
```

## 释放资源

部署验证完成后，建议释放不再需要的资源以避免残留：

```bash
cd infra
terraform destroy
```

同时删除镜像仓库中不再需要的镜像版本。
