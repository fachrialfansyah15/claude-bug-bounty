#!/usr/bin/env python3
"""
Race Condition Tester (Async)
Usage:
    python3 tools/race_condition.py -u "https://target.com/api/coupon" -m POST -d '{"code": "FREE50"}' -c 50
"""
import asyncio
import argparse
import os
import sys
try:
    import aiohttp
except ImportError:
    print("[-] Error: aiohttp is missing. Run: pip install aiohttp")
    sys.exit(1)

from auth_session import session_from_args, AuthSession

async def fetch(session, url, method, headers, data, req_id):
    try:
        async with session.request(method, url, headers=headers, data=data, timeout=10) as response:
            text = await response.text()
            return {"id": req_id, "status": response.status, "length": len(text)}
    except Exception as e:
        return {"id": req_id, "status": 0, "error": str(e)}

async def run_race(url, method, headers, data, concurrency):
    print(f"[*] Starting race condition attack with {concurrency} concurrent requests...")
    print(f"[*] Target: {method} {url}")
    
    async with aiohttp.ClientSession() as session:
        tasks = []
        for i in range(concurrency):
            tasks.append(fetch(session, url, method, headers, data, i+1))
            
        results = await asyncio.gather(*tasks)
        
        # Analyze results
        status_counts = {}
        for r in results:
            s = r['status']
            if s not in status_counts:
                status_counts[s] = 1
            else:
                status_counts[s] += 1
                
        print("\n[+] Race Condition Results:")
        for s, count in status_counts.items():
            if s == 0:
                print(f"    Errors: {count}")
            else:
                print(f"    HTTP {s}: {count} responses")
                
        if len(status_counts) > 1 and 0 not in status_counts:
            print("\n[!] ANOMALY DETECTED: Multiple status codes returned!")
            print("    This is a strong indicator of a race condition (e.g., 1 success, 49 failures).")

def main():
    parser = argparse.ArgumentParser(description="Async Race Condition Tester")
    parser.add_argument("-u", "--url", required=True, help="Target URL")
    parser.add_argument("-m", "--method", default="GET", help="HTTP Method")
    parser.add_argument("-d", "--data", default="", help="POST Data")
    parser.add_argument("-c", "--concurrency", type=int, default=50, help="Number of concurrent requests")
    parser.add_argument("--auth-file", help="Path to auth session JSON")
    args = parser.parse_args()

    headers = {}
    auth = session_from_args(args)
    if not auth.is_empty():
        headers = auth.get_headers()
        print(f"[*] Loaded auth session (Headers: {len(headers)})")

    # For Windows compatibility
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
        
    asyncio.run(run_race(args.url, args.method.upper(), headers, args.data, args.concurrency))

if __name__ == "__main__":
    main()
