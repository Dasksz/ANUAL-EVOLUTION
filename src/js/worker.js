self.importScripts('https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js');

function parseDate(dateString) {
    if (!dateString) return null;
    if (dateString instanceof Date) return !isNaN(dateString.getTime()) ? dateString : null;
    if (typeof dateString === 'number') return new Date(Math.round((dateString - 25569) * 86400 * 1000));
    if (typeof dateString !== 'string') return null;

    const parts = dateString.split('/');
    if (parts.length === 3) {
        const [day, month, year] = parts;
        if (day.length === 2 && month.length === 2 && year.length === 4) return new Date(`${year}-${month}-${day}T00:00:00`);
    }

    const isoDate = new Date(dateString);
    return !isNaN(isoDate.getTime()) ? isoDate : null;
}

function parseBrazilianNumber(value) {
    if (typeof value === 'number') return value;
    if (typeof value !== 'string' || !value) return 0;
    const cleaned = String(value).replace(/R\$\s?/g, '').trim();
    const lastComma = cleaned.lastIndexOf(',');
    const lastDot = cleaned.lastIndexOf('.');
    let numberString;
    if (lastComma > lastDot) {
        numberString = cleaned.replace(/\./g, '').replace(',', '.');
    } else if (lastDot > lastComma) {
        numberString = cleaned.replace(/,/g, '');
    } else {
        numberString = cleaned.replace(',', '.');
    }
    const number = parseFloat(numberString);
    return isNaN(number) ? 0 : number;
}

function isIbgeCode(value) {
    if (!value) return false;
    const str = String(value).trim();
    return /^\d{6,7}$/.test(str);
}

async function fetchIbgeMapping() {
    try {
        const response = await fetch('https://servicodados.ibge.gov.br/api/v1/localidades/municipios');
        if (!response.ok) throw new Error('Falha ao buscar dados do IBGE');
        const data = await response.json();
        const map = {};
        data.forEach(city => {
            map[String(city.id)] = city.nome.toUpperCase();
        });
        return map;
    } catch (e) {
        console.warn('Erro API IBGE:', e);
        return {};
    }
}

