from playwright.sync_api import sync_playwright
import os

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Determine the absolute path to index.html
        cwd = os.getcwd()
        file_path = f"file://{cwd}/index.html"

        print(f"Navigating to {file_path}")
        page.goto(file_path)

        # Inject script to bypass login overlay logic by mocking localStorage and unhiding app-layout
        # We need to simulate the 'isAppReady' state and visibility toggling manually for the static file test
        page.add_init_script("""
            localStorage.setItem('user_auth_cache_test', JSON.stringify({ status: 'aprovado', role: 'adm' }));
            // Mock supabase auth session return for app.js logic if possible,
            // but since we are verifying static HTML structure mainly, we can just force visibility.
        """)

        # Wait for DOM content
        page.wait_for_load_state("domcontentloaded")

        # Force the login overlay to hide and app layout/navbar to show via JS evaluation
        # This simulates a logged-in state without needing the actual Supabase backend connection for this visual check
        page.evaluate("""
            document.getElementById('login-view').classList.add('hidden');
            document.getElementById('app-layout').classList.remove('hidden');
            document.getElementById('top-navbar').classList.remove('hidden');
        """)

        # Verify Navigation Labels
        # Dashboard
        dashboard_btn = page.locator("#nav-dashboard")
        print(f"Dashboard Label: {dashboard_btn.inner_text()}")

        # Cobertura -> Análise por Cidade
        city_btn = page.locator("#nav-city-analysis")
        print(f"City Label: {city_btn.inner_text()}")

        # Geo -> Filiais
        branch_btn = page.locator("#nav-branch-btn")
        print(f"Branch Label: {branch_btn.inner_text()}")

        # Metas -> Caixas
        boxes_btn = page.locator("#nav-boxes-btn")
        print(f"Boxes Label: {boxes_btn.inner_text()}")

        # Take screenshot of the top navigation area
        page.locator("#top-navbar").screenshot(path="verification/nav_labels.png")
        print("Screenshot saved to verification/nav_labels.png")

        browser.close()

if __name__ == "__main__":
    run()
