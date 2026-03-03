BEGIN { in_func = 0; }
/^CREATE OR REPLACE FUNCTION get_innovations_data/,/^\$BODY\$;/ {
    if (!in_func) {
        system("cat /tmp/new_innov_func.sql");
        in_func = 1;
    }
    next;
}
{ print }
