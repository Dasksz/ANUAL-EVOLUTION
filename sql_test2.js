const fs = require('fs');

function extractBlocks(sqlFile) {
    const sql = fs.readFileSync(sqlFile, 'utf8');

    const start = sql.indexOf('CREATE OR REPLACE FUNCTION get_boxes_dashboard_data');
    if (start === -1) return;
    const end = sql.indexOf('END;', start);
    const fnBody = sql.substring(start, end);

    const matches = fnBody.match(/EXECUTE format\(\s*'([\s\S]*?)',\s*([\s\S]*?)\)\s*INTO/g);
    if (!matches) return;

    for (let m of matches) {
        // extract query string
        let qStart = m.indexOf("'");
        let qEnd = m.lastIndexOf("',");
        let q = m.substring(qStart, qEnd);
        let specifiers = q.match(/%[sLI]/g) || [];

        let argsStr = m.substring(qEnd + 2, m.lastIndexOf(")")).trim();
        let args = argsStr.split('\n').filter(l => l.trim().length > 0 && !l.trim().startsWith('--'));

        console.log(`Specifiers: ${specifiers.length}`);

        // Count comments like (1 %s, 4 %L)
        let paramCount = 0;
        let expectedFromComments = 0;
        let commentMatches = argsStr.match(/--.*?\((.*?)\)/g) || [];
        for (let cm of commentMatches) {
            console.log("  " + cm);
            let nums = cm.match(/\d+/g) || [];
            for (let n of nums) expectedFromComments += parseInt(n);
        }

        console.log("Expected from comments: " + expectedFromComments);
    }
}
extractBlocks('sql/full_system_v1.sql');
