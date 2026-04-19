import re

with open("src/js/app.js", "r") as f:
    content = f.read()

# monthNames[month] and year might be fine, but better escape
content = content.replace('${monthNames[month]} ${year}', '${escapeHtml(monthNames[month])} ${escapeHtml(year)}')

# dateStr, day
content = content.replace('data-date="${dateStr}"', 'data-date="${escapeHtml(dateStr)}"')
content = content.replace('${day}</div>', '${escapeHtml(day)}</div>')

with open("src/js/app.js", "w") as f:
    f.write(content)
