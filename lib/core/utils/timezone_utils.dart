import 'package:timezone/timezone.dart' as tz;

/// Utility class untuk mengelola timezone Indonesia (Jakarta/WIB)
class TimezoneUtils {
  // Mendapatkan lokasi timezone Jakarta
  static tz.Location get jakartaLocation => tz.getLocation('Asia/Jakarta');
  
  /// Mendapatkan waktu sekarang dengan timezone Jakarta/WIB
  static tz.TZDateTime nowInJakarta() {
    return tz.TZDateTime.now(jakartaLocation);
  }
  
  /// Mengonversi DateTime UTC ke timezone Jakarta
  static tz.TZDateTime toJakartaTime(DateTime utcDateTime) {
    return tz.TZDateTime.from(utcDateTime, jakartaLocation);
  }
  
  /// Mengonversi string ISO8601 ke timezone Jakarta
  static tz.TZDateTime parseToJakartaTime(String isoString) {
    final utcDateTime = DateTime.parse(isoString);
    return tz.TZDateTime.from(utcDateTime, jakartaLocation);
  }
  
  /// Membuat TZDateTime dengan timezone Jakarta dari komponen tanggal
  static tz.TZDateTime createJakartaTime({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
  }) {
    return tz.TZDateTime(
      jakartaLocation,
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
    );
  }
  
  /// Format tanggal dengan timezone Jakarta untuk display
  static String formatJakartaDate(tz.TZDateTime dateTime, {String format = 'dd/MM/yyyy'}) {
    switch (format) {
      case 'dd/MM/yyyy':
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      case 'dd/MM/yyyy HH:mm':
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      case 'yyyy-MM-dd':
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      case 'yyyy-MM-dd HH:mm:ss':
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
      default:
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
  
  /// Mendapatkan informasi timezone Indonesia
  static String get timezoneInfo => 'Asia/Jakarta (WIB, GMT+7)';
  
  /// Mengecek apakah waktu yang diberikan adalah hari ini (Jakarta time)
  static bool isToday(tz.TZDateTime dateTime) {
    final today = nowInJakarta();
    return dateTime.year == today.year && 
           dateTime.month == today.month && 
           dateTime.day == today.day;
  }
  
  /// Mengecek apakah waktu yang diberikan adalah besok (Jakarta time)
  static bool isTomorrow(tz.TZDateTime dateTime) {
    final tomorrow = nowInJakarta().add(const Duration(days: 1));
    return dateTime.year == tomorrow.year && 
           dateTime.month == tomorrow.month && 
           dateTime.day == tomorrow.day;
  }
  
  /// Mendapatkan selisih hari dari sekarang (Jakarta time)
  static int daysDifferenceFromNow(tz.TZDateTime dateTime) {
    final now = nowInJakarta();
    final nowDate = tz.TZDateTime(jakartaLocation, now.year, now.month, now.day);
    final targetDate = tz.TZDateTime(jakartaLocation, dateTime.year, dateTime.month, dateTime.day);
    return targetDate.difference(nowDate).inDays;
  }
}
