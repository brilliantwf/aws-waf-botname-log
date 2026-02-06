-- ============================================================
-- CloudWatch Logs Insights Queries for WAF Bot Analysis
-- Log Group: aws-waf-logs-demo-bot-analysis
-- ============================================================

-- ============================================================
-- 1. BASIC QUERIES
-- ============================================================

-- 1.1 All requests in the last hour
fields @timestamp, action, httpRequest.clientIp, httpRequest.uri, httpRequest.httpMethod
| sort @timestamp desc
| limit 100

-- 1.2 Count requests by action (ALLOW, BLOCK, COUNT)
fields action
| stats count(*) as request_count by action
| sort request_count desc

-- 1.3 Top 10 client IPs by request count
fields httpRequest.clientIp as clientIp
| stats count(*) as requests by clientIp
| sort requests desc
| limit 10


-- ============================================================
-- 2. BOT DETECTION QUERIES
-- ============================================================

-- 2.1 Extract bot labels from requests (Bot Name)
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| parse @message /awswaf:managed:aws:bot-control:bot:name:(?<bot_name>[^"]+)/
| filter ispresent(bot_name)
| stats count(*) as count by bot_name
| sort count desc

-- 2.2 Extract bot categories
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<bot_category>[^"]+)/
| filter ispresent(bot_category)
| stats count(*) as count by bot_category
| sort count desc

-- 2.3 Verified vs Unverified bots
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:(?<verification>verified|unverified)/
| filter ispresent(verification)
| stats count(*) as count by verification

-- 2.4 Bot organizations (Google, Microsoft, etc.)
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:organization:(?<organization>[^"]+)/
| filter ispresent(organization)
| stats count(*) as count by organization
| sort count desc

-- 2.5 Signal-based detections (automated browser, non-browser UA, etc.)
fields @timestamp, httpRequest.clientIp
| parse @message /awswaf:managed:aws:bot-control:signal:(?<signal>[^"]+)/
| filter ispresent(signal)
| stats count(*) as count by signal
| sort count desc


-- ============================================================
-- 3. DETAILED BOT ANALYSIS
-- ============================================================

-- 3.1 Full bot details with all labels
fields @timestamp, 
       httpRequest.clientIp as ip,
       httpRequest.uri as uri,
       httpRequest.country as country,
       action
| parse @message /awswaf:managed:aws:bot-control:bot:name:(?<bot_name>[^"]+)/
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<bot_category>[^"]+)/
| parse @message /awswaf:managed:aws:bot-control:bot:(?<verified>verified|unverified)/
| filter ispresent(bot_name) or ispresent(bot_category)
| display @timestamp, ip, uri, bot_name, bot_category, verified, action
| sort @timestamp desc
| limit 50

-- 3.2 HTTP Library bots (curl, python-requests, etc.)
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<category>[^"]+)/
| filter category = "http_library"
| stats count(*) as count by httpRequest.clientIp
| sort count desc

-- 3.3 Scraping framework detections
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<category>[^"]+)/
| filter category = "scraping_framework"
| stats count(*) as count by httpRequest.clientIp
| sort count desc

-- 3.4 AI bots (GPTBot, Claude, etc.)
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<category>[^"]+)/
| parse @message /awswaf:managed:aws:bot-control:bot:name:(?<bot_name>[^"]+)/
| filter category = "ai"
| display @timestamp, httpRequest.clientIp, bot_name, httpRequest.uri
| sort @timestamp desc


-- ============================================================
-- 4. SECURITY ANALYSIS
-- ============================================================

-- 4.1 Blocked requests by rule
fields @timestamp, terminatingRuleId, action, httpRequest.clientIp
| filter action = "BLOCK"
| stats count(*) as blocked_count by terminatingRuleId
| sort blocked_count desc

-- 4.2 Rate-limited IPs
fields @timestamp, httpRequest.clientIp
| filter terminatingRuleId = "RateLimitRule"
| stats count(*) as rate_limited by httpRequest.clientIp
| sort rate_limited desc

-- 4.3 Requests from malicious User-Agents (custom rule)
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| filter terminatingRuleId = "BlockMaliciousUserAgents"
| display @timestamp, httpRequest.clientIp, httpRequest.uri
| sort @timestamp desc

-- 4.4 Requests by country
fields httpRequest.country as country
| stats count(*) as requests by country
| sort requests desc
| limit 20

-- 4.5 Suspicious patterns - High request rate from single IP
fields @timestamp, httpRequest.clientIp
| stats count(*) as request_count by httpRequest.clientIp, bin(5m)
| filter request_count > 100
| sort request_count desc


-- ============================================================
-- 5. USER-AGENT ANALYSIS
-- ============================================================

-- 5.1 Top User-Agents
fields @timestamp
| parse httpRequest.headers.0.value as user_agent
| stats count(*) as count by user_agent
| sort count desc
| limit 20

-- 5.2 Requests with empty or missing User-Agent
fields @timestamp, httpRequest.clientIp, httpRequest.uri
| parse @message /SignalNonBrowserUserAgent/
| stats count(*) as count by httpRequest.clientIp
| sort count desc

-- 5.3 User-Agent distribution by bot category
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<category>[^"]+)/
| parse httpRequest.headers.0.value as user_agent
| filter ispresent(category)
| stats count(*) as count by category, user_agent
| sort count desc
| limit 30


-- ============================================================
-- 6. TIME-BASED ANALYSIS
-- ============================================================

-- 6.1 Requests per minute timeline
fields @timestamp
| stats count(*) as requests by bin(1m)
| sort @timestamp asc

-- 6.2 Bot traffic over time
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:category:(?<category>[^"]+)/
| filter ispresent(category)
| stats count(*) as bot_requests by bin(5m), category
| sort @timestamp asc

-- 6.3 Blocked vs Allowed over time
fields @timestamp, action
| stats count(*) as count by bin(5m), action
| sort @timestamp asc

-- 6.4 Peak traffic hours
fields @timestamp
| stats count(*) as requests by datefloor(@timestamp, 1h)
| sort requests desc
| limit 24


-- ============================================================
-- 7. RULE GROUP ANALYSIS
-- ============================================================

-- 7.1 Rules that matched (non-terminating)
fields @timestamp
| parse @message /"ruleId":"(?<rule_id>[^"]+)"/
| filter ispresent(rule_id)
| stats count(*) as matches by rule_id
| sort matches desc

-- 7.2 Bot Control rule matches
fields @timestamp
| filter @message like /AWSManagedRulesBotControlRuleSet/
| parse @message /"ruleId":"(?<rule_id>[^"]+)"/
| stats count(*) as count by rule_id
| sort count desc

-- 7.3 Common Rule Set matches
fields @timestamp
| filter @message like /AWSManagedRulesCommonRuleSet/
| parse @message /"ruleId":"(?<rule_id>[^"]+)"/
| stats count(*) as count by rule_id
| sort count desc


-- ============================================================
-- 8. DASHBOARD QUERIES (for CloudWatch Dashboard)
-- ============================================================

-- 8.1 Total requests (single stat)
stats count(*) as total_requests

-- 8.2 Blocked requests percentage
fields action
| stats count(*) as total, 
        sum(action="BLOCK") as blocked
| display blocked * 100.0 / total as blocked_percentage

-- 8.3 Unique bot types detected
fields @timestamp
| parse @message /awswaf:managed:aws:bot-control:bot:name:(?<bot_name>[^"]+)/
| filter ispresent(bot_name)
| stats count_distinct(bot_name) as unique_bots

-- 8.4 Top 5 attacking IPs (for table widget)
fields httpRequest.clientIp as ip
| filter action = "BLOCK" or action = "COUNT"
| stats count(*) as suspicious_requests by ip
| sort suspicious_requests desc
| limit 5
