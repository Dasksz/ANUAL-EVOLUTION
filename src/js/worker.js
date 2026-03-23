if (typeof self !== 'undefined' && typeof self.importScripts === 'function') {
    self.importScripts('https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js');
}


function parseExcelDate(serial) {
    let days = serial;
    if (days > 60) days -= 1;
    return new Date(Math.round((days - 25568) * 86400 * 1000));
}

function parseDate(dateString) {
    if (!dateString) return null;
    if (dateString instanceof Date) return !isNaN(dateString.getTime()) ? dateString : null;

    // Excel Serial Date (1900 format)
    if (typeof dateString === 'number') {
        return parseExcelDate(dateString);
    }

    if (typeof dateString !== 'string') return null;

    // Check DD/MM/YYYY or DD-MM-YYYY
    const str = dateString.trim().substring(0, 10); // Extract date part only, ignore time if any
    const parts = str.split(/[\/\-]/);

    if (parts.length === 3) {
        let day, month, year;

        // Assume DD/MM/YYYY if the first part is clearly a day (or standard BR format)
        // If year is first (YYYY-MM-DD), the first part will have length 4
        if (parts[0].length === 4) {
            year = parts[0];
            month = parts[1];
            day = parts[2];
        } else {
            day = parts[0];
            month = parts[1];
            year = parts[2];
            // Fix 2-digit years if they ever appear (e.g., 26 -> 2026)
            if (year.length === 2) year = '20' + year;
        }

        // Validate parts
        if (day && month && year && !isNaN(day) && !isNaN(month) && !isNaN(year)) {
            // Using Date.UTC to prevent timezone shift issues
            const d = new Date(Date.UTC(parseInt(year, 10), parseInt(month, 10) - 1, parseInt(day, 10)));
            return isNaN(d.getTime()) ? null : d;
        }
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

// Hashing Helper
async function generateHash(row) {
    // Sort keys to ensure deterministic order
    const keys = Object.keys(row).sort();
    const values = keys.map(k => {
        const val = row[k];
        if (val === null || val === undefined) return '';
        if (val instanceof Date) return val.toISOString(); // Ensure Date determinism
        return String(val);
    });
    const stringData = values.join('|'); // Delimiter to avoid boundary collisions
    const encoder = new TextEncoder();
    const data = encoder.encode(stringData);
    const hashBuffer = await self.crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
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
        const pedido = String(rawRow['NUMPED'] || rawRow['PEDIDO'] || '');
        if (supervisorName.trim().toUpperCase() === 'OSÉAS SANTOS OL') supervisorName = 'OSVALDO NUNES O';

        const supervisorUpper = (supervisorName || '').trim().toUpperCase();
        if (supervisorUpper === 'BALCAO' || supervisorUpper === 'BALCÃO') supervisorName = 'BALCAO';

        let dtPed = rawRow['DTPED'];
        const dtSaida = rawRow['DTSAIDA'];
        let parsedDtPed = parseDate(dtPed);
        const parsedDtSaida = parseDate(dtSaida);

        // Correctly handle UTC methods since parseDate returns UTC-aligned Date objects now
        if (parsedDtPed && parsedDtSaida && (parsedDtPed.getUTCFullYear() < parsedDtSaida.getUTCFullYear() || (parsedDtPed.getUTCFullYear() === parsedDtSaida.getUTCFullYear() && parsedDtPed.getUTCMonth() < parsedDtSaida.getUTCMonth()))) {
            dtPed = dtSaida;
            parsedDtPed = parsedDtSaida;
        }

        // Ensure final output string is YYYY-MM-DD
        const formattedDtPed = parsedDtPed ? parsedDtPed.toISOString().split('T')[0] : null;
        const formattedDtSaida = parsedDtSaida ? parsedDtSaida.toISOString().split('T')[0] : null;

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
            cidade: clientInfo.cidade || (rawRow['MUNICIPIO'] ? String(rawRow['MUNICIPIO']).trim().toUpperCase() : null),
            bairro: clientInfo.bairro || String(rawRow['BAIRRO'] || 'N/A').toUpperCase(),
            qtvenda: qtVenda,
            vlvenda: parseBrazilianNumber(rawRow['VLVENDA']),
            vlbonific: parseBrazilianNumber(rawRow['VLBONIFIC']),
            vldevolucao: parseBrazilianNumber(rawRow['VLDEVOLUCAO']),
            totpesoliq: parseBrazilianNumber(rawRow['TOTPESOLIQ']),
            dtped: formattedDtPed,
            dtsaida: formattedDtSaida,
            // posicao: String(rawRow["POSICAO"] || ""), // REMOVED
            filial: filialValue,
            codsupervisor: String(rawRow['CODSUPERVISOR'] || '').trim(),
            tipovenda: String(rawRow['TIPOVENDA'] || '').trim()
        };
    });
};

        function processLojaPerfeita(filesData, clientCnpjMap) {
            const combined = filesData.flat();
            const grouped = new Map(); // Key: CodCli_Pesquisador
            const uniqueClientsFound = new Set();

            // Month names in Portuguese
            const monthsPT = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

            // Helper to format date to "Month of Year"
            const formatMonthYear = (val) => {
                if (!val) return '';
                let dateObj = null;

                // Check if Excel Serial Date
                if (typeof val === 'number') {
                    if (val < 1000000) {
                        dateObj = parseExcelDate(val);
                    } else {
                        dateObj = new Date(val);
                    }
                } else {
                    const parsed = Date.parse(val);
                    if (!isNaN(parsed)) dateObj = new Date(parsed);
                }

                if (dateObj && !isNaN(dateObj.getTime())) {
                    const m = dateObj.getUTCMonth();
                    const y = dateObj.getUTCFullYear();
                    return `${monthsPT[m]} de ${y}`;
                }

                return String(val).trim();
            };

            const getVal = (row, keyPart) => {
                if (!row) return undefined;
                if (row[keyPart] !== undefined) return row[keyPart];
                const keys = Object.keys(row);
                const keyUpper = keyPart.toUpperCase();
                let match = keys.find(k => k.trim().toUpperCase() === keyUpper);
                if (match) return row[match];

                match = keys.find(k => k.toUpperCase().includes(keyUpper));
                if (match) return row[match];

                return undefined;
            };

            combined.forEach(row => {
                const cnpjRaw = getVal(row, 'CNPJ') || getVal(row, 'CPF');
                if (!cnpjRaw) return;

                let cnpjStr = String(cnpjRaw);
                if (typeof cnpjRaw === 'number' && cnpjStr.includes('e')) {
                    try {
                       cnpjStr = cnpjRaw.toLocaleString('fullwide', { useGrouping: false });
                    } catch(e) {}
                }

                const cnpjClean = cnpjStr.replace(/[^0-9]/g, '');

                let codCli = clientCnpjMap.get(cnpjClean);
                let finalCnpj = cnpjClean;

                if (!codCli && cnpjClean.length <= 14) {
                    const padded14 = cnpjClean.padStart(14, '0');
                    const match14 = clientCnpjMap.get(padded14);
                    if (match14) {
                        codCli = match14;
                        finalCnpj = padded14;
                    }
                }

                if (!codCli && cnpjClean.length <= 11) {
                    const padded11 = cnpjClean.padStart(11, '0');
                    const match11 = clientCnpjMap.get(padded11);
                    if (match11) {
                        codCli = match11;
                        finalCnpj = padded11;
                    }
                }

                if (!codCli) return;

                uniqueClientsFound.add(codCli);

                const pesquisador = String(getVal(row, 'Pesquisador') || '').trim().toUpperCase();
                const key = `${codCli}_${pesquisador}`;

                const notaRaw = getVal(row, 'Nota Média') || getVal(row, 'Nota Media');
                const nota = typeof notaRaw === 'number' ? notaRaw : parseFloat(String(notaRaw || '0').replace(',', '.'));

                if (isNaN(nota)) return;

                const current = grouped.get(key);
                const mesAnoRaw = getVal(row, 'Mês') || getVal(row, 'Mes');
                const mesAno = formatMonthYear(mesAnoRaw);
                const semana = getVal(row, 'Semana');
                const canal = getVal(row, 'Canal');
                const subcanal = getVal(row, 'Subcanal');
                const audits = parseInt(getVal(row, 'Auditorias Distintas') || 0);
                const perfectAudits = parseInt(getVal(row, 'Auditorias Distintas Perfeitas') || 0);

                if (!current) {
                    grouped.set(key, {
                        codigo_cliente: codCli,
                        mes_ano: mesAno,
                        semana: semana,
                        pesquisador: pesquisador,
                        cnpj_origem: finalCnpj,
                        canal: canal,
                        subcanal: subcanal,
                        nota_media: nota,
                        auditorias: audits,
                        auditorias_perfeitas: perfectAudits
                    });
                } else {
                    if (nota > current.nota_media) {
                        current.nota_media = nota;
                        current.mes_ano = mesAno;
                        current.semana = semana;
                        current.canal = canal;
                        current.subcanal = subcanal;
                    }
                    current.auditorias += audits;
                    current.auditorias_perfeitas += perfectAudits;
                }
            });

            return { data: Array.from(grouped.values()), uniqueCount: uniqueClientsFound.size };
        }

