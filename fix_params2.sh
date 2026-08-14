sed -i 's/p_codusur text\[\] default null/p_vendedor text\[\] default null/g' sql/full_system_v1.sql
sed -i 's/p_codusur text\[\] DEFAULT NULL/p_vendedor text\[\] DEFAULT NULL/g' sql/full_system_v1.sql
sed -i 's/AND array_length(p_codusur, 1)/AND array_length(p_vendedor, 1)/g' sql/full_system_v1.sql
sed -i 's/p_codusur IS NOT NULL/p_vendedor IS NOT NULL/g' sql/full_system_v1.sql
