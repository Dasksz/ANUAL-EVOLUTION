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

console.log(getMonthWeeksDistribution(2023, 10).length); // Nov 2023 -> 5 weeks
console.log(getMonthWeeksDistribution(2023, 1).length); // Feb 2023 -> 5 weeks
console.log(getMonthWeeksDistribution(2023, 9).length); // Oct 2023 -> 5 weeks
console.log(getMonthWeeksDistribution(2024, 8).length); // Sep 2024 -> 5 weeks or 6 weeks depending on day.