if (typeof self !== 'undefined') {
self.onmessage = async (event) => {
    // Removed credential requirements since worker no longer interacts with Supabase
    const { salesPrevYearFile, salesCurrYearFile, salesCurrMonthFile, clientsFile, productsFile, innovationsFile, notaInvolvesFile1, notaInvolvesFile2, cityBranchMap } = event.data;

    try {
        self.postMessage({ type: 'progress', status: 'Lendo arquivos...', percentage: 5 });
        let [salesPrevYearDataRaw, salesCurrYearHistDataRaw, salesCurrMonthDataRaw, clientsDataRaw, productsDataRaw, innovationsDataRaw, nota1DataRaw, nota2DataRaw] = await Promise.all([
            readFile(salesPrevYearFile),
            readFile(salesCurrYearFile),
            readFile(salesCurrMonthFile),
            readFile(clientsFile),
            readFile(productsFile),
            readFile(innovationsFile),
            readFile(notaInvolvesFile1),
            readFile(notaInvolvesFile2)
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

        for (const client of clientsDataRaw) {
            const codCli = String(client['Código'] || '').trim();
            if (!codCli) continue;

            const rca1 = String(client['RCA 1'] || '');
            const rawCnpj = client['CNPJ/CPF'] || client['Cpf/Cnpj'] || '';
            const cleanedCnpj = rawCnpj ? String(rawCnpj).replace(/[^0-9]/g, '') : null;
            // RCA 2 Removed
            const ultimaCompraRaw = client['Data da Última Compra'];
            const ultimaCompra = parseDate(ultimaCompraRaw);

            // Use city from sales map
            const salesCity = salesCityMap.get(codCli);
            // finalCity removed

            const clientData = {
                codigo_cliente: codCli,
                rca1: rca1,
                cnpj: cleanedCnpj,
                // rca2: rca2, -- Removed
                cidade: salesCity || String(client['Nome da Cidade'] || client['Cidade'] || '').trim().toUpperCase() || null,
                nomecliente: String(client['Fantasia'] || client['Cliente'] || 'N/A'),
                bairro: String(client['Bairro'] || 'N/A'),
                razaosocial: String(client['Cliente'] || 'N/A'),
                fantasia: String(client['Fantasia'] || 'N/A'),
                ramo: (client['Descricao'] && String(client['Descricao']).trim().toUpperCase() !== 'N/A' && String(client['Descricao']).trim().toUpperCase() !== 'N/D') ? String(client['Descricao']).trim().toUpperCase() : null,
                ultimacompra: ultimaCompra ? ultimaCompra.toISOString() : null,
                bloqueio: String(client['Bloqueio'] || '').trim().toUpperCase(),
            };

            // Generate Hash for Client Row
            clientData.row_hash = await generateHash(clientData);

            clientMap.set(codCli, {
                nomeCliente: clientData.nomecliente,
                cidade: clientData.cidade,
                bairro: clientData.bairro,
                rca1: rca1,
                cnpj: cleanedCnpj,
                razaosocial: clientData.razaosocial
            });
            clientsToInsert.push(clientData);
        }

        self.postMessage({ type: 'progress', status: 'Mapeando produtos...', percentage: 30 });
        const productMasterMap = new Map();
        const dimProducts = new Map();
        const allowedSuppliers = new Set(['707', '708', '752', '1119']);

        const activeProductCodes = new Set();
        const collectProductCodes = (row) => {
            const productCode = String(row['PRODUTO'] || '').trim();
            if (productCode) activeProductCodes.add(productCode);
        };
        salesPrevYearDataRaw.forEach(collectProductCodes);
        salesCurrYearHistDataRaw.forEach(collectProductCodes);
        salesCurrMonthDataRaw.forEach(collectProductCodes);

        productsDataRaw.forEach(prod => {
            const productCode = String(prod['Código'] || '').trim();
            if (!productCode) return;

            if (!activeProductCodes.has(productCode)) return;

            const codFor = String(prod['Fornecedor'] || '').trim();

            // Filter: Only process allowed suppliers (Pepsico)
            if (!allowedSuppliers.has(codFor)) return;
            
            let qtdeMaster = parseInt(prod['Qtde embalagem master(Compra)'], 10);
            if (isNaN(qtdeMaster) || qtdeMaster <= 0) qtdeMaster = 1;
            productMasterMap.set(productCode, qtdeMaster);

            const desc = String(prod['Descrição'] || '').trim();
            dimProducts.set(productCode, { descricao: desc, codfor: codFor, qtde_embalagem_master: qtdeMaster });
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
        const supervisorCodeMap = new Map(); // CODSUPERVISOR -> SUPERV NAME
        const clientLastVendorMap = new Map(); // CODCLI -> CODUSUR
        const vendorCitiesMap = new Map(); // CODUSUR -> Set(MUNICIPIO)

        // Sort all sales by date for RCA owner determination
        allSalesRaw.sort((a, b) => {
            const dateA = parseDate(a.DTPED) || new Date(0);
            const dateB = parseDate(b.DTPED) || new Date(0);
            return dateA - dateB;
        });

        for (const row of allSalesRaw) {
            const codusur = String(row['CODUSUR'] || '').trim();
            const codcli = String(row['CODCLI'] || '').trim();
            const municipio = String(row['MUNICIPIO'] || '').trim().toUpperCase();

            if (!codusur) continue;
            let supervisor = String(row['SUPERV'] || '').trim();
            let codSupervisor = String(row['CODSUPERVISOR'] || '').trim();
            const nome = String(row['NOME'] || '').trim();

            if (supervisor.trim().toUpperCase() === 'OSÉAS SANTOS OL') supervisor = 'OSVALDO NUNES O';
            const supervisorUpper = (supervisor || '').trim().toUpperCase();
            if (supervisorUpper === 'BALCAO' || supervisorUpper === 'BALCÃO') supervisor = 'BALCAO';

            if (codSupervisor && supervisor) {
                supervisorCodeMap.set(codSupervisor, supervisor);
            }

            const existingEntry = rcaInfoMap.get(codusur);
            if (!existingEntry) {
                rcaInfoMap.set(codusur, { NOME: nome || 'N/A', SUPERV: supervisor || 'N/A', CODSUPERVISOR: codSupervisor || 'N/A' });
            } else {
                if (nome) existingEntry.NOME = nome;
                if (supervisor) existingEntry.SUPERV = supervisor;
                if (codSupervisor) existingEntry.CODSUPERVISOR = codSupervisor;
            }

            // Build Client Last Vendor Map (sales sorted by date, so last one overwrites)
            if (codcli && codusur) {
                clientLastVendorMap.set(codcli, codusur);
            }

            // Build Vendor Cities Map
            if (codusur && municipio) {
                if (!vendorCitiesMap.has(codusur)) {
                    vendorCitiesMap.set(codusur, new Set());
                }
                vendorCitiesMap.get(codusur).add(municipio);
            }
        }

        self.postMessage({ type: 'progress', status: 'Processando e Reatribuindo vendas...', percentage: 50 });

        const reattributeSales = (salesData, isCurrMonth = false) => {
            const balcaoSpecialClients = new Set(['6421', '7706', '9814', '11405', '9763', '6769', '11625']);
            return salesData.map(sale => {
                const originalCodCli = String(sale['CODCLI'] || '').trim();
                const originalCodUsur = String(sale['CODUSUR'] || '').trim();
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

                // Check for Special Cases
                
                // Case A: 9569/53 Exception
                const isBalcaoException = (originalCodCli === '9569' && originalCodUsur === '53');
                // Case B: Balcao List
                const isBalcaoList = balcaoSpecialClients.has(originalCodCli);
                
                // Case C: Americanas
                const rawName = String(newSale['CLIENTE'] || newSale['NOMECLIENTE'] || newSale['RAZAOSOCIAL'] || '').toUpperCase();
                const clientName = clientData ? clientData.nomeCliente.toUpperCase() : rawName;
                const clientRazao = clientData ? clientData.razaosocial.toUpperCase() : '';
                const isAmericanas = clientName.includes('AMERICANAS') || clientName.includes('AMERICANAS S.A') || clientRazao.includes('AMERICANAS') || clientRazao.includes('AMERICANAS S.A');

                if (isBalcaoException) {
                    newSale['CODUSUR'] = 'BALCAO_SP';
                    newSale['NOME'] = 'BALCAO';
                    newSale['SUPERV'] = 'BALCAO';
                    newSale['CODCLI'] = '7706';
                } else if (isBalcaoList) {
                    newSale['CODUSUR'] = 'BALCAO_SP';
                    newSale['NOME'] = 'BALCAO';
                    newSale['SUPERV'] = 'BALCAO';
            newSale['CODSUPERVISOR'] = '8';
                } else if (isAmericanas) {
                    newSale['CODUSUR'] = 'AMERICANAS';
                    newSale['NOME'] = 'AMERICANAS';
                    newSale['SUPERV'] = 'SV AMERICANAS';
                    newSale['CODSUPERVISOR'] = 'SV_AMERICANAS';
                    // Branch is already set by Strict Logic above
                } else if (isInactive) {
                    // 3. Inactive Logic:
                    // New Rule:
                    // 1. Identify last vendor for this client
                    // 2. Identify all cities that vendor served
                    // 3. Identify predominant supervisor currently across those cities (aggregate count)
                    // 4. Assign to that supervisor and "INATIVOS [SUPERVISOR]" vendor.
                    
                    let targetSupervisor = null;
                    const lastVendor = clientLastVendorMap.get(originalCodCli);

                    if (lastVendor) {
                        const vendorCities = vendorCitiesMap.get(lastVendor);
                        if (vendorCities && vendorCities.size > 0) {
                            const supervisorAggregatedCounts = new Map();

                            vendorCities.forEach(city => {
                                const cityCounts = citySupervisorCounts.get(city);
                                if (cityCounts) {
                                    cityCounts.forEach((count, superv) => {
                                        supervisorAggregatedCounts.set(superv, (supervisorAggregatedCounts.get(superv) || 0) + count);
                                    });
                                }
                            });

                            let maxCount = 0;
                            supervisorAggregatedCounts.forEach((count, superv) => {
                                if (count > maxCount) {
                                    maxCount = count;
                                    targetSupervisor = superv;
                                }
                            });
                        }
                    }

                    // Fallback if no last vendor or no active supervisor found (use current city predominance)
                    if (!targetSupervisor) {
                         targetSupervisor = cityPredominantSupervisorMap.get(municipio) || 'INATIVOS';
                    }
                    
                    const sanitizedSupervisor = targetSupervisor.replace(/[^A-Z0-9]/g, ''); // Simple sanitization for code

                    newSale['SUPERV'] = targetSupervisor;
                    newSale['CODUSUR'] = `INAT_${sanitizedSupervisor}`;
                    newSale['NOME'] = `INATIVOS ${targetSupervisor}`;

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
                        
                        // New Rule: Vendor 190 -> Supervisor 12
                        if (targetVendorCode === '190') {
                            newSale['CODSUPERVISOR'] = '12';
                            newSale['SUPERV'] = supervisorCodeMap.get('12') || 'SUPERVISOR 12';
                        } else {
                            newSale['SUPERV'] = vendorInfo.SUPERV;
                            if (vendorInfo.CODSUPERVISOR && vendorInfo.CODSUPERVISOR !== 'N/A') {
                                newSale['CODSUPERVISOR'] = vendorInfo.CODSUPERVISOR;
                            }
                        }
                    } else {
                        // Fallback if vendor unknown in map (rare)
                         if (!rca1) {
                             // Use original sale info if RCA1 is missing
                         } else {
                             newSale['CODUSUR'] = rca1;
                             newSale['NOME'] = 'Desconhecido';
                             newSale['SUPERV'] = 'Desconhecido';
                         }
                    }
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

        // --- Collect Stock from Current Month ---
        self.postMessage({ type: 'progress', status: 'Extraindo estoque...', percentage: 75 });
        const productStockMap = new Map(); // "codigo-filial" -> { codigo, filial, estoque }
        salesCurrMonthDataRaw.forEach(row => {
            const productCode = String(row['PRODUTO'] || '').trim();
            if (!productCode) return;

            let filialValue = String(row['FILIAL'] || '').trim();
            if (filialValue === '5') filialValue = '05';
            if (filialValue === '8') filialValue = '08';
            if (!filialValue) return;

            const stockStr = row['ESTOQUECX'];
            if (stockStr !== undefined && stockStr !== null && stockStr !== '') {
                let stockVal = parseBrazilianNumber(stockStr);
                stockVal = Math.round(stockVal * 1000) / 1000;
                
                const key = `${productCode}-${filialValue}`;
                if (!productStockMap.has(key)) {
                    productStockMap.set(key, {
                        codigo: productCode,
                        filial: filialValue,
                        estoque: stockVal
                    });
                }
            }
        });
        const finalProductStock = Array.from(productStockMap.values());

        // --- Collect Dimensions (Supervisors, Vendors, Providers) ---
        self.postMessage({ type: 'progress', status: 'Extraindo dimensões (Supervisores, Vendedores)...', percentage: 80 });
        
        const dimSupervisors = new Map();
        const dimVendors = new Map();
        const dimProviders = new Map();
        // dimProducts initialized earlier

        const collectDimensions = (salesArray) => {
            salesArray.forEach(sale => {
                if (sale.codsupervisor && sale.superv) dimSupervisors.set(sale.codsupervisor, sale.superv);
                if (sale.codusur && sale.nome) dimVendors.set(sale.codusur, sale.nome);
                if (sale.codfor && sale.fornecedor) dimProviders.set(sale.codfor, sale.fornecedor);
                if (sale.produto && !dimProducts.has(sale.produto)) {
                    // Strict Filter: Only add if supplier is allowed
                    if (allowedSuppliers.has(sale.codfor)) {
                        dimProducts.set(sale.produto, { descricao: sale.descricao, codfor: sale.codfor });
                    }
                }
            });
        };

        collectDimensions(processedPrevYear);
        collectDimensions(processedCurrYearHist);
        collectDimensions(processedCurrMonth);

        // --- Final Processing (Bonification Only, No Hashing for Sales - Using Chunking) ---
        
        // Chunk Helper
        const chunkData = async (salesArray, isHistory = false) => {
             const chunks = {}; // Key: 'YYYY-MM', Value: { rows: [], hash: '' }
             
             // Process rows
             for (const sale of salesArray) {
                let newSale = { ...sale };

                // 1. Bonification Logic
                const tipo = newSale.tipovenda;
                if ((tipo === '5' || tipo === '11') && newSale.vlvenda > 0) {
                    newSale.vlbonific = (newSale.vlbonific || 0) + newSale.vlvenda;
                    newSale.vlvenda = 0;
                }

                // 2. Data Optimization
                delete newSale.cliente_nome;
                delete newSale.bairro;
                delete newSale.descricao;
                delete newSale.observacaofor;
                
                // 3. Normalization (Remove Text Columns, keep Codes)
                delete newSale.superv;
                delete newSale.nome; // Vendedor Name
                delete newSale.fornecedor;

                // 2b. History-specific Optimization
                if (isHistory) {
                    // delete newSale.pedido; // PRESERVED FOR FREQUENCY TABLE
                    // delete newSale.posicao; // REMOVED
                }

                // Identify Chunk Key (YYYY-MM)
                let dateStr = newSale.dtped; // ISO String
                if (!dateStr && newSale.dtped instanceof Date) dateStr = newSale.dtped.toISOString();
                
                let chunkKey = 'INVALID';
                if (dateStr && dateStr.length >= 7) {
                    chunkKey = dateStr.substring(0, 7); // 'YYYY-MM'
                }

                if (!chunks[chunkKey]) chunks[chunkKey] = { rows: [] };
                chunks[chunkKey].rows.push(newSale);
             }

             // Hash Chunks
             const chunkKeys = Object.keys(chunks);
             for (const key of chunkKeys) {
                 // Sort rows to ensure deterministic hash (by order ID or composite key if possible, else rely on input order stability + sort)
                 // Sorting by 'pedido' + 'produto' + 'vlvenda' for determinism
                 chunks[key].rows.sort((a, b) => {
                     const ka = (a.pedido || '') + (a.produto || '') + (a.vlvenda || 0);
                     const kb = (b.pedido || '') + (b.produto || '') + (b.vlvenda || 0);
                     return ka.localeCompare(kb);
                 });

                 // Calculate Chunk Hash (SHA-256 of JSON string of sorted rows)
                 const jsonStr = JSON.stringify(chunks[key].rows);
                 const encoder = new TextEncoder();
                 const data = encoder.encode(jsonStr);
                 const hashBuffer = await self.crypto.subtle.digest('SHA-256', data);
                 const hashArray = Array.from(new Uint8Array(hashBuffer));
                 chunks[key].hash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
             }

             return chunks;
        };

        const historyChunks = await chunkData([...processedPrevYear, ...processedCurrYearHist], true);
        const detailedChunks = await chunkData(processedCurrMonth, false);

        self.postMessage({ type: 'progress', status: 'Preparando dados para envio...', percentage: 90 });

        // Helper to convert Map to Array of Objects
        const mapToObjArray = (map) => Array.from(map.entries()).map(([codigo, nome]) => ({ codigo, nome }));

        // If history files were omitted, do not send historyChunks to prevent sync/wiping behavior
        const finalHistoryChunks = (salesPrevYearFile || salesCurrYearFile) ? historyChunks : null;

        // Only return newProducts if productsFile was provided to avoid overwriting table with partial data from sales
        const finalProducts = productsFile ? Array.from(dimProducts.entries()).map(([codigo, val]) => ({ codigo, descricao: val.descricao, codfor: val.codfor, qtde_embalagem_master: val.qtde_embalagem_master })) : null;

        // Process Innovations
        let finalInnovations = null;
        if (innovationsDataRaw && innovationsDataRaw.length > 0) {
            finalInnovations = innovationsDataRaw.map(item => ({
                codigo: String(item['Codigo'] || item['codigo'] || '').trim(),
                inovacoes: String(item['Inovacoes'] || item['inovacoes'] || '').trim()
            })).filter(item => item.codigo);
        }

        // Process Nota Perfeita
        let finalNotaPerfeita = null;
        if ((nota1DataRaw && nota1DataRaw.length > 0) || (nota2DataRaw && nota2DataRaw.length > 0)) {
             // Create clientCNPJMap for Loja Perfeita helper
             const clientCnpjMap = new Map();
             for (const client of clientsDataRaw) {
                 const codCli = String(client['Código'] || '').trim();
                 const cnpjRaw = client['CNPJ/CPF'] || client['Cpf/Cnpj'];
                 if (codCli && cnpjRaw) {
                     let cnpjStr = String(cnpjRaw).replace(/[^0-9]/g, '');
                     if (cnpjStr) clientCnpjMap.set(cnpjStr, codCli);
                 }
             }
             const notaResult = processLojaPerfeita([nota1DataRaw, nota2DataRaw], clientCnpjMap);
             finalNotaPerfeita = notaResult.data;
        }

        // Collect all data to return
        const resultPayload = {
            historyChunks: finalHistoryChunks,
            detailedChunks: detailedChunks,
            clients: clientsToInsert,
            newCities: Array.from(newCitiesSet),
            newSupervisors: mapToObjArray(dimSupervisors),
            newVendors: mapToObjArray(dimVendors),
            newProviders: mapToObjArray(dimProviders),
            newProducts: finalProducts,
            productStock: finalProductStock,
            innovations: finalInnovations,
            notaPerfeita: finalNotaPerfeita
        };

        self.postMessage({ type: 'result', data: resultPayload });

    } catch (error) {
        self.postMessage({ type: 'error', message: error.message + (error.stack ? `\nStack: ${error.stack}`: '') });
    }
};
}

// Export functions for testing in Node.js environment
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        parseDate,
        parseExcelDate,
        parseBrazilianNumber,
        isIbgeCode,
        generateHash
    };
}
