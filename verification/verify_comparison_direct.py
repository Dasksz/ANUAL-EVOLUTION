
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

        # Inject script to bypass login and show comparison view directly
        page.evaluate("""
            const loginView = document.getElementById('login-view');
            const appLayout = document.getElementById('app-layout');
            const telaLoading = document.getElementById('tela-loading');

            if (loginView) loginView.classList.add('hidden');
            if (telaLoading) telaLoading.classList.add('hidden');
            if (appLayout) appLayout.classList.remove('hidden');

            // Hide other views
            document.getElementById('main-dashboard-view').classList.add('hidden');
            document.getElementById('city-view').classList.add('hidden');
            document.getElementById('branch-view').classList.add('hidden');

            // Show Comparison View
            const comparisonView = document.getElementById('comparison-view');
            if (comparisonView) comparisonView.classList.remove('hidden');
        """)

        time.sleep(1)

        # Check for new filters
        year_filter = page.locator("#comparison-ano-filter")
        month_filter = page.locator("#comparison-mes-filter")

        if year_filter.is_visible() and month_filter.is_visible():
            print("Year and Month filters are visible.")
            # Take screenshot of the filter section
            page.screenshot(path="verification/comparison_view_filters.png")
        else:
            print("Filters not visible.")
            page.screenshot(path="verification/comparison_view_fail.png")

        browser.close()

if __name__ == "__main__":
    verify_frontend()
