#!/usr/bin/env python3
"""
AWS WAF Bot Simulator - Generates traffic with various bot User-Agents
to test WAF Bot Control detection and logging.
"""

import argparse
import asyncio
import aiohttp
import random
import time
import json
from datetime import datetime
from typing import List, Dict

BOT_USER_AGENTS: Dict[str, List[str]] = {
    "search_engine": [
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "Mozilla/5.0 (compatible; Bingbot/2.0; +http://www.bing.com/bingbot.htm)",
        "Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)",
        "DuckDuckBot/1.0; (+http://duckduckgo.com/duckduckbot.html)",
        "Mozilla/5.0 (compatible; Baiduspider/2.0; +http://www.baidu.com/search/spider.html)",
    ],
    "scraping_framework": [
        "Scrapy/2.11.0 (+https://scrapy.org)",
        "Mozilla/5.0 (compatible; Scrapy/2.5.0; +https://scrapy.org)",
        "python-scrapy/2.8.0",
    ],
    "http_library": [
        "python-requests/2.31.0",
        "curl/8.1.2",
        "Go-http-client/1.1",
        "axios/1.6.0",
        "node-fetch/3.3.0",
        "Java/17.0.1",
        "libwww-perl/6.67",
        "Ruby",
        "PHP/8.2",
        "wget/1.21",
    ],
    "ai_bot": [
        "GPTBot/1.0 (+https://openai.com/gptbot)",
        "ChatGPT-User/1.0",
        "Claude-Web/1.0",
        "anthropic-ai/1.0",
        "CCBot/2.0 (https://commoncrawl.org/faq/)",
        "Google-Extended",
    ],
    "monitoring": [
        "Pingdom.com_bot_version_1.4",
        "UptimeRobot/2.0",
        "StatusCake",
        "Site24x7",
        "Datadog/Synthetics",
        "NewRelicPinger/1.0",
    ],
    "social_media": [
        "Twitterbot/1.0",
        "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
        "LinkedInBot/1.0",
        "Slackbot-LinkExpanding 1.0",
        "TelegramBot (like TwitterBot)",
        "Discordbot/2.0",
    ],
    "seo_tool": [
        "AhrefsBot/7.0",
        "SemrushBot/7~bl",
        "MJ12bot/v1.4.8",
        "DotBot/1.2",
        "Screaming Frog SEO Spider/19.0",
    ],
    "browser": [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    ],
    "malicious": [
        "malicious-bot/1.0",
        "evil-crawler/2.0",
        "bad-spider",
        "",  # Empty User-Agent
        "sqlmap/1.7",
        "nikto/2.5.0",
    ],
}

ENDPOINTS = ["/", "/api/data", "/login", "/search?q=test", "/products", "/about"]


async def make_request(
    session: aiohttp.ClientSession,
    url: str,
    user_agent: str,
    category: str,
    request_id: int,
) -> Dict:
    endpoint = random.choice(ENDPOINTS)
    full_url = f"{url.rstrip('/')}{endpoint}"

    headers = {"User-Agent": user_agent} if user_agent else {}

    start_time = time.time()
    try:
        async with session.get(full_url, headers=headers, timeout=10) as response:
            elapsed = time.time() - start_time
            return {
                "request_id": request_id,
                "timestamp": datetime.utcnow().isoformat(),
                "url": full_url,
                "category": category,
                "user_agent": user_agent[:50] + "..."
                if len(user_agent) > 50
                else user_agent,
                "status": response.status,
                "elapsed_ms": round(elapsed * 1000, 2),
                "success": True,
            }
    except Exception as e:
        return {
            "request_id": request_id,
            "timestamp": datetime.utcnow().isoformat(),
            "url": full_url,
            "category": category,
            "user_agent": user_agent[:50] + "..."
            if len(user_agent) > 50
            else user_agent,
            "status": 0,
            "error": str(e),
            "success": False,
        }


