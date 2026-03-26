# 2024-05-24
Bolt Optimization: When rendering Chart.js line charts with `fill: true` that share the same y-axis scale, dynamically sorting datasets by their total volume ensures that datasets with smaller areas are drawn last (on top). This prevents large filled areas from visually obscuring smaller filled areas and data points, resolving issues where lines appear hidden or missing on the chart.
