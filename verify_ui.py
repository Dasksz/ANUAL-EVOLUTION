from playwright.sync_api import sync_playwright

def verify_ui():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Intercept and block supabase requests to not pollute the DB and speed up load
        page.route('**/*', lambda route: route.continue_() if not 'supabase.co' in route.request.url else route.abort())

        # Visit the local app
        page.goto('http://localhost:8000')

        # Expose signup form
        page.click('#link-signup')
        page.wait_for_selector('#signupForm', state='visible')

        # Take screenshot of the signup form
        page.screenshot(path='signup_form_screenshot.png')

        # Check visibility programmatically
        assert page.locator('label[for="signup-name"]').is_visible(), "Name label not visible"
        assert page.locator('label[for="signup-email"]').is_visible(), "Email label not visible"
        assert page.locator('label[for="signup-phone"]').is_visible(), "Phone label not visible"
        assert page.locator('label[for="signup-password"]').is_visible(), "Password label not visible"

        print("Signup form labels successfully verified")

        # Expose forgot password form
        page.click('#link-login-from-signup') # Go back to login
        page.wait_for_selector('#loginForm', state='visible')
        page.click('#link-forgot')
        page.wait_for_selector('#forgotForm', state='visible')

        # Take screenshot of the forgot password form
        page.screenshot(path='forgot_form_screenshot.png')

        # Check visibility programmatically
        assert page.locator('label[for="forgot-email"]').is_visible(), "Forgot email label not visible"
        print("Forgot form label successfully verified")

        browser.close()

if __name__ == "__main__":
    verify_ui()