const readFile = (file) => {
    return new Promise((resolve, reject) => {
        if (!file) {
            resolve([]);
            return;
        }
        const reader = new FileReader();
        reader.onload = (event) => {
            try {
                let jsonData;
                const data = event.target.result;
                if (file.name.endsWith('.csv')) {
                    let decodedData;
                    try {
                        decodedData = new TextDecoder('utf-8', { fatal: true }).decode(new Uint8Array(data));
                    } catch (e) {
                        decodedData = new TextDecoder('iso-8859-1').decode(new Uint8Array(data));
                    }

                    const lines = decodedData.split(/\r?\n/).filter(line => line.trim() !== '');
                    if (lines.length < 1) {
                        resolve([]);
                        return;
                    };

                    const firstLine = lines[0];
                    const delimiter = firstLine.includes(';') ? ';' : ',';
                    const headers = lines.shift().trim().split(delimiter).map(h => h.replace(/"/g, '').trim().replace(/^\uFEFF/, ''));

                    jsonData = lines.map(line => {
                        const values = line.split(delimiter).map(v => v.replace(/"/g, ''));
                        let row = {};
                        headers.forEach((header, index) => {
                            row[header] = values[index] || null;
                        });
                        return row;
                    });
                } else {
                    const workbook = XLSX.read(new Uint8Array(data), {type: 'array'});
                    const firstSheetName = workbook.SheetNames[0];
                    const worksheet = workbook.Sheets[firstSheetName];
                    jsonData = XLSX.utils.sheet_to_json(worksheet, { raw: false, cellDates: true });
                }
                resolve(jsonData);
            } catch (error) {
                reject(error);
            }
        };
        reader.onerror = () => reject(new Error(`Erro ao ler o arquivo '${file.name}'.`));
        reader.readAsArrayBuffer(file);
    });
};

const processSalesData = (rawData, clientMap, productMasterMap) => {
    return rawData.map(rawRow => {
        const clientInfo = clientMap.get(String(rawRow['CODCLI']).trim()) || {};
        let vendorName = String(rawRow['NOME'] || '');
        let supervisorName = String(rawRow['SUPERV'] || '');
        let codUsur = String(rawRow['CODUSUR'] || '');
        const pedido = String(rawRow['PEDIDO'] || '');
        if (supervisorName.trim().toUpperCase() === 'OSÉAS SANTOS OL') supervisorName = 'OSVALDO NUNES O';

        const supervisorUpper = (supervisorName || '').trim().toUpperCase();
        if (supervisorUpper === 'BALCAO' || supervisorUpper === 'BALCÃO') supervisorName = 'BALCAO';

        let dtPed = rawRow['DTPED'];
        const dtSaida = rawRow['DTSAIDA'];
        let parsedDtPed = parseDate(dtPed);
        const parsedDtSaida = parseDate(dtSaida);
        if (parsedDtPed && parsedDtSaida && (parsedDtPed.getFullYear() < parsedDtSaida.getFullYear() || (parsedDtPed.getFullYear() === parsedDtSaida.getFullYear() && parsedDtPed.getMonth() < parsedDtSaida.getMonth()))) {
            dtPed = dtSaida;
            parsedDtPed = parsedDtSaida;
        }
        const productCode = String(rawRow['PRODUTO'] || '').trim();
        const qtdeMaster = productMasterMap.get(productCode) || 1;
        const qtVenda = parseInt(String(rawRow['QTVENDA'] || '0').trim(), 10);

        let filialValue = String(rawRow['FILIAL'] || '').trim();
        if (filialValue === '5') filialValue = '05';
        if (filialValue === '8') filialValue = '08';

        return {
            pedido: pedido,
            nome: vendorName,
            superv: supervisorName,
            produto: productCode,
            descricao: String(rawRow['DESCRICAO'] || ''),
            fornecedor: String(rawRow['FORNECEDOR'] || ''),
            observacaofor: String(rawRow['OBSERVACAOFOR'] || '').trim(),
            codfor: String(rawRow['CODFOR'] || '').trim(),
            codusur: codUsur,
            codcli: String(rawRow['CODCLI'] || '').trim(),
            cliente_nome: clientInfo.nomeCliente || String(rawRow['CLIENTE'] || rawRow['NOMECLIENTE'] || rawRow['RAZAOSOCIAL'] || 'N/A').toUpperCase(),
            cidade: clientInfo.cidade || String(rawRow['MUNICIPIO'] || 'N/A').toUpperCase(),
            bairro: clientInfo.bairro || String(rawRow['BAIRRO'] || 'N/A').toUpperCase(),
            qtvenda: qtVenda,
            vlvenda: parseBrazilianNumber(rawRow['VLVENDA']),
            vlbonific: parseBrazilianNumber(rawRow['VLBONIFIC']),
            vldevolucao: parseBrazilianNumber(rawRow['VLDEVOLUCAO']),
            totpesoliq: parseBrazilianNumber(rawRow['TOTPESOLIQ']),
            dtped: parsedDtPed ? parsedDtPed.toISOString() : null,
            dtsaida: parsedDtSaida ? parsedDtSaida.toISOString() : null,
            posicao: String(rawRow['POSICAO'] || ''),
            filial: filialValue,
            codsupervisor: String(rawRow['CODSUPERVISOR'] || '').trim(),
            estoqueunit: parseBrazilianNumber(rawRow['ESTOQUEUNIT']),
            qtvenda_embalagem_master: isNaN(qtdeMaster) || qtdeMaster === 0 ? 0 : qtVenda / qtdeMaster,
            tipovenda: String(rawRow['TIPOVENDA'] || '').trim()
        };
    });
};

self.onmessage = async (event) => {
    // Removed credential requirements since worker no longer interacts with Supabase
    const { salesPrevYearFile, salesCurrYearFile, salesCurrMonthFile, clientsFile, productsFile, cityBranchMap } = event.data;

    try {
        self.postMessage({ type: 'progress', status: 'Lendo arquivos...', percentage: 5 });
        let [salesPrevYearDataRaw, salesCurrYearHistDataRaw, salesCurrMonthDataRaw, clientsDataRaw, productsDataRaw] = await Promise.all([
            readFile(salesPrevYearFile),
            readFile(salesCurrYearFile),
            readFile(salesCurrMonthFile),
            readFile(clientsFile),
            readFile(productsFile)
        ]);

        self.postMessage({ type: 'progress', status: 'Filtrando vendas Pepsico e linhas inválidas...', percentage: 15 });
        const pepsicoFilter = (sale) => String(sale['OBSERVACAOFOR'] || '').trim().toUpperCase() === 'PEPSICO';
        // Filter out rows where MUNICIPIO is empty/null (Stock pages/Invalid rows)
        const validRowFilter = (sale) => {
            const municipio = sale['MUNICIPIO'];
            return municipio && String(municipio).trim() !== '';
        };

        const combinedFilter = (sale) => pepsicoFilter(sale) && validRowFilter(sale);

        salesPrevYearDataRaw = salesPrevYearDataRaw.filter(combinedFilter);
        salesCurrYearHistDataRaw = salesCurrYearHistDataRaw.filter(combinedFilter);
        salesCurrMonthDataRaw = salesCurrMonthDataRaw.filter(combinedFilter);

        // --- IBGE Code Resolution ---
        self.postMessage({ type: 'progress', status: 'Verificando códigos IBGE...', percentage: 18 });
        
        // Collect all potential codes from sales only (Clients city ignored)
        const potentialCodes = new Set();
        
        const collectCodes = (row, field) => {
            const val = row[field];
            if (isIbgeCode(val)) potentialCodes.add(String(val).trim());
        };

        [...salesPrevYearDataRaw, ...salesCurrYearHistDataRaw, ...salesCurrMonthDataRaw].forEach(r => collectCodes(r, 'MUNICIPIO'));
        // Removed client code collection

        let ibgeMap = {};
        if (potentialCodes.size > 0) {
            self.postMessage({ type: 'progress', status: 'Buscando nomes de cidades (IBGE)...', percentage: 19 });
            try {
                ibgeMap = await fetchIbgeMapping();
            } catch (err) {
                console.error("Failed to fetch IBGE mapping:", err);
            }
        }

        const replaceIbgeCode = (row, field) => {
            const val = String(row[field] || '').trim();
            if (isIbgeCode(val) && ibgeMap[val]) {
                row[field] = ibgeMap[val];
            }
        };

        if (Object.keys(ibgeMap).length > 0) {
            salesPrevYearDataRaw.forEach(r => replaceIbgeCode(r, 'MUNICIPIO'));
            salesCurrYearHistDataRaw.forEach(r => replaceIbgeCode(r, 'MUNICIPIO'));
            salesCurrMonthDataRaw.forEach(r => replaceIbgeCode(r, 'MUNICIPIO'));
            // Removed client code replacement
        }

        // --- Create Sales City Map ---
        self.postMessage({ type: 'progress', status: 'Mapeando cidades pelas vendas...', percentage: 19.5 });
        const salesCityMap = new Map();

        // Iterate all sales to build map: CODCLI -> MUNICIPIO
        // Use sequential order: PrevYear -> CurrHist -> CurrMonth so latest wins if diff
        [...salesPrevYearDataRaw, ...salesCurrYearHistDataRaw, ...salesCurrMonthDataRaw].forEach(row => {
            const codCli = String(row['CODCLI'] || '').trim();
            const municipio = String(row['MUNICIPIO'] || '').trim().toUpperCase();
            if (codCli && municipio) {
                salesCityMap.set(codCli, municipio);
            }
        });

        // Process Clients
        self.postMessage({ type: 'progress', status: 'Processando clientes...', percentage: 20 });
        const clientMap = new Map();
        const clientsToInsert = [];

        clientsDataRaw.forEach(client => {
            const codCli = String(client['Código'] || '').trim();
            if (!codCli) return;

            const rca1 = String(client['RCA 1'] || '');
            // RCA 2 Removed
            const ultimaCompraRaw = client['Data da Última Compra'];
            const ultimaCompra = parseDate(ultimaCompraRaw);

            // Use city from sales map
            const salesCity = salesCityMap.get(codCli);
            const finalCity = salesCity || 'N/A';

            const clientData = {
                codigo_cliente: codCli,
                rca1: rca1,
                // rca2: rca2, -- Removed
                cidade: finalCity, // Was: String(client['Nome da Cidade'] || 'N/A'),
                nomecliente: String(client['Fantasia'] || client['Cliente'] || 'N/A'),
                bairro: String(client['Bairro'] || 'N/A'),
                razaosocial: String(client['Cliente'] || 'N/A'),
                fantasia: String(client['Fantasia'] || 'N/A'),
                ramo: String(client['Descricao'] || 'N/A'),
                ultimacompra: ultimaCompra ? ultimaCompra.toISOString() : null,
                bloqueio: String(client['Bloqueio'] || '').trim().toUpperCase(),
            };

            clientMap.set(codCli, {
                nomeCliente: clientData.nomecliente,
                cidade: clientData.cidade,
                bairro: clientData.bairro,
                rca1: rca1,
                razaosocial: clientData.razaosocial
            });
            clientsToInsert.push(clientData);
        });

        self.postMessage({ type: 'progress', status: 'Mapeando produtos...', percentage: 30 });
        const productMasterMap = new Map();
        productsDataRaw.forEach(prod => {
            const productCode = String(prod['Código'] || '').trim();
            if (!productCode) return;
            let qtdeMaster = parseInt(prod['Qtde embalagem master(Compra)'], 10);
            if (isNaN(qtdeMaster) || qtdeMaster <= 0) qtdeMaster = 1;
            productMasterMap.set(productCode, qtdeMaster);
        });

        // --- Logic for Inactive Clients (City -> Filial -> Supervisor) ---
        // 1. Identify New Cities and Use Provided Branch Map
        const newCitiesSet = new Set();
        const existingCityMap = cityBranchMap || {}; // Format: { "CITY NAME": "FILIAL" }

        // Helper to check and collect new cities
        const checkCity = (row) => {
            const cidade = String(row['MUNICIPIO'] || '').trim().toUpperCase();
            if (cidade && !existingCityMap.hasOwnProperty(cidade)) {
                newCitiesSet.add(cidade);
            }
        };

        [...salesPrevYearDataRaw, ...salesCurrYearHistDataRaw, ...salesCurrMonthDataRaw].forEach(checkCity);

        // 2. Identify Predominant Supervisor for City (using Curr Month only) for Inactive Logic
        const citySupervisorCounts = new Map(); // City -> Map(Supervisor -> Count)

        salesCurrMonthDataRaw.forEach(row => {
             // Only consider sales from Active Clients (present in clientMap)
             const codCli = String(row['CODCLI'] || '').trim();
             if (!clientMap.has(codCli)) return;

             const cidade = String(row['MUNICIPIO'] || '').trim().toUpperCase();
             let supervisor = String(row['SUPERV'] || '').trim();

             if (!cidade || !supervisor) return;
             if (supervisor.toUpperCase() === 'INATIVOS') return;

             if (supervisor.trim().toUpperCase() === 'OSÉAS SANTOS OL') supervisor = 'OSVALDO NUNES O';
             const supervisorUpper = supervisor.toUpperCase();
             if (supervisorUpper === 'BALCAO' || supervisorUpper === 'BALCÃO') return;

             if (!citySupervisorCounts.has(cidade)) {
                 citySupervisorCounts.set(cidade, new Map());
             }
             const counts = citySupervisorCounts.get(cidade);
             counts.set(supervisor, (counts.get(supervisor) || 0) + 1);
        });

        const cityPredominantSupervisorMap = new Map();
        citySupervisorCounts.forEach((counts, cidade) => {
            let maxCount = 0;
            let winner = 'N/A';
            counts.forEach((count, superv) => {
                if (count > maxCount) {
                    maxCount = count;
                    winner = superv;
                }
            });
            cityPredominantSupervisorMap.set(cidade, winner);
        });


        // Combine Sales for Map Logic
        const allSalesRaw = [...salesPrevYearDataRaw, ...salesCurrYearHistDataRaw, ...salesCurrMonthDataRaw];

        self.postMessage({ type: 'progress', status: 'Criando mapa mestre de vendedores...', percentage: 40 });
        const rcaInfoMap = new Map();
        // Sort all sales by date for RCA owner determination
        allSalesRaw.sort((a, b) => {
            const dateA = parseDate(a.DTPED) || new Date(0);
            const dateB = parseDate(b.DTPED) || new Date(0);
            return dateA - dateB;
        });

        for (const row of allSalesRaw) {
            const codusur = String(row['CODUSUR'] || '').trim();
            if (!codusur) continue;
            let supervisor = String(row['SUPERV'] || '').trim();
            const nome = String(row['NOME'] || '').trim();
            if (supervisor.trim().toUpperCase() === 'OSÉAS SANTOS OL') supervisor = 'OSVALDO NUNES O';
            const supervisorUpper = (supervisor || '').trim().toUpperCase();
            if (supervisorUpper === 'BALCAO' || supervisorUpper === 'BALCÃO') supervisor = 'BALCAO';
            const existingEntry = rcaInfoMap.get(codusur);
            if (!existingEntry) {
                rcaInfoMap.set(codusur, { NOME: nome || 'N/A', SUPERV: supervisor || 'N/A' });
            } else {
                if (nome) existingEntry.NOME = nome;
                if (supervisor) existingEntry.SUPERV = supervisor;
            }
        }

        self.postMessage({ type: 'progress', status: 'Processando e Reatribuindo vendas...', percentage: 50 });

        const reattributeSales = (salesData, isCurrMonth = false) => {
            return salesData.map(sale => {
                const originalCodCli = String(sale['CODCLI'] || '').trim();
                const newSale = { ...sale };

                // 1. Strict Branch Force Logic (No exceptions)
                const municipio = String(newSale['MUNICIPIO'] || '').trim().toUpperCase();
                const configuredFilial = existingCityMap[municipio];
                if (configuredFilial) {
                    newSale['FILIAL'] = configuredFilial;
                }
                const finalFilial = String(newSale['FILIAL'] || '00').trim();

                // 2. Identify Client Status (Active vs Inactive)
                const clientData = clientMap.get(originalCodCli);
                const rca1 = clientData ? String(clientData.rca1 || '').trim() : null;
                const isRca53 = rca1 === '53';
                const isInactive = !clientData || isRca53;

                if (isInactive) {
                    // 3. Inactive Logic: Supervisor by City Predominance
                    // User Rule: "clientes que são identificado como INATIVOS... Será identificado o supervisor de cada cidade, Por predominância"
                    // Vendor Name: "INATIVOS (numero da filial que foi identificada...)"

                    const predominantSupervisor = cityPredominantSupervisorMap.get(municipio) || 'INATIVOS';

                    newSale['SUPERV'] = predominantSupervisor;
                    newSale['CODUSUR'] = `INATIVOS_${finalFilial}`;
                    newSale['NOME'] = `INATIVOS ${finalFilial}`;

                } else {
                    // 4. Active Logic: Supervisor by Vendor's Latest Status
                    // User Rule: "todos os clientes que não são identificados como INATIVOS... identificar o supervisor desse vendedor será o qual ele vendeu por ultimo"

                    // Use Client's RCA1 as the source of truth for "Who is the vendor?"
                    // Fallback to original sale CODUSUR if RCA1 is missing (though active clients should have RCA1)
                    const targetVendorCode = rca1 || String(newSale['CODUSUR'] || '').trim();

                    if (targetVendorCode && rcaInfoMap.has(targetVendorCode)) {
                        const vendorInfo = rcaInfoMap.get(targetVendorCode);
                        newSale['CODUSUR'] = targetVendorCode;
                        newSale['NOME'] = vendorInfo.NOME;
                        newSale['SUPERV'] = vendorInfo.SUPERV;
                    } else {
                        // Fallback if vendor unknown in map (rare)
                        // Keep original if valid, otherwise mark N/A?
                        // Keeping original or "Inativo" fallback might be safer, but instructions imply Strict Active/Inactive split.
                        // If we can't find the vendor, we can't apply the "latest supervisor" rule.
                        // Let's assume standard behavior: keep what we have or flag it.
                        // Previous logic defaulted to INATIVO.
                        // However, if the client IS active but RCA is unknown, it's an edge case.
                        // Let's try to preserve original info if RCA1 is missing but client exists.
                         if (!rca1) {
                             // Use original sale info if RCA1 is missing
                         } else {
                             newSale['CODUSUR'] = rca1;
                             newSale['NOME'] = 'Desconhecido'; // Or check original sale name?
                             newSale['SUPERV'] = 'Desconhecido';
                         }
                    }

                    // Handle "Americanas" Name/ID consistency if needed, OR just treat as normal Active Client.
                    // If Americanas has a client card, it is Active.
                    // If its RCA1 maps to "AMERICANAS" in rcaInfoMap, it gets that.
                    // If the user wants specific names for Americanas, they should ensure the RCA maps to it.
                    // Given the strict instruction "no exceptions", we rely on the generic Active logic.
                    // But if Americanas was previously hardcoded because it lacked a consistent RCA, this might break.
                    // However, we must follow "não deve ter exceções".
                }

                return newSale;
            });
        };

        const reattributedPrevYear = reattributeSales(salesPrevYearDataRaw, false);
        const reattributedCurrYearHist = reattributeSales(salesCurrYearHistDataRaw, false);
        const reattributedCurrMonth = reattributeSales(salesCurrMonthDataRaw, true);

        const processedPrevYear = processSalesData(reattributedPrevYear, clientMap, productMasterMap);
        const processedCurrYearHist = processSalesData(reattributedCurrYearHist, clientMap, productMasterMap);
        const processedCurrMonth = processSalesData(reattributedCurrMonth, clientMap, productMasterMap);

        // --- Final Processing (Bonification Only) ---
        // Note: Branch Override and Tiago Rule removed as City Map now dictates branch assignment.

        const finalizeSalesData = (salesArray, isHistory = false) => {
             return salesArray.map(sale => {
                let newSale = { ...sale };

                // 1. Bonification Logic
                const tipo = newSale.tipovenda;
                if ((tipo === '5' || tipo === '11') && newSale.vlvenda > 0) {
                    newSale.vlbonific = (newSale.vlbonific || 0) + newSale.vlvenda;
                    newSale.vlvenda = 0;
                }

                // 2. Data Optimization (Strip unused fields for History)
                // This reduces JSON payload size and potentially DB size if columns are nullable/dropped
                if (isHistory) {
                    delete newSale.pedido;
                    delete newSale.descricao;
                    delete newSale.observacaofor;
                    delete newSale.estoqueunit;
                    delete newSale.posicao;
                    delete newSale.qtvenda_embalagem_master;
                    // Deep optimization: Remove fields available in data_clients or unused
                    delete newSale.cidade;
                    delete newSale.bairro;
                    delete newSale.cliente_nome;
                    delete newSale.produto;
                }

                return newSale;
             });
        };

        const finalPrevYear = finalizeSalesData(processedPrevYear, true);
        const finalCurrYearHist = finalizeSalesData(processedCurrYearHist, true);
        const finalCurrMonth = finalizeSalesData(processedCurrMonth, false);

        self.postMessage({ type: 'progress', status: 'Preparando dados para envio...', percentage: 90 });

        // Collect all data to return
        const resultPayload = {
            history: [...finalPrevYear, ...finalCurrYearHist],
            detailed: finalCurrMonth,
            clients: clientsToInsert,
            newCities: Array.from(newCitiesSet)
        };

        self.postMessage({ type: 'result', data: resultPayload });

    } catch (error) {
        self.postMessage({ type: 'error', message: error.message + (error.stack ? `\nStack: ${error.stack}`: '') });
    }
};
