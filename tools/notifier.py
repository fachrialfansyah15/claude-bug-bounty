#!/usr/bin/env python3
"""
Notifier — Send alerts to Telegram / Discord
"""
import os
import sys
import json
import requests
from pathlib import Path

BASE_DIR = Path(__file__).parent.parent
NOTIFIER_CONF = BASE_DIR / ".private" / "notifier.json"

def send_alert(message):
    if not NOTIFIER_CONF.exists():
        return False
        
    try:
        with open(NOTIFIER_CONF, "r") as f:
            conf = json.load(f)
            
        tg_token = conf.get("telegram_bot_token")
        tg_chat = conf.get("telegram_chat_id")
        discord_wh = conf.get("discord_webhook")
        
        success = False
        
        import urllib.request
        
        # Telegram
        if tg_token and tg_chat:
            url = f"https://api.telegram.org/bot{tg_token}/sendMessage"
            data = json.dumps({"chat_id": tg_chat, "text": message}).encode("utf-8")
            req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
            try:
                urllib.request.urlopen(req, timeout=10)
                success = True
            except Exception as e:
                print(f"[-] Telegram error: {e}", file=sys.stderr)
                
        # Discord
        if discord_wh:
            r = requests.post(discord_wh, json={"content": message})
            if r.status_code in [200, 204]:
                success = True
                
        return success
    except Exception as e:
        print(f"[-] Notifier error: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    msg = ""
    if len(sys.argv) > 1:
        msg = " ".join(sys.argv[1:])
    else:
        import select
        # Use select to safely check if stdin has data on unix-like systems
        if sys.platform != 'win32':
            i, o, e = select.select([sys.stdin], [], [], 0.0)
            if i:
                msg = sys.stdin.read().strip()
    
    if msg:
        if send_alert(msg):
            print("[+] Notification sent")
        else:
            print("[-] Notification failed or not configured (check .private/notifier.json)")
