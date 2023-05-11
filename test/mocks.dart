import 'package:mockito/mockito.dart';

class MockResponseBody extends Mock {
  final Map<String, dynamic> _data;

  MockResponseBody(this._data);

  dynamic operator [](String key) => _data[key];
}
