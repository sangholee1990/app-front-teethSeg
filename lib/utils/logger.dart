import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

final logger = Logger(printer: Log4jPrinter());

class Log4jPrinter extends LogPrinter {
  static final levelStrings = {
    Level.verbose: 'TRACE',
    Level.debug:   'DEBUG',
    Level.info:    'INFO ',
    Level.warning: 'WARN ',
    Level.error:   'ERROR',
    Level.wtf:     'FATAL',
  };

  @override
  List<String> log(LogEvent event) {
    final timeStamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(event.time);
    final level = levelStrings[event.level] ?? '-';
    final message = event.message;

    final logMessage = "[$timeStamp] [$level] $message";

    if (event.error != null) {
      return [logMessage, '  => ${event.error}', if (event.stackTrace != null) '  ${event.stackTrace}'];
    }

    return [logMessage];
  }
}