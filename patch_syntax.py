import re

for filename in ['sql/full_system_v1.sql', 'sql/migration_boxes.sql']:
    with open(filename, 'r') as f:
        content = f.read()

    # We missed the trailing comma before `chart_agg_base AS (` when removing the salty_monthly block.
    # Actually wait.
    # The error says `syntax error at or near "WHERE"`.
    # Let's inspect the formats.
