import re

with open('src/js/app.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Add isEstrelasInitialized
content = content.replace("let isLojaPerfeitaInitialized = false;", "let isLojaPerfeitaInitialized = false;\n    let isEstrelasInitialized = false;")

# Add nav button var
content = content.replace("const navLojaPerfeitaBtn = document.getElementById('nav-loja-perfeita-btn');", "const navLojaPerfeitaBtn = document.getElementById('nav-loja-perfeita-btn');\n    const navEstrelasBtn = document.getElementById('nav-estrelas-btn');")

# Add view var
content = content.replace("const lojaPerfeitaView = document.getElementById('loja-perfeita-view');", "const lojaPerfeitaView = document.getElementById('loja-perfeita-view');\n    const estrelasView = document.getElementById('estrelas-view');")

# Add to getActiveViewId()
content = content.replace("if (lojaPerfeitaView && !lojaPerfeitaView.classList.contains('hidden')) return 'loja-perfeita';", "if (lojaPerfeitaView && !lojaPerfeitaView.classList.contains('hidden')) return 'loja-perfeita';\n        if (estrelasView && !estrelasView.classList.contains('hidden')) return 'estrelas';")

# Add to resetViews()
content = content.replace("if (lojaPerfeitaView) lojaPerfeitaView.classList.add('hidden');", "if (lojaPerfeitaView) lojaPerfeitaView.classList.add('hidden');\n        if (estrelasView) estrelasView.classList.add('hidden');")

# Add to renderView() switch
render_view_estrelas = """            case 'estrelas':
                if (estrelasView && navEstrelasBtn) {
                    estrelasView.classList.remove('hidden');
                    setActiveNavLink(navEstrelasBtn);
                    renderEstrelasView();
                }
                break;
"""
content = content.replace("case 'loja-perfeita':", render_view_estrelas + "            case 'loja-perfeita':")

# Add to click listener
click_estrelas = """    if (navEstrelasBtn) {
        navEstrelasBtn.addEventListener('click', (e) => {
            if (navigateWithCtrl(e, 'estrelas')) return;
            renderView('estrelas');
        });
    }

"""
content = content.replace("    if (navLojaPerfeitaBtn) {", click_estrelas + "    if (navLojaPerfeitaBtn) {")

with open('src/js/app.js', 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated nav logic")
