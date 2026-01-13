
from playwright.sync_api import sync_playwright
import time

def verify_frontend():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Navigate to the page
        page.goto("http://localhost:8000")

        # Wait for potential initial load
        time.sleep(2)

        # Inject script to bypass login and show layout
        page.evaluate("""
            const loginView = document.getElementById('login-view');
            const appLayout = document.getElementById('app-layout');
            const telaLoading = document.getElementById('tela-loading');

            if (loginView) loginView.classList.add('hidden');
            if (telaLoading) telaLoading.classList.add('hidden');
            if (appLayout) {
                appLayout.classList.remove('hidden');
                // Attempt to trigger init dashboard logic if possible, or just view static layout
                // Since we can't easily fake the session for RPCs without credentials,
                // we focus on verifying the HTML structure exists.
            }
        """)

        # Click on Comparison Nav Button
        comparison_btn = page.locator("#nav-comparativo-btn")
        if comparison_btn.is_visible():
            comparison_btn.click()
            time.sleep(1) # Wait for view switch

            # Check for new filters
            year_filter = page.locator("#comparison-ano-filter")
            month_filter = page.locator("#comparison-mes-filter")

            print(f"Year Filter Visible: {year_filter.is_visible()}")
            print(f"Month Filter Visible: {month_filter.is_visible()}")

            # Take screenshot
            page.screenshot(path="verification/comparison_view.png")
        else:
            print("Comparison button not found or visible.")
            page.screenshot(path="verification/error_view.png")

        browser.close()

if __name__ == "__main__":
    verify_frontend()
