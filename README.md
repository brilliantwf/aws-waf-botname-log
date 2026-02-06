# AWS WAF Bot Control 日志分析 Demo

基于 AWS WAF Bot Control、CloudFront 和 EC2 的 Bot 流量检测与日志分析演示项目。

## 架构概览

```
                                    ┌─────────────────────────────────────┐
                                    │           AWS Cloud                 │
┌──────────────┐                    │                                     │
│  Bot Client  │───────────────────▶│  ┌─────────────────────────────┐   │
│  (模拟器)     │     HTTPS          │  │      CloudFront + WAF       │   │
└──────────────┘                    │  │  ┌─────────────────────┐    │   │
                                    │  │  │   Bot Control 规则   │    │   │
                                    │  │  │   - 检测 Bot 类型    │    │   │
                                    │  │  │   - 记录标签信息     │    │   │
                                    │  │  └──────────┬──────────┘    │   │
                                    │  └─────────────┼───────────────┘   │
                                    │                │                    │
                                    │       ┌───────┴───────┐            │
                                    │       ▼               ▼            │
                                    │  ┌─────────┐    ┌───────────┐      │
                                    │  │   EC2   │    │CloudWatch │      │
                                    │  │ (nginx) │    │   Logs    │      │
                                    │  └─────────┘    └───────────┘      │
                                    │   Origin          WAF 日志         │
                                    └─────────────────────────────────────┘
```

### 数据流说明

1. **请求到达 CloudFront** - 用户/Bot 发起 HTTPS 请求
2. **WAF 检测** - AWS WAF Bot Control 分析请求，识别 Bot 类型
3. **日志记录** - WAF 自动将检测结果写入 CloudWatch Logs
4. **请求转发** - 请求转发到 EC2 Origin 服务器
5. **日志分析** - 使用 CloudWatch Logs Insights 查询 Bot 信息

## 项目结构

```
waf/
├── bin/
│   └── app.ts                      # CDK 应用入口
├── lib/
│   ├── waf-stack.ts                # WAF WebACL + Bot Control 配置
│   └── cloudfront-stack.ts         # CloudFront Distribution 配置
├── scripts/
│   ├── bot_simulator.py            # Bot 流量模拟器
│   └── userdata.sh                 # EC2 启动脚本
├── queries/
│   └── cloudwatch-insights.sql     # CloudWatch 查询示例 (50+ 条)
├── static/
│   ├── index.html                  # 测试页面
│   └── api/data                    # 测试 API 端点
├── package.json
├── tsconfig.json
├── cdk.json
└── README.md
```

## 快速开始

### 前置条件

- AWS CLI 已配置 (`aws configure`)
- Node.js 18+ 
- Python 3.8+ (用于 Bot 模拟器)
- AWS CDK CLI (`npm install -g aws-cdk`)

### 1. 部署基础设施

```bash
cd /home/ec2-user/waf

# 安装依赖
npm install

# 部署所有 Stack
npm run deploy

# 部署完成后会输出:
# - CloudFront Distribution URL
# - WAF WebACL ID
# - CloudWatch Log Group 名称
```

### 2. 访问测试页面

```bash
# 替换为你的 CloudFront URL
curl https://<distribution-id>.cloudfront.net/
```

### 3. 运行 Bot 模拟器

```bash
# 基本测试 (50 请求，包含各类 Bot)
python3 scripts/bot_simulator.py --url https://<distribution-id>.cloudfront.net

# 指定请求数量
python3 scripts/bot_simulator.py --url https://<distribution-id>.cloudfront.net --count 200

# 只测试特定 Bot 类型
python3 scripts/bot_simulator.py --url https://<distribution-id>.cloudfront.net \
  --categories http_library ai_bot scraping_framework

# 详细输出
python3 scripts/bot_simulator.py --url https://<distribution-id>.cloudfront.net \
  --count 100 --verbose
```

### 4. 查看 WAF 日志

**方式一：AWS Console**
1. 打开 CloudWatch → Logs → Logs Insights
2. 选择日志组: `aws-waf-logs-demo-bot-analysis`
3. 输入查询语句 (见下方示例)

**方式二：AWS CLI**
```bash
aws logs start-query \
  --log-group-name aws-waf-logs-demo-bot-analysis \
  --start-time $(($(date +%s) - 3600)) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp | parse @message /awswaf:managed:aws:bot-control:bot:name:(?<bot_name>[^"]+)/ | filter ispresent(bot_name) | stats count(*) as count by bot_name | sort count desc' \
  --region us-east-1
```

## CloudWatch Logs Insights 查询示例

### Bot 名称统计

```sql
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:name:(?<bot_name>[^"]+)/
| filter ispresent(bot_name)
| stats count(*) as count by bot_name
| sort count desc
```

### Bot 类别统计

```sql
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<bot_category>[^"]+)/
| filter ispresent(bot_category)
| stats count(*) as count by bot_category
| sort count desc
```

### 完整 Bot 详情

```sql
fields @timestamp, 
       httpRequest.clientIp as ip,
       httpRequest.uri as uri,
       action
| parse @message /awswaf:managed:aws:bot-control:bot:name:(?<bot_name>[^"]+)/
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<bot_category>[^"]+)/
| filter ispresent(bot_name)
| display @timestamp, ip, uri, bot_name, bot_category, action
| sort @timestamp desc
| limit 50
```

### AI Bot 专项查询

