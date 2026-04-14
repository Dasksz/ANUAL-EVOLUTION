if (typeof self !== 'undefined' && typeof self.importScripts === 'function') {
    self.importScripts('https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js');
}


function parseExcelDate(serial) {
    let days = serial;
    if (days > 60) days -= 1;
    return new Date(Math.round((days - 25568) * 86400 * 1000));
}

const isDigit = (code) => code >= 48 && code <= 57;

function createUTCDate(y, m, d) {
    let finalYear = y;
    // Fix 2-digit years if they ever appear (e.g., 26 -> 2026, 99 -> 1999, 0026 -> 2026)
    if (finalYear < 100) {
        finalYear += (finalYear < 50) ? 2000 : 1900;
    }
    // Using Date.UTC to prevent timezone shift issues
    const dt = new Date(Date.UTC(finalYear, m - 1, d));
    return isNaN(dt.getTime()) ? null : dt;
}

function parseDate(dateString) {
    if (!dateString) return null;
    if (dateString instanceof Date) return !isNaN(dateString.getTime()) ? dateString : null;

    // Excel Serial Date (1900 format)
    if (typeof dateString === 'number') {
        return parseExcelDate(dateString);
    }

    if (typeof dateString !== 'string') return null;

    // Get only the date part before any space/time
    const str = dateString.trim().split(' ')[0];
    if (str.length === 0) return null;

    // Fast path for YYYY-MM-DD or DD/MM/YYYY
    if (str.length >= 10) {
        const c4 = str.charCodeAt(4);
        const c2 = str.charCodeAt(2);

        // yyyy-mm-dd ('-' is 45)
        if (c4 === 45 && str.charCodeAt(7) === 45) {
            if (
                isDigit(str.charCodeAt(0)) && isDigit(str.charCodeAt(1)) &&
                isDigit(str.charCodeAt(2)) && isDigit(str.charCodeAt(3)) &&
                isDigit(str.charCodeAt(5)) && isDigit(str.charCodeAt(6)) &&
                isDigit(str.charCodeAt(8)) && isDigit(str.charCodeAt(9))
            ) {
                const y = (str.charCodeAt(0) - 48) * 1000 + (str.charCodeAt(1) - 48) * 100 + (str.charCodeAt(2) - 48) * 10 + (str.charCodeAt(3) - 48);
                const m = (str.charCodeAt(5) - 48) * 10 + (str.charCodeAt(6) - 48);
                const d = (str.charCodeAt(8) - 48) * 10 + (str.charCodeAt(9) - 48);
                return createUTCDate(y, m, d);
            }
        }
        // dd/mm/yyyy or dd-mm-yyyy ('/' is 47, '-' is 45)
        else if ((c2 === 47 || c2 === 45) && (str.charCodeAt(5) === 47 || str.charCodeAt(5) === 45)) {
            if (
                isDigit(str.charCodeAt(0)) && isDigit(str.charCodeAt(1)) &&
                isDigit(str.charCodeAt(3)) && isDigit(str.charCodeAt(4)) &&
                isDigit(str.charCodeAt(6)) && isDigit(str.charCodeAt(7)) &&
                isDigit(str.charCodeAt(8)) && isDigit(str.charCodeAt(9))
            ) {
                const d = (str.charCodeAt(0) - 48) * 10 + (str.charCodeAt(1) - 48);
                const m = (str.charCodeAt(3) - 48) * 10 + (str.charCodeAt(4) - 48);
                const y = (str.charCodeAt(6) - 48) * 1000 + (str.charCodeAt(7) - 48) * 100 + (str.charCodeAt(8) - 48) * 10 + (str.charCodeAt(9) - 48);
                return createUTCDate(y, m, d);
            }
        }
    }

    // Check DD/MM/YYYY or DD-MM-YYYY (fallback)
    const strPart = str.substring(0, 10); // Extract date part only, ignore time if any
    const parts = strPart.split(/[\/\-]/);

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
        }

        const y = parseInt(year, 10);
        const m = parseInt(month, 10);
        const d = parseInt(day, 10);

        // Validate parts
        if (!isNaN(y) && !isNaN(m) && !isNaN(d)) {
            return createUTCDate(y, m, d);
        }
    }

    const isoDate = new Date(dateString);
    return !isNaN(isoDate.getTime()) ? isoDate : null;
}

