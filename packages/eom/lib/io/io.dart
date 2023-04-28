abstract class IO {
  Future<void> writeMetrics(responseBody, promptFileName, filePath);

  Future<String> readFileAsString(String filePath);

  Future<void> writeMap(Map<String, dynamic> data, String filePath);

  Future<void> writeString(String content, String filePath);

  void createDirectoryIfNotExist(String dirName);
}

