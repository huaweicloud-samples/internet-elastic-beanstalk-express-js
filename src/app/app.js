const express = require('express');
const app = express();

// 监听端口可由环境变量覆盖，便于在不同部署环境复用同一镜像
const port = process.env.PORT || 8080;

app.get('/', (req, res) => res.send('Hello World!'));

// 健康检查端点：供负载均衡的健康检查探针使用
app.get('/healthz', (req, res) => res.status(200).send('OK'));

app.listen(port, () => {
  console.log(`App running on http://localhost:${port}`);
});
