import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shopping_list/data/services/api_exception.dart';

void main() {
  group('toString', () {
    // These strings are for the developer at the console. The day this project
    // adds Sentry, they become what leaves the device — and then the response
    // body and the transport cause below have to go. Locking the format here
    // makes that a deliberate change instead of a silent one.
    test('ApiException carries the status and the body', () {
      expect(
        ApiException(409, 'duplicate key').toString(),
        'ApiException(409): duplicate key',
      );
    });

    test('NetworkException carries the transport cause', () {
      expect(
        NetworkException(ClientException('closed')).toString(),
        contains('NetworkException:'),
      );
    });
  });
}
