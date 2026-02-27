
import asyncio
from playwright.async_api import async_playwright

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        # Capture console logs
        page.on("console", lambda msg: print(f"CONSOLE: {msg.text}"))
        page.on("pageerror", lambda exc: print(f"PAGE ERROR: {exc}"))

        # Mock Supabase Auth in localStorage to bypass login
        await page.add_init_script("""
            localStorage.setItem('user_auth_cache_test-user', JSON.stringify({
                status: 'aprovado',
                role: 'adm'
            }));

            // Mock Supabase client
            window.supabase = {
                auth: {
                    onAuthStateChange: (callback) => {
                        // Simulate signed in
                        callback('SIGNED_IN', { user: { id: 'test-user', email: 'test@example.com' } });
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
                        or: () => Promise.resolve({ data: [], error: null }) // for missing branches
                    })
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
                    return Promise.resolve({ data: null, error: null });
                }
            };

            // Mock module import if needed (but we are loading file directly, so script type=module works if served)
            // However, for file:// access, modules are tricky.
            // We assume we are running against a local server.
        """)

        # We need to serve the directory to avoid CORS issues with modules
        # But for this script, we'll try to just load the page from localhost:8000
        # Assuming the user has a server running or I need to start one.
        # I will start a python http server in background.

        try:
            await page.goto("http://localhost:8000/index.html")

            # Wait for app ready
            try:
                await page.wait_for_selector("#main-dashboard-view", state="visible", timeout=5000)
                print("Main Dashboard View is visible.")
            except:
                print("Main Dashboard View did NOT become visible.")

                # Check visibility of key elements
                login_visible = await page.is_visible("#login-view")
                print(f"Login View Visible: {login_visible}")

                app_layout_visible = await page.is_visible("#app-layout")
                print(f"App Layout Visible: {app_layout_visible}")

                dashboard_visible = await page.is_visible("#dashboard-container")
                print(f"Dashboard Container Visible: {dashboard_visible}")

            await page.screenshot(path="debug_screenshot.png")
            print("Screenshot saved to debug_screenshot.png")

        except Exception as e:
            print(f"Error accessing page: {e}")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(run())
