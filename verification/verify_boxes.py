from playwright.sync_api import sync_playwright
import time

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Navigate to Boxes view
        page.goto("http://localhost:8080?view=boxes")

        # Wait for potential loading (or auth screen if applicable)
        # Assuming dev environment might need login or mock.
        # The app has a login screen. I might need to bypass it or check if it appears.
        # If I can't login, I can't see the dashboard.
        # However, checkSession logic:
        # const { data: { session } } = await supabase.auth.getSession();
        # If no session, it shows login-view.

        # I can try to bypass auth by manipulating the DOM or localStorage if possible,
        # but supabase client usually checks real session.
        # Alternative: The user didn't ask for tests, I am doing visual verification.
        # If I can't login, I can't verify.
        # Does the environment have credentials?
        # I'll check if I can just unhide the view for testing purposes or if I'm already logged in (unlikely in new browser instance).

        # Strategy: Inject a mock session or modifying the code to bypass auth for localhost?
        # Or just checking if the Filter Element exists in the DOM even if hidden?
        # The elements are in index.html, just hidden.

        # I'll unhide the boxes-view manually using script if needed.

        time.sleep(2)

        # Force show boxes view
        page.evaluate("""() => {
            document.getElementById('login-view').classList.add('hidden');
            document.getElementById('app-layout').classList.remove('hidden');
            document.getElementById('boxes-view').classList.remove('hidden');
        }""")

        time.sleep(1)

        # Check for Tipo Venda Filter
        filter_btn = page.locator("#boxes-tipovenda-filter-btn")
        if filter_btn.is_visible():
            print("Tipo Venda Filter found.")
        else:
            print("Tipo Venda Filter NOT visible (might be hidden by layout logic or css).")
            # Force unhide for screenshot
            page.evaluate("document.getElementById('boxes-tipovenda-filter-btn').style.display = 'block'")

        # Check KPI Cards
        # Look for text "Ano ant."
        if page.get_by_text("Ano ant.").count() > 0:
            print("KPI 'Ano ant.' text found.")
        else:
            print("KPI 'Ano ant.' text NOT found.")

        if page.get_by_text("Méd. Tri").count() > 0:
            print("KPI 'Méd. Tri' text found.")
        else:
            print("KPI 'Méd. Tri' text NOT found.")

        page.screenshot(path="verification/boxes_view.png")
        browser.close()

if __name__ == "__main__":
    run()
