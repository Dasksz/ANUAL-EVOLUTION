import re

with open('sql/full_system_v1.sql', 'r') as f:
    content = f.read()

content = content.replace('CREATE POLICY "Allow authenticated read access" ON public.dat_summary_frequency', 'DROP POLICY IF EXISTS "Allow authenticated read access" ON public.dat_summary_frequency;\nCREATE POLICY "Allow authenticated read access" ON public.dat_summary_frequency')
content = content.replace('CREATE POLICY "Allow admin write access" ON public.dat_summary_frequency', 'DROP POLICY IF EXISTS "Allow admin write access" ON public.dat_summary_frequency;\nCREATE POLICY "Allow admin write access" ON public.dat_summary_frequency')

with open('sql/full_system_v1.sql', 'w') as f:
    f.write(content)
print("Added DROP POLICY IF EXISTS")
