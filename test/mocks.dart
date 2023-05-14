import 'package:mockito/mockito.dart';

class MockResponseBody extends Mock {
  final Map<String, dynamic> _data;

  MockResponseBody(this._data);

  dynamic operator [](String key) => _data[key];
}

final testProjectConfig = {
  "apiKey": "sk-ssss",
  "outputDir": "output_dir",
  "projectName": "myProject",
  "projectVersion": "projectVersion",
  "reportDir": "reportDir",
  "dataDir": "dataDir"
};

final testBlock = {"blockId": "blockId", "pluginName": "pluginName"};
