
from playwright.sync_api import sync_playwright
import time

def run(playwright):
    browser = playwright.chromium.launch(headless=True)
    page = browser.new_page()

    page.on("console", lambda msg: print(f"PAGE LOG: {msg.text}"))

    # Navigate
    page.goto("http://localhost:8000")
    time.sleep(2) # Wait for JS load

    # Bypass Login & Force View
    page.evaluate("""
        document.getElementById('login-view').classList.add('hidden');
        document.getElementById('app-layout').classList.remove('hidden');
        document.getElementById('dashboard-container').classList.remove('hidden');

        // Force show Comparison View
        document.getElementById('main-dashboard-view').classList.add('hidden');
        document.getElementById('comparison-view').classList.remove('hidden');
        document.getElementById('comparison-view').style.display = 'block'; // Ensure visibility
    """)

    # Wait for rendering
    time.sleep(1)

    # Check City Filter Dropdown
    print("Checking City Filter...")
    city_btn = page.locator("#comparison-city-filter-btn")

    # Wait for visibility explicitly
    try:
        city_btn.wait_for(state="visible", timeout=5000)
        city_btn.click()
        time.sleep(1)
        page.screenshot(path="verification/city_filter_open.png")
    except Exception as e:
        print(f"City Filter Check Failed: {e}")
        page.screenshot(path="verification/city_filter_fail.png")

    # Check Product Filter Dropdown
    print("Checking Product Filter...")
    prod_btn = page.locator("#comparison-product-filter-btn")
    try:
        prod_btn.wait_for(state="visible", timeout=5000)
        prod_btn.click()
        time.sleep(1)
        page.screenshot(path="verification/product_filter_open.png")
    except Exception as e:
        print(f"Product Filter Check Failed: {e}")

    browser.close()

with sync_playwright() as playwright:
    run(playwright)
