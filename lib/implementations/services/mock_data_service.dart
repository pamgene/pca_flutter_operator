import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../../domain/models/pca_data.dart';
import '../../domain/services/data_service.dart';

class MockDataService implements DataService {
  @override
  Future<PcaData> loadData({bool scale = false}) async {
    final results = await Future.wait([
      rootBundle.loadString('assets/data/scores.csv'),
      rootBundle.loadString('assets/data/loadings.csv'),
      rootBundle.loadString('assets/data/variance.csv'),
      rootBundle.loadString('assets/data/annotations.csv'),
    ]);

    final scores = _parseScores(results[0]);
    final loadings = _parseLoadings(results[1]);
    final variance = _parseVariance(results[2]);
    final annotations = _parseAnnotations(results[3]);

    final fieldNames = annotations.isNotEmpty
        ? annotations.first.fields.keys.toList()
        : <String>[];

    return PcaData(
      scores: scores,
      loadings: loadings,
      variance: variance,
      annotations: annotations,
      numComponents: variance.length,
      annotationFields: fieldNames,
      defaultColorBy: fieldNames.isNotEmpty ? fieldNames.first : '',
    );
  }

  @override
  Future<void> saveResults(PcaData data) async {}

  List<PcaScore> _parseScores(String csv) {
    final rows = const CsvToListConverter(eol: '\n').convert(csv);
    return rows.skip(1).where((r) => r.length >= 6).map((row) => PcaScore(
      ci: (row[0] as num).toInt(),
      values: [for (int i = 1; i <= 5; i++) (row[i] as num).toDouble()],
    )).toList();
  }

  List<PcaLoading> _parseLoadings(String csv) {
    final rows = const CsvToListConverter(eol: '\n').convert(csv);
    return rows.skip(1).where((r) => r.length >= 7).map((row) => PcaLoading(
      ri: (row[0] as num).toInt(),
      variable: row[1].toString(),
      values: [for (int i = 2; i <= 6; i++) (row[i] as num).toDouble()],
    )).toList();
  }

  List<PcVariance> _parseVariance(String csv) {
    final rows = const CsvToListConverter(eol: '\n').convert(csv);
    return rows.skip(1).where((r) => r.length >= 3).map((row) => PcVariance(
      label: row[0].toString(),
      variance: (row[1] as num).toDouble(),
      percent: (row[2] as num).toDouble(),
    )).toList();
  }

  List<SampleAnnotation> _parseAnnotations(String csv) {
    final rows = const CsvToListConverter(eol: '\n').convert(csv);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((h) => h.toString()).toList();
    return rows.skip(1).where((r) => r.length >= headers.length).map((row) {
      final fields = <String, String>{};
      for (int i = 1; i < headers.length; i++) {
        fields[headers[i]] = row[i].toString();
      }
      return SampleAnnotation(
        ci: (row[0] as num).toInt(),
        fields: fields,
      );
    }).toList();
  }
}
