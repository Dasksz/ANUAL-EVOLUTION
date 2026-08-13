        function parseGoalsSvStructure(text) {
            console.log("[Parser] Iniciando parse...");
            const lines = text.replace(/[\r\n]+$/, '').split(/\r?\n/);
            if (lines.length === 0) return null;

            // 1. Detect Delimiter (Heuristic)
            const firstLine = lines[0];
            let delimiter = '\t';
            if (firstLine.includes('\t')) delimiter = '\t';
            else if (firstLine.includes(';')) delimiter = ';';
            else if (firstLine.includes(',') && lines.length > 1) delimiter = ',';
            // Fallback for space separated copy-paste if single line has spaces
            else if (firstLine.trim().split(/\s{2,}/).length > 1) delimiter = /\s{2,}/; // At least 2 spaces

            console.log("[Parser] Delimitador detectado:", delimiter);

            const rows = lines.map(line => {
                // If delimiter is regex, use split directly
                if (delimiter instanceof RegExp) return line.trim().split(delimiter);
                return line.split(delimiter);
            });

            console.log(`[Parser] Linhas encontradas: ${rows.length}`);

            // 2. Identify Header Rows and Construct ColMap
            const colMap = {};
            let dataStartRow = 0;

            if (rows.length >= 3) {
                // Standard logic: Rows 0, 1, 2
                const startRow = 0;

                const header0 = rows[startRow].map(h => h ? h.trim().toUpperCase() : '');
                const header1 = rows[startRow + 1].map(h => h ? h.trim().toUpperCase() : '');
                const header2 = rows[startRow + 2].map(h => h ? h.trim().toUpperCase() : '');

                console.log("[Parser] Header 0:", header0.join('|'));
                console.log("[Parser] Header 1:", header1.join('|'));
                console.log("[Parser] Header 2:", header2.join('|'));

                let currentCategory = null;
                let currentMetric = null;

                // Map Headers
                for (let i = 0; i < header0.length; i++) {
                    if (header0[i]) currentCategory = header0[i];
                    if (header1[i]) currentMetric = header1[i];
                    let subMetric = header2[i]; // Meta, Ajuste, etc.

                    if (currentCategory && subMetric) {
                        if (subMetric === 'AJ.' || subMetric === 'AJ') subMetric = 'AJUSTE';

                        let catKey = currentCategory;
                        // Normalize Category Names to IDs (Fuzzy Matching)
                        if (catKey.includes('NÃO EXTRUSADOS') || catKey.includes('NAO EXTRUSADOS')) catKey = '708';
                        else if (catKey.includes('EXTRUSADOS')) catKey = '707';
                        else if (catKey.includes('TORCIDA')) catKey = '752';
                        else if (catKey.includes('TODDYNHO')) catKey = '1119_TODDYNHO';
                        else if (catKey.includes('TODDY')) catKey = '1119_TODDY';
                        else if (catKey.includes('QUAKER') || catKey.includes('KEROCOCO')) catKey = '1119_QUAKER_KEROCOCO';
                        else if (catKey === 'KG ELMA') catKey = 'tonelada_elma';
                        else if (catKey === 'KG FOODS') catKey = 'tonelada_foods';
                        else if (catKey === 'TOTAL ELMA') catKey = 'total_elma';
                        else if (catKey === 'TOTAL FOODS') catKey = 'total_foods';
                        else if (catKey === 'MIX SALTY') catKey = 'mix_salty';
                        else if (catKey === 'MIX FOODS') catKey = 'mix_foods';
                        else if (catKey === 'PEPSICO_ALL_POS' || catKey === 'PEPSICO_ALL' || catKey === 'GERAL') catKey = 'pepsico_all';

                        let metricKey = 'OTHER';
                        if (currentMetric === 'FATURAMENTO' || currentMetric === 'MÉDIA TRIM.') metricKey = 'FAT';
                        else if (currentMetric === 'POSITIVAÇÃO' || currentMetric === 'POSITIVACAO' || currentMetric.includes('POSITIVA')) metricKey = 'POS';
                        else if (currentMetric === 'TONELADA' || currentMetric === 'META KG') metricKey = 'VOL';
                        else if (currentMetric === 'META MIX' || currentMetric === 'MIX' || currentMetric === 'QTD') metricKey = 'MIX';

                        const key = `${catKey}_${metricKey}_${subMetric}`;
                        colMap[key] = i;
                    }
                }

                dataStartRow = startRow + 3;
            } else {
                console.warn("[Parser] Menos de 3 linhas. Tentando modo simplificado...");
                // Simplified Mode: Hardcoded Column Map based on Standard Export
                // Columns structure matches exportGoalsSvXLSX

                let colIdx = 2; // Start after Vendedor (Index 2)
                const addKeys = (cat, keys) => {
                    keys.forEach((k, i) => {
                        if (k) colMap[`${cat}_${k}`] = colIdx + i;
                    });
                    colIdx += keys.length;
                };

                // 1. TOTAL ELMA (Standard Agg)
                addKeys('total_elma', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 2. EXTRUSADOS (707)
                addKeys('707', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 3. NÃO EXTRUSADOS (708)
                addKeys('708', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 4. TORCIDA (752)
                addKeys('752', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 5. KG ELMA (tonnage)
                addKeys('tonelada_elma', [null, 'VOL_VOLUME', 'VOL_AJUSTE']);
                // 6. MIX SALTY (mix)
                addKeys('mix_salty', [null, 'MIX_META', 'MIX_AJUSTE']);

                // 7. TOTAL FOODS (Standard Agg)
                addKeys('total_foods', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 8. TODDYNHO (1119_TODDYNHO)
                addKeys('1119_TODDYNHO', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 9. TODDY (1119_TODDY)
                addKeys('1119_TODDY', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 10. QUAKER/KEROCOCO
                addKeys('1119_QUAKER_KEROCOCO', ['FAT_META', 'FAT_AJUSTE', 'POS_META', 'POS_AJUSTE']);
                // 11. KG FOODS (tonnage)
                addKeys('tonelada_foods', [null, 'VOL_VOLUME', 'VOL_AJUSTE']);
                // 12. MIX FOODS (mix)
                addKeys('mix_foods', [null, 'MIX_META', 'MIX_AJUSTE']);

                // 13. GERAL (pepsico_all)
                addKeys('pepsico_all', [null, 'FAT_META', 'VOL_META', 'POS_META']);

                // 14. PEDEV
                colIdx += 1;

                dataStartRow = 0; // Parse all rows
            }

            const updates = [];
            const processedSellers = new Set();

            const parseImportValue = (rawStr) => {
                if (!rawStr) return NaN;
                let clean = String(rawStr).trim().toUpperCase().replace(/[^0-9,.-]/g, '');
                if (!clean) return NaN;

                const dotIdx = clean.lastIndexOf('.');
                const commaIdx = clean.lastIndexOf(',');
                
                if (dotIdx > -1 && commaIdx > -1) {
                    if (dotIdx > commaIdx) clean = clean.replace(/,/g, ''); 
                    else clean = clean.replace(/\./g, '').replace(',', '.');
                } else if (commaIdx > -1) {
                    // Has comma, no dot. Assume comma is decimal in Brazil
                    // However, if the user exported raw CSV without decimals for thousands (e.g. 1,234 meaning 1234)
                    // it is highly ambiguous. In this system, we mostly use Brazilian format (1,234 is 1.234)
                    // We remove the old /,\d{3}$/ check because volume is often 3 decimals (e.g., 2,600 kg = 2.6).
                    clean = clean.replace(',', '.');
                } else if (dotIdx > -1) {
                    // Has dot, no comma.
                    // If it has multiple dots, they are definitely thousands separators.
                    if (clean.split('.').length > 2) {
                        clean = clean.replace(/\./g, '');
                    } else {
                        // Single dot. In raw Excel data or standard floats (e.g., 1359.041), this is a decimal point.
                        // We DO NOT remove it. Removing it would inflate the value 1000x for volume.
                    }
                }
                return parseFloat(clean);
            };
            // Identify Vendor Column Index (Name)
            // Usually Index 1 (Code, Name, ...)
            // We scan first few rows to find valid seller names
            let nameColIndex = 1; 
            // Basic Heuristic: If col 0 looks like a name and col 1 is number, maybe it's col 0.
            // But standard template is [Code, Name, ...]. We stick to 1 for now or 0 if 1 is empty.

            for (let i = dataStartRow; i < rows.length; i++) {
                const row = rows[i];
                if (!row || row.length < 2) continue;

                // Try col 1 for name, fallback to col 0 if col 1 is empty/numeric
                let sellerName = row[1];
                let sellerCodeCandidate = row[0]; // Candidate for Code

                if (!sellerName || !isNaN(parseImportValue(sellerName))) {
                     // If col 1 is number, maybe col 0 is name? Or col 2?
                     // Standard: Col 0 = Code, Col 1 = Name.
                     if (row[0] && isNaN(parseImportValue(row[0]))) {
                         sellerName = row[0];
                         sellerCodeCandidate = null; // Name is in Col 0
                     }
                }

                if (!sellerName) continue; 
                
                // --- ENHANCED FILTER: Ignore Supervisors, Aggregates, and BALCAO ---
                const upperName = sellerName.normalize('NFD').replace(/[\u0300-\u036f]/g, "").toUpperCase().trim();
                
                // 1. Explicit Blocklist
                if (upperName === 'BALCAO' || upperName === 'BALCÃO' || 
                    upperName.includes('TOTAL') || upperName.includes('SUPERVISOR') || upperName.includes('GERAL') ||
                    upperName === 'VENDEDOR' || upperName === 'NOME' || upperName === 'CODIGO' || upperName === 'CÓDIGO') {
                    continue;
                }

                // --- RESOLUTION LOGIC: Normalize Seller Name to System Canonical Name ---
                let canonicalName = null;

                // 1. Try by Code (Col 0)
                if (sellerCodeCandidate) {
                    const parsedCode = parseImportValue(sellerCodeCandidate);
                    if (!isNaN(parsedCode)) {
                        const codeStr = String(parsedCode);
                        if (optimizedData.rcaNameByCode.has(codeStr)) {
                            canonicalName = optimizedData.rcaNameByCode.get(codeStr);
                        }
                    }
                }

                // 2. Try by Name (Fuzzy/Case-Insensitive)
                if (!canonicalName) {
                    // Iterate existing system names to find case-insensitive match
                    for (const [sysName, sysCode] of optimizedData.rcaCodeByName) {
                         const sysUpper = sysName.normalize('NFD').replace(/[\u0300-\u036f]/g, "").toUpperCase().trim();
                         if (sysUpper === upperName) {
                             canonicalName = sysName;
                             break;
                         }
                    }
                }

                const finalSellerName = canonicalName || sellerName;

                // 2. Dynamic Supervisor Check
                // If the name is a known Supervisor (key in rcasBySupervisor), ignore it.
                // Assuming supervisors are not also sellers in this context (or we only want leaf sellers).
                if (optimizedData.rcasBySupervisor.has(finalSellerName) || optimizedData.rcasBySupervisor.has(finalSellerName.toUpperCase())) {
                    continue;
                }
                // ------------------------------------------------

                if (processedSellers.has(finalSellerName)) continue;
                processedSellers.add(finalSellerName);

                // Helper to get value with priority: Adjust > Meta
                const getPriorityValue = (cat, metric) => {
                    // 1. Try AJUSTE
                    let idx = colMap[`${cat}_${metric}_AJUSTE`];
                    if (idx !== undefined && row[idx]) {
                        const val = parseImportValue(row[idx]);
                        if (!isNaN(val)) return val;
                    }
                    // 2. Try META
                    idx = colMap[`${cat}_${metric}_META`];
                    if (idx !== undefined && row[idx]) {
                        const val = parseImportValue(row[idx]);
                        if (!isNaN(val)) return val;
                    }
                    return NaN;
                };

                // 1. Revenue
                const revCats = ['707', '708', '752', '1119_TODDYNHO', '1119_TODDY', '1119_QUAKER_KEROCOCO'];
                revCats.forEach(cat => {
                    const val = getPriorityValue(cat, 'FAT');
                    if (!isNaN(val)) updates.push({ type: 'rev', seller: sellerName, category: cat, val: val });
                });

                // 2. Volume
                // Metas de Volume são importadas pelos Totais (KG ELMA / KG FOODS) e distribuídas automaticamente
                const volCats = ['tonelada_elma', 'tonelada_foods'];
                volCats.forEach(cat => {
                    const val = getPriorityValue(cat, 'VOL');
                    if (!isNaN(val)) updates.push({ type: 'vol', seller: sellerName, category: cat, val: val });
                });

                // 3. Positivation
                const posCats = ['pepsico_all', 'total_elma', 'total_foods', '707', '708', '752', '1119_TODDYNHO', '1119_TODDY', '1119_QUAKER_KEROCOCO'];
                posCats.forEach(cat => {
                    const val = getPriorityValue(cat, 'POS');
                    if (!isNaN(val)) updates.push({ type: 'pos', seller: sellerName, category: cat, val: Math.round(val) });
                });

                // 4. Mix
                const mixCats = ['mix_salty', 'mix_foods'];
                mixCats.forEach(cat => {
                    const val = getPriorityValue(cat, 'MIX');
                    if (!isNaN(val)) updates.push({ type: 'mix', seller: sellerName, category: cat, val: Math.round(val) });
                });
            }
            return updates;
        }
// Mock fallback for optimizedData if missing since legacy parser relies on it
if (typeof window.optimizedData === 'undefined') {
    window.optimizedData = { rcasBySupervisor: new Map() };
};
window.parseGoalsSvStructure = parseGoalsSvStructure;