function parseBrazilianNumber(value) {
    if (typeof value === 'number') return value;
    if (typeof value !== 'string' || !value) return 0;

    let cleaned = value;
    if (cleaned.indexOf('R$') !== -1) {
        cleaned = cleaned.replace(/R\$\s?/g, '');
    }
    cleaned = cleaned.trim();

    const lastComma = cleaned.lastIndexOf(',');
    const lastDot = cleaned.lastIndexOf('.');

    // ⚡ Bolt Optimization: Fast path for pure numbers to avoid expensive regex operations
    if (lastComma === -1 && lastDot === -1) {
        const num = parseFloat(cleaned);
        return isNaN(num) ? 0 : num;
    }

    let numberString;
    if (lastComma > lastDot) {
        if (lastDot === -1) {
             numberString = cleaned.replace(',', '.');
        } else {
             numberString = cleaned.replace(/\./g, '').replace(',', '.');
        }
    } else if (lastDot > lastComma) {
        if (lastComma === -1) {
             numberString = cleaned;
        } else {
             numberString = cleaned.replace(/,/g, '');
        }
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
const _hexMap = [];
for (let i = 0; i < 256; i++) {
    _hexMap[i] = i.toString(16).padStart(2, '0');
}
const _hashEncoder = new TextEncoder();

async function generateHash(row) {
    // Sort keys to ensure deterministic order
    const keys = Object.keys(row).sort();
    let stringData = '';
    for (let i = 0; i < keys.length; i++) {
        const val = row[keys[i]];
        if (i > 0) stringData += '|';
        if (val !== null && val !== undefined) {
            if (val instanceof Date) {
                stringData += val.toISOString(); // Ensure Date determinism
            } else {
                stringData += val;
            }
        }
    }

    // Delimiter to avoid boundary collisions
    const data = _hashEncoder.encode(stringData);
    const hashBuffer = await self.crypto.subtle.digest('SHA-256', data);
    const hashArray = new Uint8Array(hashBuffer);

    let hex = '';
    for (let i = 0; i < hashArray.length; i++) {
        hex += _hexMap[hashArray[i]];
    }
    return hex;
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
            cidade: clientInfo.cidade || (rawRow['MUNICIPIO'] ? normalizeCityName(rawRow['MUNICIPIO']) : null),
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

        
        // ------------------------------------------------------------------
        // METAS ESTRELAS PROCESSING
        // ------------------------------------------------------------------
        function processMetasEstrelas(data, mes, ano) {
            const results = [];
            for (const row of data) {
                // Ignore lines that don't have FILIAL or have "Total" in it
                if (!row['FILIAL']) continue;
                const filialStr = String(row['FILIAL']).trim().toUpperCase();
                if (filialStr.includes('TOTAL')) continue;
                
                // Extract only numbers from FILIAL just in case it still says "FILIAL 5"
                const filialMatch = filialStr.match(/\d+/);
                const filial = filialMatch ? parseInt(filialMatch[0], 10) : null;
                
                const codRca = parseInt(row['Cod'], 10);
                
                if (!filial || isNaN(codRca)) continue;

                const calcPos = parseInt(row['Calibração Pos'] || row['Calibração Pos '], 10) || 0;
                
                // Parse float numbers replacing comma with dot
                const parseDecimal = (val) => {
                    if (!val) return 0;
                    if (typeof val === 'number') return val;
                    return parseFloat(String(val).replace(',', '.')) || 0;
                };

                const calcFoods = parseDecimal(row['Calibração Foods'] || row['Calibração Foods ']);
                const calcSalty = parseDecimal(row['Calibração Salty'] || row['Calibração Salty ']);

                results.push({
                    filial: filial,
                    cod_rca: codRca,
                    calibracao_salty: calcSalty,
                    calibracao_foods: calcFoods,
                    calibracao_pos: calcPos,
                    mes: parseInt(mes, 10),
                    ano: parseInt(ano, 10)
                });
            }
            return results;
        }

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

            const matchedKeysCache = new Map();
            const searchedKeyParts = new Set();
            const allKnownKeys = new Set();

            let lastProcessedRow = null;

            const getVal = (row, keyPart) => {
                if (!row) return undefined;
                // 1. Direct match (fastest path)
                if (row[keyPart] !== undefined) return row[keyPart];

                // 2. Cached actual keys match
                let matched = matchedKeysCache.get(keyPart);
                if (matched) {
                    for (let i = 0; i < matched.length; i++) {
                        if (row[matched[i]] !== undefined) return row[matched[i]];
                    }
                }

                // 3. Fast exit for known missing keys
                // Bolt Optimization: Only check for new keys once per row reference to avoid
                // redundant O(N) object key iterations for every missing property lookup.
                if (row !== lastProcessedRow) {
                    let hasNewKeys = false;
                    for (const k in row) {
                        if (!allKnownKeys.has(k)) {
                            allKnownKeys.add(k);
                            hasNewKeys = true;
                        }
                    }

                    if (hasNewKeys) {
                        searchedKeyParts.clear();
                    }
                    lastProcessedRow = row;
                }

                if (searchedKeyParts.has(keyPart)) {
                    return undefined;
                }

                // 4. Slow search for new match
                const keyUpper = keyPart.toUpperCase();
                let matchExact = null;
                let matchIncludes = null;

                for (const k in row) {
                    const kUpper = k.toUpperCase();
                    if (k.trim().toUpperCase() === keyUpper) {
                        matchExact = k;
                        break;
                    } else if (!matchIncludes && kUpper.includes(keyUpper)) {
                        matchIncludes = k;
                    }
                }

                let match = matchExact || matchIncludes;

                if (match) {
                    if (!matched) {
                        matched = [];
                        matchedKeysCache.set(keyPart, matched);
                    }
                    if (!matched.includes(match)) {
                        matched.push(match);
                    }
                    return row[match];
                }

                // Mark this keyPart as thoroughly searched with current known keys
                searchedKeyParts.add(keyPart);
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
    const { salesPrevYearFile, salesCurrYearFile, salesCurrMonthFile, clientsFile, productsFile, innovationsFile, notaInvolvesFile1, notaInvolvesFile2, cityBranchMap, metaEstrelasFile, metaEstrelasMes, metaEstrelasAno } = event.data;

    try {
        self.postMessage({ type: 'progress', status: 'Lendo arquivos...', percentage: 5 });
        let [salesPrevYearDataRaw, salesCurrYearHistDataRaw, salesCurrMonthDataRaw, clientsDataRaw, productsDataRaw, innovationsDataRaw, nota1DataRaw, nota2DataRaw, metaEstrelasDataRaw] = await Promise.all([
            readFile(salesPrevYearFile),
            readFile(salesCurrYearFile),
            readFile(salesCurrMonthFile),
            readFile(clientsFile),
            readFile(productsFile),
            readFile(innovationsFile),
            readFile(notaInvolvesFile1),
            readFile(notaInvolvesFile2),
            readFile(metaEstrelasFile)
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

        // ⚡ Bolt Optimization: Pre-compute the combined array once using optimized Array.prototype.concat
        // to avoid repeatedly copying 100k+ objects into new memory blocks via [...a, ...b, ...c] spreads down the line.
        const allSalesRaw = salesPrevYearDataRaw.concat(salesCurrYearHistDataRaw, salesCurrMonthDataRaw);

        // --- IBGE Code Resolution ---
        self.postMessage({ type: 'progress', status: 'Verificando códigos IBGE...', percentage: 18 });
        
        // Collect all potential codes from sales only (Clients city ignored)
        const potentialCodes = new Set();
        
        const collectCodes = (row, field) => {
            const val = row[field];
            if (isIbgeCode(val)) potentialCodes.add(String(val).trim());
        };

        allSalesRaw.forEach(r => collectCodes(r, 'MUNICIPIO'));
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
        allSalesRaw.forEach(row => {
            const codCli = String(row['CODCLI'] || '').trim();
            const municipio = normalizeCityName(row['MUNICIPIO']);
            if (codCli && municipio) {
                salesCityMap.set(codCli, municipio);
            }
        });

        // Process Clients
        self.postMessage({ type: 'progress', status: 'Processando clientes...', percentage: 20 });
        const clientMap = new Map();
        const clientsToInsert = [];

        // ⚡ Bolt Optimization: Parallelize client hashing to avoid sequential await bottleneck.
        const processedClients = await Promise.all(clientsDataRaw.map(async (client) => {
            const codCli = String(client['Código'] || '').trim();
            if (!codCli) return null;

            const rca1 = String(client['RCA 1'] || '');
            const rawCnpj = client['CNPJ/CPF'] || client['Cpf/Cnpj'] || '';
            const cleanedCnpj = rawCnpj ? String(rawCnpj).replace(/[^0-9]/g, '') : null;
            const ultimaCompraRaw = client['Data da Última Compra'];
            const ultimaCompra = parseDate(ultimaCompraRaw);

            const salesCity = salesCityMap.get(codCli);

            const clientData = {
                codigo_cliente: codCli,
                rca1: rca1,
                cnpj: cleanedCnpj,
                cidade: salesCity || String(client['Nome da Cidade'] || client['Cidade'] || '').trim().toUpperCase() || null,
                nomecliente: String(client['Fantasia'] || client['Cliente'] || 'N/A'),
                bairro: String(client['Bairro'] || 'N/A'),
                razaosocial: String(client['Cliente'] || 'N/A'),
                fantasia: String(client['Fantasia'] || 'N/A'),
                ramo: (client['Descricao'] && String(client['Descricao']).trim().toUpperCase() !== 'N/A' && String(client['Descricao']).trim().toUpperCase() !== 'N/D') ? String(client['Descricao']).trim().toUpperCase() : null,
                ultimacompra: ultimaCompra ? ultimaCompra.toISOString() : null,
                bloqueio: String(client['Bloqueio'] || '').trim().toUpperCase(),
            };

            clientData.row_hash = await generateHash(clientData);

            return {
                codCli,
                rca1,
                cleanedCnpj,
                clientData
            };
        }));

        for (const res of processedClients) {
            if (!res) continue;
            const { codCli, rca1, cleanedCnpj, clientData } = res;
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
            const cidade = normalizeCityName(row['MUNICIPIO']);
            if (cidade && !existingCityMap.hasOwnProperty(cidade)) {
                newCitiesSet.add(cidade);
            }
        };

        allSalesRaw.forEach(checkCity);

        // 2. Identify Predominant Supervisor for City (using Curr Month only) for Inactive Logic
        const citySupervisorCounts = new Map(); // City -> Map(Supervisor -> Count)

        salesCurrMonthDataRaw.forEach(row => {
             // Only consider sales from Active Clients (present in clientMap)
             const codCli = String(row['CODCLI'] || '').trim();
             if (!clientMap.has(codCli)) return;

             const cidade = normalizeCityName(row['MUNICIPIO']);
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


        // Combine Sales for Map Logic (Already computed as allSalesRaw using .concat earlier)
        self.postMessage({ type: 'progress', status: 'Criando mapa mestre de vendedores...', percentage: 40 });
        const rcaInfoMap = new Map();
        const supervisorCodeMap = new Map(); // CODSUPERVISOR -> SUPERV NAME
        const clientLastVendorMap = new Map(); // CODCLI -> CODUSUR
        const vendorCitiesMap = new Map(); // CODUSUR -> Set(MUNICIPIO)

        // Pre-compute timestamps to avoid calling parseDate repeatedly in sort comparator
        for (let i = 0; i < allSalesRaw.length; i++) {
            const parsed = parseDate(allSalesRaw[i].DTPED);
            allSalesRaw[i]._dtped_ts = parsed ? parsed.getTime() : 0;
        }

        // Sort all sales by date for RCA owner determination
        allSalesRaw.sort((a, b) => {
            return a._dtped_ts - b._dtped_ts;
        });

        for (const row of allSalesRaw) {
            const codusur = String(row['CODUSUR'] || '').trim();
            const codcli = String(row['CODCLI'] || '').trim();
            const municipio = normalizeCityName(row['MUNICIPIO']);

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
                const municipio = normalizeCityName(newSale['MUNICIPIO']);
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

             // ⚡ Bolt Optimization: Parallelize chunk hashing to avoid sequential await bottleneck.
             await Promise.all(chunkKeys.map(async (key) => {
                 // Sort rows to ensure deterministic hash (by order ID or composite key if possible, else rely on input order stability + sort)
                 // Sorting by 'pedido', then 'produto', then 'vlvenda' for determinism
                 // ⚡ Bolt Optimization: Avoid O(N log N) string concatenation by doing sequential property comparison
                 chunks[key].rows.sort((a, b) => {
                     const pa = a.pedido || '';
                     const pb = b.pedido || '';
                     if (pa !== pb) return pa < pb ? -1 : 1;

                     const pra = a.produto || '';
                     const prb = b.produto || '';
                     if (pra !== prb) return pra < prb ? -1 : 1;

                     const va = a.vlvenda || 0;
                     const vb = b.vlvenda || 0;
                     return va < vb ? -1 : (va > vb ? 1 : 0);
                 });

                 // Calculate Chunk Hash (SHA-256 of JSON string of sorted rows)
                 const jsonStr = JSON.stringify(chunks[key].rows);
                 const data = _hashEncoder.encode(jsonStr);
                 const hashBuffer = await self.crypto.subtle.digest('SHA-256', data);
                 const hashArray = new Uint8Array(hashBuffer);

                 let hex = '';
                 for (let i = 0; i < hashArray.length; i++) {
                     hex += _hexMap[hashArray[i]];
                 }
                 chunks[key].hash = hex;
             }));

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
        
        // Process Metas Estrelas
        let finalMetaEstrelas = null;
        if (metaEstrelasDataRaw && metaEstrelasDataRaw.length > 0) {
            self.postMessage({ type: 'progress', status: 'Processando Metas Estrelas...', percentage: 95 });
            finalMetaEstrelas = processMetasEstrelas(metaEstrelasDataRaw, metaEstrelasMes, metaEstrelasAno);
        }

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
            notaPerfeita: finalNotaPerfeita,
            metaEstrelas: finalMetaEstrelas
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
