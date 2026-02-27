from playwright.sync_api import sync_playwright
import os

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

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
                        cb('SIGNED_IN', { user: { id: 'mock-user-id', email: 'test@example.com' } });
                        return { data: { subscription: { unsubscribe: () => {} } } };
                    },
                    session: () => ({ user: { id: 'mock-user-id' } })
                },
                from: () => ({
                    select: () => ({
                        eq: () => ({
                            single: () => Promise.resolve({ data: { status: 'aprovado', role: 'adm' }, error: null })
                        })
                    })
                }),
                rpc: (fn, args) => {
                    console.log('RPC Call:', fn, args);
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
                    return Promise.resolve({ data: [], error: null });
                }
            };
        """)

        # Determine absolute path to index.html
        cwd = os.getcwd()
        file_url = f"file://{cwd}/index.html"

        print(f"Navigating to {file_url}")
        page.goto(file_url)

        # Wait for dashboard to load (simulated by checking if main dashboard view is visible)
        try:
            page.wait_for_selector('#main-dashboard-view', state='visible', timeout=5000)
            print("Dashboard loaded.")
        except Exception as e:
            print("Dashboard load timeout, checking for errors...")

        # Take screenshot
        screenshot_path = "verification/dashboard_fix_verification.png"
        page.screenshot(path=screenshot_path, full_page=True)
        print(f"Screenshot saved to {screenshot_path}")

        browser.close()

if __name__ == "__main__":
    run()
