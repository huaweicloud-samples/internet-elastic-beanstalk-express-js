# 构建阶段使用官方 Node.js 运行时镜像
FROM node:18-alpine

# 工作目录
WORKDIR /app

# 先拷贝依赖清单，利用镜像层缓存加速构建
COPY package*.json ./
RUN npm install --omit=dev

# 拷贝应用源码
COPY . .

# 容器监听端口（需与 app.js 中 PORT 默认值一致）
EXPOSE 8080

# 启动命令
CMD ["node", "app.js"]
