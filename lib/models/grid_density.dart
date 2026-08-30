/// Visual density presets for the schedule grid.
enum GridDensity { compact, standard, comfortable }

class GridDensityMetrics {
  const GridDensityMetrics({
    required this.rowHeight,
    required this.timeColumnWidth,
    required this.tableHeaderExtent,
    required this.weekdayChipHeight,
    required this.courseNameFontSize,
    required this.courseMetaFontSize,
  });

  final double rowHeight;
  final double timeColumnWidth;
  final double tableHeaderExtent;
  final double weekdayChipHeight;
  final double courseNameFontSize;
  final double courseMetaFontSize;

  static GridDensityMetrics forDensity(GridDensity density) {
    return switch (density) {
      GridDensity.compact => const GridDensityMetrics(
        rowHeight: 52,
        timeColumnWidth: 44,
        tableHeaderExtent: 44,
        weekdayChipHeight: 40,
        courseNameFontSize: 9,
        courseMetaFontSize: 8,
      ),
      GridDensity.standard => const GridDensityMetrics(
        rowHeight: 64,
        timeColumnWidth: 52,
        tableHeaderExtent: 52,
        weekdayChipHeight: 48,
        courseNameFontSize: 10,
        courseMetaFontSize: 9,
      ),
      GridDensity.comfortable => const GridDensityMetrics(
        rowHeight: 76,
        timeColumnWidth: 60,
        tableHeaderExtent: 56,
        weekdayChipHeight: 52,
        courseNameFontSize: 11,
        courseMetaFontSize: 10,
      ),
    };
  }
}
