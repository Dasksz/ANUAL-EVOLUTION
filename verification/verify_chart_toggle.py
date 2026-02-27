
from playwright.sync_api import sync_playwright, expect
import os
import json

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Determine absolute path to index.html
        url = "http://localhost:3000/index.html"
        print(f"Navigating to {url}")

        page.goto(url)

        # 1. Login Simulation (remove hidden from app-layout)
        print("Simulating login...")
        page.evaluate("document.getElementById('login-view').classList.add('hidden')")
        page.evaluate("document.getElementById('app-layout').classList.remove('hidden')")
        page.evaluate("document.getElementById('main-dashboard-view').classList.remove('hidden')")

        # 2. Wait for Chart container
        print("Waiting for chart container...")
        page.wait_for_selector("#main-chartContainer")

        # Wait for app.js to fully load and expose the function
        # Since app.js is a module, we might need to wait a bit longer or trigger it.
        # But wait_for_function timeout means it never became true.
        # Maybe because we are running file:// protocol and module scripts have CORS issues?
        # Actually, module scripts <script type="module"> src="file://..." are often blocked by CORS policies in browsers.
        # Playwright usually handles this, but let's check console errors.

        page.on("console", lambda msg: print(f"Console: {msg.text}"))
        page.on("pageerror", lambda err: print(f"Page Error: {err}"))

        # Wait for app.js to fully load and expose the function
        page.wait_for_timeout(2000)

        # Check if function exists
        exists = page.evaluate("typeof window.renderMainChartAmCharts === 'function'")
        if not exists:
            print("Function not found on window. Trying to reload or check errors.")
            # If module failed, we can't do much testing of the JS logic.
            # But let's assume it works if we serve it or just bypass for visual verification of the python script logic if we can.
            # Actually, let's try to just eval the function code directly into the page if it failed to load?
            # No, that's too complex.

            # Let's try to expose it manually if it wasn't exposed?
            # The code `window.renderMainChartAmCharts = ...` is inside DOMContentLoaded.
            # Maybe DOMContentLoaded fired before we removed the hidden class?
            # No, the event listener is set immediately.

            # If using file://, <script type="module"> might be blocked.
            pass
        else:
            print("Function found!")

        # 3. Simulate Data Load (Mock Data for Chart)
        print("Injecting mock data and rendering chart...")
        mock_data = {
            "daily_data_current": [],
            "daily_data_previous": [],
            "monthly_data_current": [
                {"month_index": 0, "faturamento": 1000, "peso": 500},
                {"month_index": 1, "faturamento": 1500, "peso": 750},
                {"month_index": 2, "faturamento": 1200, "peso": 600}
            ],
            "monthly_data_previous": [
                {"month_index": 0, "faturamento": 900, "peso": 450},
                {"month_index": 1, "faturamento": 1400, "peso": 700},
                {"month_index": 2, "faturamento": 1100, "peso": 550}
            ],
            "previous_year": 2024,
            "current_year": 2025,
            "target_month_index": 2,
            "trend_allowed": False
        }

        # Expose mock data to window context and call render function
        json_data = json.dumps(mock_data)
        page.evaluate(f"window.renderMainChartAmCharts({json_data})")

        # Wait for chart to render (switch button should appear)
        page.wait_for_timeout(2000)

        # 4. Interact with Toggle
        # Find the switch button container/label in amCharts is tricky via DOM as it uses Canvas/SVG
        # However, amCharts 5 creates DOM elements for some UI controls if configured, or SVG elements.
        # The switch button in the code uses `am5.Button` which renders into the canvas usually?
        # No, amCharts 5 is SVG based. We can try to click the element.
        # But we need to verify the code change logic, which is internal.

        # Let's take a screenshot of the initial state (Real Value)
        print("Taking initial screenshot (Real Value)...")
        page.screenshot(path="verification/1_initial_real_value.png")

        # To strictly verify the fix, we need to toggle ON then OFF and ensure Y-axis is correct.
        # Since clicking canvas elements in Playwright is hard without exact coords,
        # we can simulate the internal state change if we can access the chart object?
        # The root is stored in `mainChartRoot`.

        print("Toggling to Evolution %...")
        # Simulate toggle active state true
        # We need to find the switch button in the chart children.
        # It's buried in chart.children -> Container -> Button.
        # Accessing via JS evaluation is easier.

        page.evaluate("""
            const root = window.getMainChartRoot();
            // This is a guess on structure based on code: chart.plotContainer.children.push(am5.Container...
            // Actually, we can just find the button by themeTags?
            // The code: themeTags: ["switch"]

            // Let's iterate recursively to find the switch button
            function findSwitch(parent) {
                if (parent.children) {
                    for (let child of parent.children.values) {
                        if (child.get("themeTags") && child.get("themeTags").includes("switch")) {
                            return child;
                        }
                        const found = findSwitch(child);
                        if (found) return found;
                    }
                }
                return null;
            }

            window.toggleBtn = findSwitch(root.container);
            if (window.toggleBtn) {
                window.toggleBtn.set("active", true); // Toggle ON
            }
        """)

        page.wait_for_timeout(1000)
        print("Taking screenshot (Evolution %)...")
        page.screenshot(path="verification/2_evolution_percent.png")

        print("Toggling back to Real Value...")
        page.evaluate("""
            if (window.toggleBtn) {
                window.toggleBtn.set("active", false); // Toggle OFF
            }
        """)

        page.wait_for_timeout(1000)
        print("Taking screenshot (Back to Real Value)...")
        page.screenshot(path="verification/3_back_to_real_value.png")

        browser.close()

if __name__ == "__main__":
    run()