```sql
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<category>[^"]+)/
| parse @message /awswaf:managed:aws:bot-control:bot:name:(?<bot_name>[^"]+)/
| filter category = "ai"
| display @timestamp, httpRequest.clientIp, bot_name, httpRequest.uri
| sort @timestamp desc
```

### 按时间统计 Bot 流量

```sql
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<category>[^"]+)/
| filter ispresent(category)
| stats count(*) as bot_requests by bin(5m), category
| sort @timestamp asc
```

> 更多查询示例见 [`queries/cloudwatch-insights.sql`](queries/cloudwatch-insights.sql)

## Bot 检测能力

### 可检测的 Bot 类别

| 类别 | 说明 | 示例 |
|------|------|------|
| `http_library` | HTTP 客户端库 | curl, python-requests, axios, wget |
| `ai` | AI 爬虫 | GPTBot, ChatGPT-User, Claude |
| `scraping_framework` | 爬虫框架 | Scrapy |
| `search_engine` | 搜索引擎 | Googlebot, Bingbot, Yandex |
| `seo` | SEO 工具 | AhrefsBot, SemrushBot, MJ12bot |
| `monitoring` | 监控服务 | UptimeRobot, Pingdom, Datadog |
| `social_media` | 社交媒体 | Twitterbot, Facebot, Slackbot |

### WAF 日志中的 Bot 标签

```json
{
  "labels": [
    {"name": "awswaf:managed:aws:bot-control:bot:name:curl"},
    {"name": "awswaf:managed:aws:bot-control:bot:category:http_library"},
    {"name": "awswaf:managed:aws:bot-control:bot:unverified"},
    {"name": "awswaf:managed:aws:bot-control:signal:non_browser_user_agent"}
  ]
}
```

| 标签类型 | 格式 | 说明 |
|----------|------|------|
| Bot 名称 | `bot:name:{name}` | 具体的 Bot 名称 |
| Bot 类别 | `bot:category:{category}` | Bot 分类 |
| 验证状态 | `bot:verified` / `bot:unverified` | 是否为已验证的合法 Bot |
| 组织 | `bot:organization:{org}` | Bot 所属组织 |
| 信号 | `signal:{signal}` | 检测信号 (如 non_browser_user_agent) |

## WAF 规则配置

| 规则 | 优先级 | 动作 | 说明 |
|------|--------|------|------|
| `AWSManagedRulesBotControlRuleSet` | 1 | COUNT | Bot 检测，记录但不阻止 |
| `RateLimitRule` | 2 | BLOCK | IP 速率限制 (2000次/5分钟) |

> 当前配置为 **COUNT 模式**，仅记录日志不阻止请求，便于分析所有 Bot 流量。

## 成本估算

| 服务 | 计费项 | 估算成本 |
|------|--------|----------|
| WAF Bot Control | $1.00 / 百万请求 | 按请求量 |
| CloudFront | 数据传输 | 按流量 |
| CloudWatch Logs | $0.50 / GB 摄取 | 按日志量 |
| EC2 (t3.micro) | $0.0104 / 小时 | ~$7.5 / 月 |

## 清理资源

```bash
cd /home/ec2-user/waf

# 删除所有 CDK 部署的资源
npm run destroy
```

## 扩展场景

### 切换到 BLOCK 模式

修改 `lib/waf-stack.ts` 中的 `overrideAction`:

```typescript
overrideAction: { none: {} }  // 改为 none 启用阻止
```

### 添加更多 WAF 规则

```typescript
// 添加 SQL 注入防护
{
  name: 'AWSManagedRulesSQLiRuleSet',
  priority: 3,
  statement: {
    managedRuleGroupStatement: {
      vendorName: 'AWS',
      name: 'AWSManagedRulesSQLiRuleSet',
    },
  },
  overrideAction: { none: {} },
  visibilityConfig: {
    sampledRequestsEnabled: true,
    cloudWatchMetricsEnabled: true,
    metricName: 'SQLiRuleSetMetric',
  },
}
```

### 使用 OWASP JuiceShop 作为后端

```bash
# 在 EC2 上部署 JuiceShop (替换 nginx)
docker run -d -p 80:3000 bkimminich/juice-shop
```

## 安全说明

### 凭证管理

本项目**不包含任何硬编码的 AWS 凭证**。部署时使用以下方式获取凭证:

| 配置项 | 来源 | 说明 |
|--------|------|------|
| AWS Account ID | `CDK_DEFAULT_ACCOUNT` 环境变量 | CDK 自动从 AWS CLI 配置获取 |
| AWS Region | 硬编码 `us-east-1` | CloudFront WAF 必须部署在 us-east-1 |
| AWS Credentials | AWS CLI Profile | 通过 `aws configure` 配置 |

### 部署前检查

```bash
# 确认 AWS CLI 已配置
aws sts get-caller-identity

# 确认有足够权限 (需要 WAF, CloudFront, S3, CloudWatch, IAM 权限)
```

### 敏感信息

- ❌ 不要将 AWS Access Key 提交到代码仓库
- ❌ 不要在代码中硬编码 Account ID
- ✅ 使用环境变量或 AWS CLI Profile
- ✅ 使用 IAM Role (推荐用于生产环境)

## 参考文档

- [AWS WAF Bot Control](https://docs.aws.amazon.com/waf/latest/developerguide/waf-bot-control.html)
- [WAF 日志字段](https://docs.aws.amazon.com/waf/latest/developerguide/logging-fields.html)
- [CloudWatch Logs Insights 语法](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [AWS CDK 安全最佳实践](https://docs.aws.amazon.com/cdk/v2/guide/best-practices.html)

## License

MIT
