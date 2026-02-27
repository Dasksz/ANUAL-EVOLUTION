from playwright.sync_api import sync_playwright
import os
import http.server
import socketserver
import threading
import time

PORT = 8001

def start_server():
    os.chdir(".")
    Handler = http.server.SimpleHTTPRequestHandler
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print("serving at port", PORT)
        httpd.serve_forever()

def run():
    # Start server in thread
    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()
    time.sleep(1)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Capture console logs
        page.on("console", lambda msg: print(f"Browser Console: {msg.text}"))

        # Inject mock data into localStorage to bypass login
        page.add_init_script("""
            localStorage.setItem('user_auth_cache_mock-user-id', JSON.stringify({ status: 'aprovado', role: 'adm' }));
            localStorage.setItem('dashboard_data_version', '1.0');
        """)

        # Mock Supabase
        page.add_init_script("""
            window.supabase = {
                auth: {
                    onAuthStateChange: (cb) => {
                        console.log("Mock onAuthStateChange called");
                        setTimeout(() => {
                            console.log("Triggering SIGNED_IN");
                            cb('SIGNED_IN', { user: { id: 'mock-user-id', email: 'test@example.com' } });
                        }, 500);
                        return { data: { subscription: { unsubscribe: () => {} } } };
                    },
                    session: () => ({ user: { id: 'mock-user-id' } })
                },
                from: (table) => {
                    console.log("Mock DB from:", table);
                    return {
                        select: () => ({
                            eq: () => ({
                                single: () => Promise.resolve({ data: { status: 'aprovado', role: 'adm' }, error: null })
                            })
                        })
                    };
                },
                rpc: (fn, args) => {
                    console.log('RPC Call:', fn);
                    if (fn === 'get_main_dashboard_data') {
                        return Promise.resolve({ data: {
                            current_year: 2025,
                            previous_year: 2024,
                            monthly_data_current: [
                                { month_index: 0, faturamento: 150000, peso: 15000, bonificacao: 1000 },
                                { month_index: 1, faturamento: 160000, peso: 16000, bonificacao: 1200 }
                            ],
                            monthly_data_previous: [
                                { month_index: 0, faturamento: 140000, peso: 14000 },
                                { month_index: 1, faturamento: 145000, peso: 14500 }
                            ],
                            kpi_clients_attended: 150,
                            kpi_clients_base: 200,
                            trend_allowed: true,
                            trend_data: { month_index: 1, faturamento: 165000, peso: 16500 },
                            target_month_index: 1
                        }, error: null });
                    }
                    if (fn === 'get_dashboard_filters') {
                        return Promise.resolve({ data: {
                            anos: [2025, 2024],
                            filiais: ['Filial 1', 'Filial 2'],
                            cidades: ['Cidade A', 'Cidade B'],
                            supervisors: ['Sup 1'],
                            vendedores: ['Vend 1'],
                            fornecedores: ['Forn 1'],
                            tipos_venda: ['1', '5'],
                            redes: ['Rede A'],
                            categorias: ['Cat A']
                        }, error: null });
                    }
                    if (fn === 'get_available_years') return Promise.resolve({ data: [2025, 2024], error: null });

                    return Promise.resolve({ data: [], error: null });
                }
            };
        """)

        # Navigate to localhost
        url = f"http://localhost:{PORT}/index.html"
        print(f"Navigating to {url}")
        page.goto(url)

        # Force wait
        time.sleep(3)

        # Check visibility
        is_login_visible = page.locator('#login-view').is_visible()
        is_dashboard_visible = page.locator('#main-dashboard-view').is_visible()
        print(f"Login Visible: {is_login_visible}, Dashboard Visible: {is_dashboard_visible}")

        # If stuck on login, try to verify if we can check DOM elements
        # Force display dashboard just to see if it rendered (even if hidden)
        if not is_dashboard_visible:
            print("Forcing dashboard visibility for inspection...")
            page.evaluate("""
                document.getElementById('login-view').classList.add('hidden');
                document.getElementById('app-layout').classList.remove('hidden');
                document.getElementById('main-dashboard-view').classList.remove('hidden');
            """)
            time.sleep(1)

        # Check for KPI value
        try:
            kpi_val = page.locator('#kpi-value-trend-fat').inner_text()
            print(f"KPI Value Trend Fat: {kpi_val}")

            if "R$" in kpi_val or "," in kpi_val:
                print("SUCCESS: KPI Card updated with formatted value.")
            else:
                print("FAILURE: KPI Card value is empty or not formatted.")

        except Exception as e:
            print(f"Error checking KPI: {e}")

        # Take screenshot
        screenshot_path = "verification/dashboard_fix_verification_v4.png"
        page.screenshot(path=screenshot_path, full_page=True)
        print(f"Screenshot saved to {screenshot_path}")

        browser.close()

if __name__ == "__main__":
    run()
