
from playwright.sync_api import sync_playwright
import time

def verify_chart():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Mock Session
        page.add_init_script("""
            window.localStorage.setItem('sb-fpvhl...-auth-token', JSON.stringify({
                user: { id: 'test-user', email: 'test@example.com' },
                access_token: 'mock-token'
            }));
            window.localStorage.setItem('user_auth_cache_test-user', JSON.stringify({
                status: 'aprovado',
                role: 'adm'
            }));
        """)

        # Mock RPC calls
        page.route('**/rest/v1/rpc/get_dashboard_filters', lambda route: route.fulfill(json={
            'filiais': ['01'], 'cidades': ['City A'], 'supervisors': ['Sup A'],
            'vendedores': ['Vend A'], 'fornecedores': [], 'tipos_venda': [], 'redes': [], 'categorias': [],
            'anos': [2024, 2025]
        }))

        # Mock Data for Chart
        page.route('**/rest/v1/rpc/get_main_dashboard_data', lambda route: route.fulfill(json={
            'kpi_clients_attended': 100,
            'current_year': 2025,
            'previous_year': 2024,
            'monthly_data_current': [{'month_index': 0, 'faturamento': 1000, 'peso': 500}],
            'monthly_data_previous': [{'month_index': 0, 'faturamento': 800, 'peso': 400}],
            'trend_allowed': False
        }))

        try:
            print("Navigating...")
            page.goto('http://localhost:8080')

            # Force Layout if needed
            page.evaluate("""
                document.getElementById('app-layout')?.classList.remove('hidden');
                document.getElementById('login-view')?.classList.add('hidden');
                document.getElementById('main-dashboard-view')?.classList.remove('hidden');
            """)

            page.wait_for_selector('#main-chartContainer', state='visible', timeout=5000)
            print("Chart container found.")

            # Check for AmCharts Canvas inside container
            # amCharts creates a canvas inside the div
            time.sleep(2) # Wait for render

            # Check HTML content of container
            content = page.inner_html('#main-chartContainer')
            if 'canvas' in content or 'am5-layer' in content:
                print("AmCharts elements found in container.")
            else:
                print("WARNING: Container empty or no canvas found.")
                print("Inner HTML:", content)
                raise Exception("Chart not rendered")

            page.screenshot(path='verification/chart_verify.png')
            print("Screenshot saved.")

        except Exception as e:
            print(f"Test Failed: {e}")
            page.screenshot(path='verification/chart_fail.png')
        finally:
            browser.close()

if __name__ == "__main__":
    verify_chart()
