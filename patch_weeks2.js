function getMonthWeeksDistribution(year, month) {
    const startOfMonth = new Date(year, month, 1);
    const endOfMonth = new Date(year, month + 1, 0);

    const weeks = [];
    let currentStart = new Date(startOfMonth);

    while (currentStart <= endOfMonth) {
        const dayOfWeek = currentStart.getDay();
        const daysToSaturday = 6 - dayOfWeek;

        let currentEnd = new Date(currentStart);
        currentEnd.setDate(currentStart.getDate() + daysToSaturday);

        if (currentEnd > endOfMonth) currentEnd = new Date(endOfMonth);

        weeks.push({
            start: new Date(currentStart),
            end: new Date(currentEnd)
        });

        currentStart = new Date(currentEnd);
        currentStart.setDate(currentStart.getDate() + 1);
    }
    return weeks;
}

for (let y = 2023; y <= 2024; y++) {
  for (let m = 0; m < 12; m++) {
    console.log(`y=${y}, m=${m}, weeks=${getMonthWeeksDistribution(y, m).length}`);
  }
}
