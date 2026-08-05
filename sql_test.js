const fs = require('fs');

function testArgs(sqlFile) {
    const sql = fs.readFileSync(sqlFile, 'utf8');

    // Find the EXECUTE format blocks for get_boxes_dashboard_data
    // Specifically looking for the arguments passed to format
    const matches = sql.match(/EXECUTE format\(\s*'([\s\S]*?)',\s*([\s\S]*?)\)\s*INTO/g);

    if (!matches) {
        console.log("No EXECUTE format matches found.");
        return;
    }

    for (let i = 0; i < matches.length; i++) {
        let match = matches[i];
        let queryStr = match.substring(match.indexOf("'") + 1, match.lastIndexOf("',"));
        let argsStr = match.substring(match.lastIndexOf("',") + 2, match.lastIndexOf(")")).trim();

        let formatSpecifiers = (queryStr.match(/%s|%L|%I/g) || []).length;

        // Remove comments
        argsStr = argsStr.replace(/--.*$/gm, '');
        // Split by commas not inside parentheses
        // This is a naive split
        let argsCount = 0;
        let depth = 0;
        for (let j=0; j<argsStr.length; j++) {
            if (argsStr[j] === '(') depth++;
            else if (argsStr[j] === ')') depth--;
            else if (argsStr[j] === ',' && depth === 0) argsCount++;
        }
        if (argsStr.trim().length > 0) argsCount++; // last arg

        console.log(`Block ${i}: specifiers=${formatSpecifiers}, args=${argsCount}`);
        if (formatSpecifiers !== argsCount) {
             console.log("MISMATCH!");
        }
    }
}

testArgs('sql/full_system_v1.sql');
testArgs('sql/migration_boxes.sql');
