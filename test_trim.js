const weeklyCurrent = [100, 200, 300, 400, 0, 0];
const weeklyHistory = [150, 250, 350, 450, 0, 0];
const dailyDataByWeek = [[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[1,1,1,1,1,1,1],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]];

let numWeeksToKeep = 6;
while (numWeeksToKeep > 4 && weeklyCurrent[numWeeksToKeep - 1] === 0 && weeklyHistory[numWeeksToKeep - 1] === 0) {
    numWeeksToKeep--;
}

const trimmedWeeklyCurrent = weeklyCurrent.slice(0, numWeeksToKeep);
const trimmedWeeklyHistory = weeklyHistory.slice(0, numWeeksToKeep);
const trimmedDailyDataByWeek = dailyDataByWeek.slice(0, numWeeksToKeep);
const trimmedDailyLabels = new Array(numWeeksToKeep).fill(0).map((_, i) => `Semana ${i+1}`);

console.log(trimmedWeeklyCurrent);
console.log(trimmedWeeklyHistory);
console.log(trimmedDailyLabels);
