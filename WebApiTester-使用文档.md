# Web API Tester 使用文档

一个基于 WPF 的轻量 API 测试工具，用于日常发送 HTTP 请求、调试接口、验证响应。

---

## 1. 界面总览

| 区域 | 说明 |
|---|---|
| 顶部 | Method 下拉框 + URL 输入框 + Send 按钮 |
| 左侧 Tab | Headers / Body / Auth / Variables，用来配置请求 |
| 右侧 | 响应结果：状态码、耗时、Body、Headers |

---

## 2. 发送一个基本请求

1. 在顶部下拉框选择 Method（GET / POST / PUT / PATCH / DELETE）
2. URL 输入框填写接口地址，例如：
   ```
   https://jsonplaceholder.typicode.com/posts/1
   ```
3. 点击 **Send**
4. 右侧会显示：
   - 状态码（绿色 = 成功，橙红色 = 4xx/5xx，红色 = 请求本身失败，比如网络不通）
   - 耗时（ms）
   - Body（自动格式化 JSON）
   - Headers（切换到 Headers 子 Tab 查看）

---

## 3. 配置 Headers

切到左侧 **Headers** Tab：

- 点击 **+ Add Header** 新增一行
- 每行有「启用」勾选框，取消勾选可以临时禁用某个 Header 而不用删除
- 点击行尾 **✕** 删除
- 默认已经带了一条 `Content-Type: application/json`

---

## 4. 配置 Body（POST/PUT/PATCH/DELETE）

切到左侧 **Body** Tab：

1. 上方输入框可以修改 Content-Type（默认 `application/json`）
2. 下方文本框填写请求体，例如：
   ```json
   {
     "title": "测试标题",
     "body": "测试内容",
     "userId": 1
   }
   ```
3. GET 请求不会发送 Body，即使填了也会被忽略

---

## 5. 配置认证（Auth）

切到左侧 **Auth** Tab，下拉框选择认证方式：

### None（默认）
不添加任何 Authorization Header。

### Basic Auth
- 填写 Username / Password
- 工具会自动生成 `Authorization: Basic <base64(user:pass)>` 并附加到请求

### Bearer Token
- 填写 Token（不需要自己加 "Bearer " 前缀）
- 工具会自动生成 `Authorization: Bearer <token>` 并附加到请求

> 注意：如果 Headers Tab 里手动填了 `Authorization`，Send 时会被 Auth Tab 的配置**覆盖**，避免冲突。

---

## 6. 使用变量（Variables）

适合同一个接口要在多个环境（dev/test/prod）之间切换，或者想把 Token 抽出来复用。

1. 切到左侧 **Variables** Tab
2. 添加变量，例如：
   | Key | Value |
   |---|---|
   | baseUrl | https://api.example.com |
   | token | eyJhbGciOi... |
3. 在 URL / Headers / Body / Auth 的输入框里用 `{{key}}` 引用，例如：
   - URL: `{{baseUrl}}/api/orders`
   - Bearer Token 字段: `{{token}}`
4. 发送时会自动把 `{{baseUrl}}`、`{{token}}` 替换成实际值

---

## 7. 常见问题排查

| 现象 | 可能原因 |
|---|---|
| 状态码是红色，Body 显示网络错误 | URL 拼错、网络不通，或者目标服务器没起来 |
| 状态码 503 | 目标服务器临时不可用，跟工具无关，换个时间或换个接口测 |
| Body 显示空 | Content-Type 没设对，或者接口本身返回空 Body |
| 返回 401 | 检查 Auth Tab 里 Token / 用户名密码是否正确，或者 Token 已过期 |
| 变量没有被替换 | 检查 `{{key}}` 拼写是否和 Variables 里的 Key 完全一致（区分大小写） |

---

## 8. 已知限制

- 不支持 form-data / multipart 上传文件
- 关闭程序后，Headers / Body / Variables 不会保存，需要重新填写
- 没有请求历史，无法回看之前测过的请求
- 只支持 Basic / Bearer Token 两种认证方式，不支持 OAuth2 授权流程

这些是后续可以按需扩展的方向，目前版本适合日常临时测试单个接口的场景。
