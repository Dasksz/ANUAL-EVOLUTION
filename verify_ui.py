
from playwright.sync_api import sync_playwright
import time

def verify_upload_button():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto("http://localhost:8080/index.html")

        # Simulate admin login state by modifying DOM directly
        page.evaluate("() => { \
            window.userRole = 'adm'; \
            document.getElementById('login-view').classList.add('hidden'); \
            document.getElementById('app-layout').classList.remove('hidden'); \
            document.getElementById('top-navbar').classList.remove('hidden'); \
            document.getElementById('nav-uploader').classList.remove('hidden'); \
        }")

        # Wait a bit for layout
        time.sleep(1)

        # Verify button exists in actions area
        uploader_btn = page.locator("#nav-uploader")

        if uploader_btn.is_visible():
            print("Upload button is visible.")

            # Click it
            uploader_btn.click()
            time.sleep(1)

            # Verify modal opened
            modal = page.locator("#uploader-modal")
            if modal.is_visible():
                print("Modal opened successfully.")

                # Take screenshot of open modal
                page.screenshot(path="verification_modal_open.png")

                # Close modal
                close_btn = page.locator("#close-uploader-btn")
                close_btn.click()
                time.sleep(0.5)

                if not modal.is_visible():
                    print("Modal closed successfully.")
                else:
                    print("Error: Modal did not close.")
            else:
                print("Error: Modal did not open.")
                page.screenshot(path="verification_modal_error.png")
        else:
            print("Error: Upload button not found or not visible.")
            page.screenshot(path="verification_btn_error.png")

        # Take screenshot of the navbar with the button
        page.screenshot(path="verification_navbar.png")

        browser.close()

if __name__ == "__main__":
    verify_upload_button()
