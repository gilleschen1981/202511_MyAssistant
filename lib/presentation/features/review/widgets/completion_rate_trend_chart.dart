import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Completion Rate Trend Chart Widget
class CompletionRateTrendChart extends StatelessWidget {
  final Map<DateTime, double> trendData;
  final int days;

  const CompletionRateTrendChart({
    super.key,
    required this.trendData,
    this.days = 30,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (trendData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '暂无数据',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Sort dates
    final sortedDates = trendData.keys.toList()..sort();

    // Create data points
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final rate = trendData[date] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), rate * 100)); // Convert to percentage
    }

    // Calculate min and max for Y axis
    const minY = 0.0;
    const maxY = 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '完成率趋势（最近$days天）',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.surfaceContainerHighest,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (sortedDates.length / 5).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedDates.length) {
                            return const Text('');
                          }
                          final date = sortedDates[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MM/dd').format(date),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 25,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.surfaceContainerHighest,
                        width: 1,
                      ),
                      left: BorderSide(
                        color: theme.colorScheme.surfaceContainerHighest,
                        width: 1,
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: (sortedDates.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: theme.colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: theme.colorScheme.inverseSurface,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          if (index < 0 || index >= sortedDates.length) {
                            return null;
                          }
                          final date = sortedDates[index];
                          return LineTooltipItem(
                            '${DateFormat('MM/dd').format(date)}\n${spot.y.toStringAsFixed(1)}%',
                            TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