async def run_bot_simulation(
    url: str,
    count: int,
    categories: List[str],
    concurrency: int,
    delay: float,
) -> List[Dict]:
    results = []
    semaphore = asyncio.Semaphore(concurrency)

    all_user_agents = []
    for category in categories:
        if category in BOT_USER_AGENTS:
            for ua in BOT_USER_AGENTS[category]:
                all_user_agents.append((category, ua))

    if not all_user_agents:
        print(f"No valid categories found. Available: {list(BOT_USER_AGENTS.keys())}")
        return results

    async def bounded_request(session, request_id):
        async with semaphore:
            category, user_agent = random.choice(all_user_agents)
            result = await make_request(session, url, user_agent, category, request_id)
            if delay > 0:
                await asyncio.sleep(delay + random.uniform(0, delay * 0.5))
            return result

    connector = aiohttp.TCPConnector(limit=concurrency, ssl=False)
    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = [bounded_request(session, i) for i in range(count)]
        results = await asyncio.gather(*tasks)

    return results


def print_summary(results: List[Dict]):
    print("\n" + "=" * 60)
    print("BOT SIMULATION SUMMARY")
    print("=" * 60)

    total = len(results)
    successful = sum(1 for r in results if r.get("success"))
    failed = total - successful

    print(f"\nTotal Requests: {total}")
    print(f"Successful: {successful}")
    print(f"Failed: {failed}")

    by_category = {}
    by_status = {}

    for r in results:
        cat = r.get("category", "unknown")
        by_category[cat] = by_category.get(cat, 0) + 1

        status = r.get("status", 0)
        by_status[status] = by_status.get(status, 0) + 1

    print("\nRequests by Category:")
    for cat, count in sorted(by_category.items()):
        print(f"  {cat}: {count}")

    print("\nRequests by Status Code:")
    for status, count in sorted(by_status.items()):
        status_name = {200: "OK", 403: "Forbidden", 404: "Not Found", 0: "Error"}.get(
            status, str(status)
        )
        print(f"  {status} ({status_name}): {count}")

    if results:
        elapsed_times = [r.get("elapsed_ms", 0) for r in results if r.get("success")]
        if elapsed_times:
            avg_time = sum(elapsed_times) / len(elapsed_times)
            print(f"\nAverage Response Time: {avg_time:.2f}ms")

    print("\n" + "=" * 60)


def main():
    parser = argparse.ArgumentParser(
        description="AWS WAF Bot Simulator - Generate bot traffic for testing",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage with 100 requests
  python bot_simulator.py --url https://d123456.cloudfront.net --count 100

  # Test specific bot categories
  python bot_simulator.py --url https://d123456.cloudfront.net --categories http_library scraping_framework

  # High-volume test with more concurrency
  python bot_simulator.py --url https://d123456.cloudfront.net --count 500 --concurrency 20

  # Slow crawl simulation
  python bot_simulator.py --url https://d123456.cloudfront.net --count 50 --delay 2.0

Available categories:
  search_engine, scraping_framework, http_library, ai_bot,
  monitoring, social_media, seo_tool, browser, malicious
        """,
    )

    parser.add_argument(
        "--url",
        "-u",
        required=True,
        help="Target CloudFront distribution URL",
    )
    parser.add_argument(
        "--count",
        "-n",
        type=int,
        default=50,
        help="Number of requests to send (default: 50)",
    )
    parser.add_argument(
        "--categories",
        "-c",
        nargs="+",
        default=list(BOT_USER_AGENTS.keys()),
        help="Bot categories to simulate (default: all)",
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        default=10,
        help="Maximum concurrent requests (default: 10)",
    )
    parser.add_argument(
        "--delay",
        "-d",
        type=float,
        default=0.1,
        help="Delay between requests in seconds (default: 0.1)",
    )
    parser.add_argument(
        "--output",
        "-o",
        help="Output file for detailed results (JSON)",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Print each request result",
    )

    args = parser.parse_args()

    print(f"\nStarting Bot Simulation")
    print(f"Target: {args.url}")
    print(f"Requests: {args.count}")
    print(f"Categories: {', '.join(args.categories)}")
    print(f"Concurrency: {args.concurrency}")
    print(f"Delay: {args.delay}s")
    print("-" * 40)

    results = asyncio.run(
        run_bot_simulation(
            url=args.url,
            count=args.count,
            categories=args.categories,
            concurrency=args.concurrency,
            delay=args.delay,
        )
    )

    if args.verbose:
        for r in results:
            status = "✓" if r.get("success") else "✗"
            print(f"{status} [{r['category']}] {r['status']} - {r['user_agent']}")

    print_summary(results)

    if args.output:
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\nDetailed results saved to: {args.output}")


if __name__ == "__main__":
    main()
