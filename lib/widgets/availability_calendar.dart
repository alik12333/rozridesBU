import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AvailabilityCalendar extends StatefulWidget {
  final List<Map<String, dynamic>> bookedDateRanges;
  final Function(DateTime? start, DateTime? end) onRangeSelected;

  const AvailabilityCalendar({
    Key? key,
    required this.bookedDateRanges,
    required this.onRangeSelected,
  }) : super(key: key);

  @override
  State<AvailabilityCalendar> createState() => _AvailabilityCalendarState();
}

class _AvailabilityCalendarState extends State<AvailabilityCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;

  bool _isDayBooked(DateTime day) {
    // Normalize string/time values just to strip hours for accurate comparison
    DateTime dayOnly = DateTime(day.year, day.month, day.day);

    for (var range in widget.bookedDateRanges) {
      DateTime start = (range['start'] as Timestamp).toDate();
      DateTime end = (range['end'] as Timestamp).toDate();
      
      DateTime startOnly = DateTime(start.year, start.month, start.day);
      DateTime endOnly = DateTime(end.year, end.month, end.day);
      
      // If the day falls anywhere within start and end inclusive
      if (dayOnly.isAfter(startOnly.subtract(const Duration(days: 1))) && 
          dayOnly.isBefore(endOnly.add(const Duration(days: 1)))) {
        return true;
      }
    }
    return false;
  }

  bool _doesRangeContainBookedDates(DateTime start, DateTime end) {
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (_isDayBooked(current)) return true;
      current = current.add(const Duration(days: 1));
    }
    return false;
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;

      if (start != null && end != null) {
        if (_doesRangeContainBookedDates(start, end)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selection contains already booked dates!'),
              backgroundColor: Colors.red,
            ),
          );
          _rangeStart = start;
          _rangeEnd = null; // Reset the end date
        } else {
          _rangeStart = start;
          _rangeEnd = end;
        }
      } else {
        _rangeStart = start;
        _rangeEnd = end;
      }
      
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });

    widget.onRangeSelected(_rangeStart, _rangeEnd);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TableCalendar(
        firstDay: DateTime.now(),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_rangeStart, day),
        rangeStartDay: _rangeStart,
        rangeEndDay: _rangeEnd,
        calendarFormat: CalendarFormat.month,
        rangeSelectionMode: _rangeSelectionMode,
        onRangeSelected: _onRangeSelected,
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        enabledDayPredicate: (day) {
          // Disable past days and booked days
          if (day.isBefore(DateTime.now().subtract(const Duration(days: 1)))) return false;
          return !_isDayBooked(day);
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarStyle: CalendarStyle(
          rangeHighlightColor: Theme.of(context).primaryColor.withAlpha(50),
          rangeStartDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          rangeEndDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          withinRangeTextStyle: TextStyle(color: Theme.of(context).primaryColor),
          disabledDecoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          disabledTextStyle: TextStyle(color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
          todayDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withAlpha(80),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
