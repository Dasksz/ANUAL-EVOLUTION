const fs = require('fs');
let content = fs.readFileSync('sql/full_system_v1.sql', 'utf8');

const targetStr = `create or replace function public.handle_new_user () RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
set
  search_path = public as $$
DECLARE`;

if (content.includes(targetStr)) {
    content = content.replace(targetStr, `create or replace function public.handle_new_user () RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE`);
    console.log("Patched trigger handle_new_user");
} else {
    console.log("target string not found");
}

fs.writeFileSync('sql/full_system_v1.sql', content);
