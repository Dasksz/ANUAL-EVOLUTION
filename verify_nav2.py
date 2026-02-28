import asyncio
from playwright.async_api import async_playwright
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler
import threading

def serve():
    class CORSRequestHandler(SimpleHTTPRequestHandler):
        def end_headers(self):
            self.send_header('Access-Control-Allow-Origin', '*')
            super().end_headers()
    server = HTTPServer(('127.0.0.1', 8080), CORSRequestHandler)
    server.serve_forever()

threading.Thread(target=serve, daemon=True).start()

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={'width': 1280, 'height': 800})
        
        await page.goto("http://127.0.0.1:8080/index.html")
        
        # Bypass auth for UI testing (the id is top-navbar but the class is header now)
        await page.evaluate("""
            const login = document.getElementById('login-container');
            if (login) login.classList.add('hidden');
            
            const app = document.getElementById('app-layout');
            if (app) app.classList.remove('hidden');
            
            const nav = document.getElementById('top-navbar');
            if (nav) nav.classList.remove('hidden');
        """)

        await page.screenshot(path="/home/jules/verification/nav_initial.png")
        
        # Force click since playwright might complain about visibility from weird hover states
        print("Clicking Filiais...")
        await page.evaluate("document.getElementById('nav-branch-btn').click()")
        await page.wait_for_timeout(1000)
        await page.screenshot(path="/home/jules/verification/nav_branch_active.png")

        # Test Config Dropdown Click
        print("Clicking Config...")
        await page.evaluate("document.getElementById('nav-config-btn').click()")
        await page.wait_for_timeout(500)
        await page.screenshot(path="/home/jules/verification/nav_config_open.png")

        # Test Profile Dropdown Click
        print("Clicking Profile...")
        await page.evaluate("document.getElementById('nav-profile-btn').click()")
        await page.wait_for_timeout(500)
        await page.screenshot(path="/home/jules/verification/nav_profile_open.png")

        await browser.close()

asyncio.run(main())
