import 'dart:html';

import 'package:eom/io/io.dart';

class WebIO implements IO {
  @override
  void createDirectoryIfNotExist(String dirName) {
   //noop
  }

  @override
  Future<String> readFileAsString(String filePath) async {
    return window.localStorage[filePath].toString();
  }

  @override
  Future<void> writeMap(Map<String, dynamic> data, String filePath) async {
    window.localStorage[filePath] = "";
  }

  @override
  Future<void> writeString(String content, String filePath) async {
    window.localStorage[filePath] = content;
    return;
  }

  @override
  Future<void> writeMetrics(responseBody, promptFileName, filePath) async {
    //noop
  }

}