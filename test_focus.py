from playwright.sync_api import sync_playwright

def run_cuj(page):
    # Navigate to local file since this is a static project
    import os
    file_path = f"file://{os.path.abspath('index.html')}"
    page.goto(file_path)
    page.wait_for_timeout(500)

    # Tab to focus the first input (email)
    page.keyboard.press("Tab")
    page.wait_for_timeout(500)

    # Tab to password
    page.keyboard.press("Tab")
    page.wait_for_timeout(500)

    # Tab to toggle password visibility
    page.keyboard.press("Tab")
    page.wait_for_timeout(500)

    # Tab to remember me
    page.keyboard.press("Tab")
    page.wait_for_timeout(500)

    # Tab to forgot password
    page.keyboard.press("Tab")
    page.wait_for_timeout(500)

    # Tab to submit button (ENTRAR)
    page.keyboard.press("Tab")
    page.wait_for_timeout(500)

    # Take screenshot of the focused submit button
    page.screenshot(path="/home/jules/verification/screenshots/verification.png")
    page.wait_for_timeout(1000)

if __name__ == "__main__":
    import os
    os.makedirs("/home/jules/verification/videos", exist_ok=True)
    os.makedirs("/home/jules/verification/screenshots", exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            record_video_dir="/home/jules/verification/videos"
        )
        page = context.new_page()
        try:
            run_cuj(page)
        finally:
            context.close()
            browser.close()
