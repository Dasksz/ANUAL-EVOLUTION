from playwright.sync_api import sync_playwright
import os

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Load index.html
        cwd = os.getcwd()
        page.goto(f"file://{cwd}/index.html")

        # Manually show city view and hide others
        page.evaluate("""
            document.getElementById('login-view').classList.add('hidden');
            document.getElementById('app-layout').classList.remove('hidden');

            document.getElementById('main-dashboard-header').classList.add('hidden');
            document.getElementById('main-dashboard-content').classList.add('hidden');
            document.getElementById('branch-view').classList.add('hidden');

            document.getElementById('city-view').classList.remove('hidden');
        """)

        # Take screenshot
        os.makedirs("verification", exist_ok=True)
        page.screenshot(path="verification/city_header.png")

        browser.close()

if __name__ == "__main__":
    run()
