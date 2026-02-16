from playwright.sync_api import sync_playwright
import time

def verify(page):
    page.set_viewport_size({"width": 1280, "height": 720})

    page.add_init_script("""
        window.userRole = 'adm';
    """)

    page.goto("http://localhost:8080")

    time.sleep(2)

    # Force show dashboard
    page.evaluate("""
        document.getElementById('login-view').classList.add('hidden');
        document.getElementById('app-layout').classList.remove('hidden');
        document.getElementById('dashboard-container').classList.remove('hidden');
        window.userRole = 'adm';
    """)

    # Ensure sidebar is open (desktop it should be visible if layout is responsive, but let's check)
    # If mobile, click hamburger.
    # We set 1280 width, so it should be visible.
    # However, maybe the 'nav-uploader' is hidden behind something or the previous error "element is outside of the viewport" meant it's in the DOM but off-canvas.

    # Let's try to force open sidebar just in case
    page.evaluate("document.getElementById('side-menu').classList.remove('-translate-x-full')")

    time.sleep(1)

    page.click("#nav-uploader")

    page.wait_for_selector("#uploader-modal")

    time.sleep(1)
    page.screenshot(path="verification/uploader_visible.png")

if __name__ == "__main__":
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        try:
            verify(page)
            print("Verification script finished successfully.")
        except Exception as e:
            print(f"Error: {e}")
        finally:
            browser.close()
