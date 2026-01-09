from playwright.sync_api import sync_playwright

def verify_branch_view(page):
    # Set viewport size
    page.set_viewport_size({"width": 1280, "height": 720})

    # Capture console logs
    page.on("console", lambda msg: print(f"Console: {msg.text}"))

    # Add init script to persist mockSupabase across reloads
    page.add_init_script("""
    window.mockSupabase = {
        auth: {
            getSession: async () => ({ data: { session: { user: { id: 'test-user', email: 'test@example.com' } } }, error: null }),
            onAuthStateChange: (callback) => {
                setTimeout(() => {
                    callback('SIGNED_IN', { user: { id: 'test-user', email: 'test@example.com' } });
                }, 100);
                return { data: { subscription: { unsubscribe: () => {} } } };
            },
            signInWithOAuth: async () => ({ data: {}, error: null }),
            signOut: async () => {}
        },
        from: (table) => {
            if (table === 'profiles') {
                return {
                    select: () => ({
                        eq: () => ({
                            single: async () => ({ data: { status: 'aprovado', role: 'adm' }, error: null })
                        })
                    })
                };
            }
            if (table === 'config_city_branches') {
                 return {
                    select: async () => ({ data: [{cidade: 'SAO PAULO', filial: '01'}, {cidade: 'RIO DE JANEIRO', filial: '02'}], error: null })
                 };
            }
            return { select: () => ({ eq: () => ({ single: async () => ({ data: {}, error: null }) }) }) };
        },
        rpc: async (fn, params) => {
            console.log('RPC Call:', fn, params);
            if (fn === 'get_data_version') return { data: '1.0', error: null };
            if (fn === 'get_dashboard_filters') {
                return {
                    data: {
                        anos: ['2023', '2024'],
                        filiais: ['01', '02'],
                        cidades: ['SAO PAULO', 'RIO DE JANEIRO'],
                        supervisors: ['SUP1'],
                        vendedores: ['VEND1'],
                        fornecedores: [{cod: 'FORN1', name: 'Fornecedor 1'}],
                        tipos_venda: ['VENDA1']
                    },
                    error: null
                };
            }
            if (fn === 'get_main_dashboard_data') {
                // Return dummy data for chart
                const isTrend = params.p_ano !== '2023';
                return {
                    data: {
                        current_year: 2024,
                        previous_year: 2023,
                        target_month_index: 0,
                        kpi_clients_attended: 100,
                        kpi_clients_base: 200,
                        monthly_data_current: [
                            { month_index: 0, faturamento: 10000, peso: 5000 },
                            { month_index: 1, faturamento: 12000, peso: 6000 },
                            { month_index: 2, faturamento: 11000, peso: 5500 },
                            { month_index: 3, faturamento: 13000, peso: 6500 },
                            { month_index: 4, faturamento: 14000, peso: 7000 },
                            { month_index: 5, faturamento: 15000, peso: 7500 },
                            { month_index: 6, faturamento: 16000, peso: 8000 },
                            { month_index: 7, faturamento: 17000, peso: 8500 },
                            { month_index: 8, faturamento: 18000, peso: 9000 },
                            { month_index: 9, faturamento: 19000, peso: 9500 },
                            { month_index: 10, faturamento: 20000, peso: 10000 },
                            { month_index: 11, faturamento: 21000, peso: 10500 }
                        ],
                        monthly_data_previous: [],
                        trend_allowed: true,
                        trend_data: { month_index: 12, faturamento: 22000, peso: 11000 },
                        holidays: []
                    },
                    error: null
                };
            }
            return { data: null, error: null };
        },
        channel: () => ({ on: () => ({ subscribe: () => {} }) }),
        removeChannel: () => {}
    };
    """)

    # Intercept supabase.js import
    page.route("**/src/js/supabase.js", lambda route: route.fulfill(
        status=200,
        content_type="application/javascript",
        body="const mock = window.mockSupabase; export default mock;"
    ))

    # Navigate
    page.goto("http://localhost:8000")

    # Wait for dashboard to load (login bypass)
    # The loading screen should disappear and app layout should appear
    page.wait_for_selector("#app-layout:not(.hidden)", timeout=10000)

    # Open sidebar
    page.click("#open-sidebar-btn")

    # Wait for nav item to be visible
    page.wait_for_selector("#nav-branch-btn", state="visible")

    # Click on Branch View
    page.click("#nav-branch-btn")

    # Wait for branch view to be visible
    page.wait_for_selector("#branch-view:not(.hidden)")

    # Wait a bit for filters to populate
    page.wait_for_timeout(2000)

    # Verify filters are populated
    # Check if Year dropdown has options other than "Todos"
    options = page.eval_on_selector_all("#branch-ano-filter option", "els => els.map(e => e.value)")
    print(f"Branch Year Options: {options}")

    if len(options) <= 1:
        print("FAIL: Branch Year options not populated!")
    else:
        print("SUCCESS: Branch Year options populated.")

    # Take screenshot of the Branch View
    page.screenshot(path="verification/branch_view.png")

if __name__ == "__main__":
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        try:
            verify_branch_view(page)
        except Exception as e:
            print(f"Error: {e}")
            page.screenshot(path="verification/error.png")
        finally:
            browser.close()
