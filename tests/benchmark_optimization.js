
const LATENCY_MS = 500; // Simulated latency per RPC call

async function simulatedRpcCall(name) {
    return new Promise(resolve => {
        setTimeout(() => {
            // console.log(`Finished ${name}`);
            resolve({ data: 'success', error: null });
        }, LATENCY_MS);
    });
}

async function runSequential(years, months) {
    const start = Date.now();
    for (const year of years) {
        for (const month of months) {
            // Simulated sequential chunks
            await simulatedRpcCall(`Chunk 1 - ${month}/${year}`);
            await simulatedRpcCall(`Chunk 2 - ${month}/${year}`);
            await simulatedRpcCall(`Chunk 3 - ${month}/${year}`);
            // Simulated filter refresh
            await simulatedRpcCall(`Filter - ${month}/${year}`);
        }
    }
    return Date.now() - start;
}

async function runParallel(years, months) {
    const start = Date.now();
    for (const year of years) {
        for (const month of months) {
            // Simulated parallel chunks
            await Promise.all([
                simulatedRpcCall(`Chunk 1 - ${month}/${year}`),
                simulatedRpcCall(`Chunk 2 - ${month}/${year}`),
                simulatedRpcCall(`Chunk 3 - ${month}/${year}`)
            ]);
            // Simulated filter refresh (must remain sequential after chunks)
            await simulatedRpcCall(`Filter - ${month}/${year}`);
        }
    }
    return Date.now() - start;
}

async function benchmark() {
    const years = [2024, 2025];
    const months = Array.from({ length: 12 }, (_, i) => i + 1);

    console.log(`--- Performance Benchmark (Simulation) ---`);
    console.log(`Processing ${years.length} years and 12 months each...`);
    console.log(`Simulated Latency: ${LATENCY_MS}ms per RPC call\n`);

    const seqTime = await runSequential(years, months);
    console.log(`Baseline (Sequential): ${seqTime}ms`);

    const parTime = await runParallel(years, months);
    console.log(`Optimized (Parallel Chunks): ${parTime}ms`);

    const improvement = seqTime - parTime;
    const percent = ((improvement / seqTime) * 100).toFixed(2);

    console.log(`\nImprovement: ${improvement}ms (${percent}%)`);
}

benchmark();
