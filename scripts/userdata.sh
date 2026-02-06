#!/bin/bash
yum update -y
yum install -y nginx

cat > /usr/share/nginx/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS WAF Bot Analysis Demo</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            color: #fff;
            padding: 40px 20px;
        }
        .container { max-width: 900px; margin: 0 auto; }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            background: linear-gradient(90deg, #00d4ff, #7b2cbf);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle { color: #8892b0; margin-bottom: 40px; font-size: 1.1rem; }
        .card {
            background: rgba(255,255,255,0.05);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 20px;
        }
        .card h2 { color: #00d4ff; margin-bottom: 15px; font-size: 1.3rem; }
        .card p { color: #a8b2d1; line-height: 1.7; }
        .status { display: inline-block; padding: 5px 15px; border-radius: 20px; font-size: 0.85rem; font-weight: 600; background: #064e3b; color: #34d399; }
        .bot-types { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 20px; }
        .bot-type { background: rgba(123,44,191,0.1); border: 1px solid rgba(123,44,191,0.3); border-radius: 8px; padding: 20px; text-align: center; }
        .bot-type .icon { font-size: 2rem; margin-bottom: 10px; }
        .bot-type h3 { color: #c084fc; font-size: 1rem; margin-bottom: 5px; }
        .bot-type p { color: #8892b0; font-size: 0.85rem; }
        footer { text-align: center; margin-top: 40px; color: #64748b; font-size: 0.9rem; }
    </style>
</head>
<body>
    <div class="container">
        <h1>AWS WAF Bot Analysis Demo</h1>
        <p class="subtitle">EC2 Origin Server - Bot traffic analysis endpoint</p>

        <div class="card">
            <h2>Server Status</h2>
            <p><span class="status">Online</span> Origin server is running on EC2</p>
        </div>

        <div class="card">
            <h2>Bot Categories Detected by WAF</h2>
            <div class="bot-types">
                <div class="bot-type"><div class="icon">🔍</div><h3>Search Engine</h3><p>Googlebot, Bingbot</p></div>
                <div class="bot-type"><div class="icon">🕷️</div><h3>Scraping</h3><p>Scrapy, Puppeteer</p></div>
                <div class="bot-type"><div class="icon">📚</div><h3>HTTP Library</h3><p>curl, requests</p></div>
                <div class="bot-type"><div class="icon">🤖</div><h3>AI Bot</h3><p>GPTBot, Claude</p></div>
                <div class="bot-type"><div class="icon">📊</div><h3>Monitoring</h3><p>Pingdom, Datadog</p></div>
                <div class="bot-type"><div class="icon">📱</div><h3>Social Media</h3><p>Twitterbot, Facebot</p></div>
            </div>
        </div>

        <footer><p>Powered by AWS WAF + CloudFront + EC2</p></footer>
    </div>
</body>
</html>
HTMLEOF

cat > /usr/share/nginx/html/api/health << 'JSONEOF'
{"status":"healthy","server":"ec2-origin","timestamp":"dynamic"}
JSONEOF

mkdir -p /usr/share/nginx/html/api
echo '{"status":"ok","data":[1,2,3]}' > /usr/share/nginx/html/api/data

systemctl enable nginx
systemctl start nginx
