
import asyncio
from playwright.async_api import async_playwright

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        # Capture console logs
        page.on("console", lambda msg: print(f"CONSOLE: {msg.text}"))
        page.on("pageerror", lambda exc: print(f"PAGE ERROR: {exc}"))

        # Mock Supabase Module Import
        async def handle_supabase_route(route):
            print(f"Intercepted request: {route.request.url}")
            mock_js = """
            const supabase = {
                auth: {
                    onAuthStateChange: (callback) => {
                        // Simulate signed in
                        console.log('MOCK: onAuthStateChange called');
                        setTimeout(() => {
                            callback('SIGNED_IN', { user: { id: 'test-user', email: 'test@example.com' } });
                        }, 100);
                        return { data: { subscription: { unsubscribe: () => {} } } };
                    },
                    session: () => ({ user: { id: 'test-user' } })
                },
                from: (table) => ({
                    select: () => ({
                        eq: () => ({
                            single: () => Promise.resolve({ data: { status: 'aprovado', role: 'adm' }, error: null }),
                            maybeSingle: () => Promise.resolve({ data: null, error: null }) // for last sales date
                        }),
                        or: () => Promise.resolve({ data: [], error: null }), // for missing branches
                        upsert: () => Promise.resolve({ error: null })
                    }),
                    upsert: () => Promise.resolve({ error: null }),
                    insert: () => Promise.resolve({ error: null })
                }),
                rpc: (func, params) => {
                    console.log(`RPC Called: ${func}`, params);
                    if (func === 'get_dashboard_filters') {
                        return Promise.resolve({ data: {
                            anos: [2024, 2023],
                            filiais: ['01', '02'],
                            cidades: ['City A'],
                            supervisors: ['Sup A'],
                            vendedores: ['Vend A'],
                            fornecedores: ['Forn A'],
                            tipos_venda: ['1'],
                            redes: ['Rede A'],
                            categorias: ['Cat A']
                        }, error: null });
                    }
                    if (func === 'get_main_dashboard_data') {
                        return Promise.resolve({ data: {
                            current_year: 2024,
                            previous_year: 2023,
                            monthly_data_current: [
                                { month_index: 0, faturamento: 1000, peso: 500, bonificacao: 10, devolucao: 5, total_sold_base: 1000 },
                                { month_index: 1, faturamento: 1200, peso: 600, bonificacao: 12, devolucao: 6, total_sold_base: 1200 }
                            ],
                            monthly_data_previous: [
                                { month_index: 0, faturamento: 900, peso: 450, bonificacao: 9, devolucao: 4, total_sold_base: 900 }
                            ],
                            daily_data_current: [],
                            daily_data_previous: [],
                            trend_allowed: false,
                            target_month_index: 1,
                            kpi_clients_attended: 100,
                            kpi_clients_base: 200
                        }, error: null });
                    }
                    if (func === 'get_data_version') {
                        return Promise.resolve({ data: '1.0', error: null });
                    }
                    if (func === 'get_branch_comparison_data') {
                        return Promise.resolve({ data: {}, error: null });
                    }
                    if (func === 'get_city_view_data') {
                         return Promise.resolve({ data: { active_clients: [], inactive_clients: [] }, error: null });
                    }
                    return Promise.resolve({ data: null, error: null });
                }
            };
            export default supabase;
            """
            await route.fulfill(status=200, content_type="application/javascript", body=mock_js)

        # Intercept the supabase.js import
        await page.route("**/src/js/supabase.js*", handle_supabase_route)

        # Also init local storage for the cache check
        await page.add_init_script("""
            localStorage.setItem('user_auth_cache_test-user', JSON.stringify({
                status: 'aprovado',
                role: 'adm'
            }));
        """)

        try:
            print("Navigating to index.html...")
            await page.goto("http://localhost:8000/index.html")

            # Wait for app ready
            print("Waiting for main-dashboard-view...")
            try:
                await page.wait_for_selector("#main-dashboard-view", state="visible", timeout=10000)
                print("SUCCESS: Main Dashboard View is visible.")
            except:
                print("TIMEOUT: Main Dashboard View did NOT become visible.")

                # Check visibility of key elements
                login_visible = await page.is_visible("#login-view")
                print(f"Login View Visible: {login_visible}")

                app_layout_visible = await page.is_visible("#app-layout")
                print(f"App Layout Visible: {app_layout_visible}")

                dashboard_visible = await page.is_visible("#dashboard-container")
                print(f"Dashboard Container Visible: {dashboard_visible}")

            await page.screenshot(path="debug_screenshot_v2.png")
            print("Screenshot saved to debug_screenshot_v2.png")

        except Exception as e:
            print(f"Error accessing page: {e}")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(run())
