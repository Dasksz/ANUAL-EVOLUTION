
from playwright.sync_api import sync_playwright
import time

def run(playwright):
    browser = playwright.chromium.launch(headless=True)
    page = browser.new_page()

    page.on("console", lambda msg: print(f"PAGE LOG: {msg.text}"))

    # Navigate
    page.goto("http://localhost:8000")

    # Bypass Login
    page.evaluate("""
        document.getElementById('login-view').classList.add('hidden');
        document.getElementById('app-layout').classList.remove('hidden');
        document.getElementById('dashboard-container').classList.remove('hidden');
    """)

    time.sleep(1)

    # Open Sidebar
    print("Opening Sidebar...")
    # The button ID depends on which view is active. Initially Dashboard is active?
    # Actually 'nav-dashboard-btn' is default active.
    # We can try clicking the hamburger.
    page.locator("#open-sidebar-btn").click()
    time.sleep(0.5)

    # Click Comparativo Nav
    print("Navigating to Comparativo...")
    page.locator("#nav-comparativo-btn").click()

    # Wait for view load (RPC calls etc)
    time.sleep(3)

    # Check City Filter Dropdown
    print("Checking City Filter...")
    city_btn = page.locator("#comparison-city-filter-btn")
    city_btn.click()
    time.sleep(1)
    page.screenshot(path="verification/city_filter_open_v2.png")

    # Check Product Filter Dropdown
    print("Checking Product Filter...")
    # Close City first
    city_btn.click()
    time.sleep(0.5)

    prod_btn = page.locator("#comparison-product-filter-btn")
    prod_btn.click()
    time.sleep(1)
    page.screenshot(path="verification/product_filter_open_v2.png")

    browser.close()

with sync_playwright() as playwright:
    run(playwright)
