const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

// Only replace in the appended portion
const splitPoint = content.lastIndexOf('-- Create metas_sv table');
if (splitPoint !== -1) {
    let base = content.substring(0, splitPoint);
    let appended = content.substring(splitPoint);

    appended = appended.replace(/vendedor_nome/g, 'codusur');
    appended = appended.replace(/vendedor/g, 'codusur');

    fs.writeFileSync('sql/full_system_v1.sql', base + appended);
    console.log('Fixed');
}
