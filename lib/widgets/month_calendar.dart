import 'package:flutter/material.dart';

class MonthCalendar extends StatefulWidget {
  final List<DateTime> highlightedDates;
  const MonthCalendar({super.key, required this.highlightedDates});

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _visibleMonth;

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _weekdays = ['Su','Mo','Tu','We','Th','Fr','Sa'];

  @override
  void initState() {
    super.initState();
    final anchor = widget.highlightedDates.isNotEmpty ? widget.highlightedDates.first : DateTime.now();
    _visibleMonth = DateTime(anchor.year, anchor.month);
  }

  void _changeMonth(int delta) {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta));
  }

  bool _isHighlighted(DateTime day) => widget.highlightedDates.any(
        (d) => d.year == day.year && d.month == day.month && d.day == day.day,
      );

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left, color: Colors.black), onPressed: () => _changeMonth(-1)),
              Text('${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.chevron_right, color: Colors.black), onPressed: () => _changeMonth(1)),
            ],
          ),
          Row(
            children: _weekdays
                .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))))
                .toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = index - leadingBlanks + 1;
              final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
              final highlighted = _isHighlighted(date);
              return Center(
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: highlighted ? Colors.black : null, shape: BoxShape.circle),
                  child: Text('$day',
                      style: TextStyle(color: highlighted ? Colors.white : Colors.black,
                          fontWeight: highlighted ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}