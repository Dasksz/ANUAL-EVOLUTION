const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const targetStr = `
    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$;

-- OVERLOAD:`;

if (content.includes(targetStr)) {
    content = content.replace(targetStr, `
    EXECUTE v_sql INTO v_result;
    RETURN v_result;
END;
$$;

-- OVERLOAD:`);
    console.log("Patched final $$");
} else {
    console.log("target string not found for $$ patch");
}

fs.writeFileSync('sql/full_system_v1.sql', content);
