import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:file/local.dart';
import 'package:gpt/src/chatgpt/catalog_client.dart';
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
    addSubcommand(DownloadManifestsCommand());
  }
}

class DownloadManifestsCommand extends Command {
  @override
  String get description =>
      "Attempts to download plugin manifests from well-known location";

  @override
  String get name => "download-manifests";

  @override
  Future<void> run() async {
    final client = CatalogClient(localFileSystem);
    final domainFile = localFileSystem.file('domains.json');
    final domains = jsonDecode(await domainFile.readAsString());
    final outputDir = "output/catalog";
    client.downloadManifests(domains, outputDir);
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
    argParser.addFlag("domain", defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final input = argResults?['input'];
    final output = argResults?['output'];
    final inputFile = localFileSystem.file(input);
    final outputFile = localFileSystem.file(output);
    final isDomainOutput = argResults?['domain'];
    if (isDomainOutput) {
      await parseDomains(inputFile, outputFile);
    } else {
      await parseCatalog(inputFile, outputFile);
    }
  }
}
