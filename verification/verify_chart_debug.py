
from playwright.sync_api import sync_playwright
import time

def verify_chart():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        page.on("console", lambda msg: print(f"BROWSER CONSOLE: {msg.text}"))

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

        page.route('**/rest/v1/rpc/get_main_dashboard_data', lambda route: route.fulfill(json={
            'kpi_clients_attended': 100,
            'kpi_clients_base': 200,
            'current_year': 2025,
            'previous_year': 2024,
            'monthly_data_current': [{'month_index': 0, 'faturamento': 1000, 'peso': 500, 'bonificacao': 0, 'devolucao': 0}],
            'monthly_data_previous': [{'month_index': 0, 'faturamento': 800, 'peso': 400, 'bonificacao': 0, 'devolucao': 0}],
            'trend_allowed': False,
            'trend_data': None,
            'holidays': []
        }))

        # Mock Table calls (data_detailed for date check)
        page.route('**/rest/v1/data_detailed*', lambda route: route.fulfill(json=[{'dtped': '2025-01-01T00:00:00'}]))

        # Mock Config City Branches (used in app load)
        page.route('**/rest/v1/config_city_branches*', lambda route: route.fulfill(json=[]))

        try:
            print("Navigating...")
            page.goto('http://localhost:8080')

            # Force Layout if needed (mimic app readiness)
            page.evaluate("""
                document.getElementById('app-layout')?.classList.remove('hidden');
                document.getElementById('login-view')?.classList.add('hidden');
                document.getElementById('main-dashboard-view')?.classList.remove('hidden');
            """)

            # Wait for data load
            time.sleep(3)

            # Check container
            page.wait_for_selector('#main-chartContainer', state='attached', timeout=5000)

            # Check content
            content = page.inner_html('#main-chartContainer')
            # print(f"Container HTML: '{content}'")

            if 'canvas' in content or 'am5-layer' in content:
                print("SUCCESS: AmCharts elements found.")
            else:
                print("FAILURE: Container empty.")

            page.screenshot(path='verification/chart_debug_fixed.png')

        except Exception as e:
            print(f"Test Failed: {e}")
        finally:
            browser.close()

if __name__ == "__main__":
    verify_chart()
