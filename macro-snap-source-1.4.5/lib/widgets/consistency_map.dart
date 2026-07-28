import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/habit.dart' show Habit, dateKey;

/// A GitHub-style contribution heatmap showing habit completion
/// consistency over the last 12 weeks.
class ConsistencyMap extends StatelessWidget {
  final List<Habit> habits;
  final int weeksToShow;
  final void Function(DateTime date, int count, List<String> habitNames)? onCellTap;

  const ConsistencyMap({
    super.key,
    required this.habits,
    this.weeksToShow = 12,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final totalDays = weeksToShow * 7;

    // Build a map of dateKey → completion count across all habits
    final Map<String, int> dailyCount = {};
    int maxCount = 0;
    for (final h in habits) {
      for (final key in h.completedDates) {
        dailyCount[key] = (dailyCount[key] ?? 0) + 1;
        if (dailyCount[key]! > maxCount) maxCount = dailyCount[key]!;
      }
    }

    // Ensure maxCount is at least 1 to avoid division by zero
    if (maxCount < 1) maxCount = 1;

    // Generate the grid cells (oldest to newest, left to right)
    // Each column = a week (Mon-Sun), each row = a day of week
    final startDate = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: totalDays - 1));

    // Build month labels: which columns have the first day of a month
    final monthLabels = <_MonthLabel>[];
    for (var i = 0; i < weeksToShow; i++) {
      final weekStart = startDate.add(Duration(days: i * 7));
      for (var d = 0; d < 7; d++) {
        final date = weekStart.add(Duration(days: d));
        if (date.day == 1 && !date.isAfter(today)) {
          monthLabels.add(_MonthLabel(weekIndex: i, label: _monthAbbr(date.month)));
          break;
        }
      }
    }
    // Always label the first week's month
    if (monthLabels.isEmpty || monthLabels.first.weekIndex > 0) {
      monthLabels.insert(0, _MonthLabel(weekIndex: 0, label: _monthAbbr(startDate.month)));
    }

    // Cell size calculation
    const cellSize = 14.0;
    const cellGap = 3.0;
    const colWidth = cellSize + cellGap;
    const rowHeight = cellSize + cellGap;
    const leftLabelWidth = 32.0;
    const topLabelHeight = 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Month labels ──────────────────────────────────
        SizedBox(
          height: topLabelHeight,
          child: Stack(
            children: [
              // Left spacer for weekday labels
              const SizedBox(width: leftLabelWidth),
              // Month labels positioned over the grid
              ...monthLabels.map((ml) {
                return Positioned(
                  left: leftLabelWidth + ml.weekIndex * colWidth,
                  top: 0,
                  child: Text(
                    ml.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // ─── Grid rows ─────────────────────────────────────
        SizedBox(
          height: 7 * rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday labels (left side)
              SizedBox(
                width: leftLabelWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (row) {
                    // Only show Mon, Wed, Fri labels
                    final showLabel = row == 0 || row == 2 || row == 4;
                    return SizedBox(
                      height: rowHeight,
                      child: showLabel
                          ? Padding(
                              padding: EdgeInsets.only(top: row == 0 ? 0 : cellGap),
                              child: Text(
                                _weekdayAbbr(row + 1),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                                ),
                              ),
                            )
                          : null,
                    );
                  }),
                ),
              ),
              // Grid columns (weeks)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    height: 7 * rowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(weeksToShow, (weekIndex) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(7, (dayIndex) {
                            final date = startDate
                                .add(Duration(days: weekIndex * 7 + dayIndex));
                            final key = dateKey(date);
                            final count = dailyCount[key] ?? 0;
                            final intensity =
                                maxCount > 0 ? count / maxCount : 0.0;

                            Color cellColor;
                            if (date.isAfter(today)) {
                              cellColor = Colors.transparent;
                            } else if (count == 0) {
                              cellColor = isDark
                                  ? const Color(0xFF26262E)
                                  : const Color(0xFFEDE9FE);
                            } else {
                              cellColor = Color.lerp(
                                MacroSnapTheme.neonGreen.withValues(alpha: 0.3),
                                MacroSnapTheme.neonGreen,
                                intensity,
                              )!;
                            }

                            return Padding(
                              padding: EdgeInsets.only(
                                top: dayIndex == 0 ? 0 : cellGap,
                                right: cellGap,
                              ),
                              child: Tooltip(
                                message:
                                    '${_formatDate(date)}: $count/${habits.length} habits',
                                child: GestureDetector(
                                  onTap: date.isAfter(today)
                                      ? null
                                      : () {
                                          final names = habits
                                              .where((h) =>
                                                  h.isCompleted(date))
                                              .map((h) => h.emoji + h.name)
                                              .toList();
                                          onCellTap?.call(
                                              date, count, names);
                                        },
                                  child: Container(
                                    width: cellSize,
                                    height: cellSize,
                                    decoration: BoxDecoration(
                                      color: cellColor,
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ─── Legend ─────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 6),
            ...List.generate(5, (i) {
              final intensity = maxCount > 0 ? (i * maxCount ~/ 4) / maxCount : 0.0;
              Color c;
              if (i == 0) {
                c = isDark ? const Color(0xFF26262E) : const Color(0xFFEDE9FE);
              } else {
                c = Color.lerp(
                  MacroSnapTheme.neonGreen.withValues(alpha: 0.3),
                  MacroSnapTheme.neonGreen,
                  intensity,
                )!;
              }
              return Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
            Text(
              'More',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _monthAbbr(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _weekdayAbbr(int weekday) {
    const labels = ['Mon', '', 'Wed', '', 'Fri', '', ''];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _MonthLabel {
  final int weekIndex;
  final String label;
  const _MonthLabel({required this.weekIndex, required this.label});
}
