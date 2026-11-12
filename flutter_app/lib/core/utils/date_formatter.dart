class DateFormatter {
  DateFormatter._();

  static String timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hr lalu';
      return '${date.day} ${_monthName(date.month)} ${date.year}';
    } catch (_) {
      return '';
    }
  }

  static String _monthName(int m) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return m >= 1 && m <= 12 ? months[m] : '';
  }
}
