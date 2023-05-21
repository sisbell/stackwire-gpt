import 'package:args/command_runner.dart';
import 'package:file/local.dart';
import 'package:gpt/src/chatgpt/catalog_parser.dart';
import 'package:gpt/src/io_helper.dart';

final localFileSystem = LocalFileSystem();

final ioHelper = IOHelper(fileSystem: localFileSystem);

class CatalogCommand extends Command {
  @override
  String get description => "Manages plugin catalog data";

  @override
  String get name => "catalog";

  CatalogCommand() {
    addSubcommand(ParseCatalogCommand());
  }
}

class ParseCatalogCommand extends Command {
  @override
  String get description => "Creates a Plugin Catalog File";

  @override
  String get name => "parse";

  ParseCatalogCommand() {
    argParser.addOption('input', abbr: 'i', defaultsTo: "manifests.json");
    argParser.addOption('output', abbr: 'o', defaultsTo: "catalog.json");
  }

  @override
  Future<void> run() async {
    final input = argResults?['input'];
    final output = argResults?['output'];
    final inputFile = localFileSystem.file(input);
    final outputFile = localFileSystem.file(output);
    await parseCatalog(inputFile, outputFile);
  }
}
