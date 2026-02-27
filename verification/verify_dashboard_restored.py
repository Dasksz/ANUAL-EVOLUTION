
from playwright.sync_api import sync_playwright
import os

def verify_dashboard_load():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # Inject Mock Data for Supabase
        page.add_init_script("""
            window.localStorage.setItem('user_auth_cache_123', JSON.stringify({ status: 'aprovado', role: 'admin' }));

            // Mock Supabase
            window.supabase = {
                auth: {
                    onAuthStateChange: (cb) => {
                        cb('SIGNED_IN', { user: { id: '123', email: 'test@example.com' } });
                        return { data: { subscription: { unsubscribe: () => {} } } };
                    },
                    session: () => ({ user: { id: '123' } })
                },
                from: () => ({
                    select: () => ({
                        eq: () => ({
                            single: () => Promise.resolve({ data: { status: 'aprovado', role: 'admin' }, error: null }),
                            maybeSingle: () => Promise.resolve({ data: { dtped: '2025-01-01' }, error: null })
                        }),
                        order: () => ({
                            limit: () => ({
                                maybeSingle: () => Promise.resolve({ data: { dtped: '2025-01-01' }, error: null })
                            })
                        })
                    })
                }),
                rpc: (name, params) => {
                    console.log('RPC Call:', name, params);
                    if (name === 'get_data_version') return Promise.resolve({ data: '1.0', error: null });
                    if (name === 'get_dashboard_filters') return Promise.resolve({
                        data: {
                            anos: ['2025', '2024'],
                            filiais: ['Filial A'],
                            cidades: ['City X'],
                            supervisors: ['Sup 1'],
                            vendedores: ['Vend 1'],
                            fornecedores: [{cod: '1', name: 'Forn 1'}],
                            tipos_venda: ['1'],
                            redes: ['Rede A'],
                            categorias: ['Cat A']
                        },
                        error: null
                    });
                    if (name === 'get_main_dashboard_data') return Promise.resolve({
                        data: {
                            current_year: 2025,
                            previous_year: 2024,
                            monthly_data_current: Array(12).fill({ month_index: 0, faturamento: 1000, peso: 500, bonificacao: 100, devolucao: 50, clients: 10 }),
                            monthly_data_previous: Array(12).fill({ month_index: 0, faturamento: 900, peso: 450, bonificacao: 90, devolucao: 45, clients: 9 }),
                            kpi_clients_attended: 150,
                            kpi_clients_base: 200,
                            target_month_index: 0,
                            trend_allowed: true,
                            trend_data: { month_index: 0, faturamento: 1200, peso: 600 }
                        },
                        error: null
                    });
                    return Promise.resolve({ data: {}, error: null });
                }
            };
        """)

        # Load local file
        cwd = os.getcwd()
        page.goto(f"file://{cwd}/index.html")

        # Wait for dashboard to load (checking for a known element)
        try:
            page.wait_for_selector("#main-dashboard-view", state="visible", timeout=5000)
            print("Dashboard view visible.")
        except:
            print("Dashboard view not immediately visible, checking login flow...")

        # Take screenshot
        os.makedirs("verification", exist_ok=True)
        screenshot_path = os.path.join(cwd, "verification/dashboard_restored.png")
        page.screenshot(path=screenshot_path)
        print(f"Screenshot saved to {screenshot_path}")

        browser.close()

if __name__ == "__main__":
    verify_dashboard_load()
