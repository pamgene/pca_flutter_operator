/// Alternative mock dataset designed to demonstrate the visible effect of
/// scaling. Variables 0-3 (GeneA-D) are group-discriminating at small scale
/// (~5 units). Variables 4-7 (BatchX-W) are noise at large scale (~100 units).
///
/// Without scaling: BatchX-W dominate PC1 (large variance), groups not separated.
/// With scaling:    GeneA-D dominate, three groups (A/B/C) separate cleanly.
///
/// To use as the default mock, swap MockDataService for this in service_locator.dart.
library;

import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../../core/math/pca_computation.dart';
import '../../domain/models/pca_data.dart';
import '../../domain/services/data_service.dart';

class MockDataServiceScaleDemo implements DataService {
  static const List<String> _varNames = [
    'GeneA', 'GeneB', 'GeneC', 'GeneD',
    'BatchX', 'BatchY', 'BatchZ', 'BatchW',
  ];

  // 20 samples × 8 variables. Groups: A=0-6, B=7-13, C=14-19.
  static final List<List<double>> _rawX = [
    // Group A — centroid (5, 3, -2, 4) in vars 0-3
    [ 5.2,  3.1, -2.0,  4.3,  120.0, -85.0,  43.0, -62.0],
    [ 4.8,  2.7, -1.6,  3.9,  -30.0,  110.0, -90.0,  55.0],
    [ 5.5,  3.4, -2.3,  4.1,   75.0,  -20.0,  88.0, -40.0],
    [ 4.6,  3.0, -1.9,  4.6,  -95.0,   60.0, -15.0,  77.0],
    [ 5.1,  2.8, -2.1,  3.7,   40.0, -100.0,  55.0, -88.0],
    [ 5.3,  3.3, -1.7,  4.2,  -55.0,   30.0, -70.0,  20.0],
    [ 4.9,  2.9, -2.2,  4.0,   85.0,  -45.0,  10.0, -50.0],
    // Group B — centroid (-3, 5, 4, -2) in vars 0-3
    [-3.1,  5.0,  4.2, -2.1,   65.0, -110.0,  30.0,  90.0],
    [-2.8,  5.3,  3.9, -2.4,  -80.0,   50.0, -60.0, -35.0],
    [-3.3,  4.8,  4.4, -1.8,   25.0,   95.0, -20.0,  70.0],
    [-2.9,  5.1,  4.0, -2.2, -100.0,  -30.0,  80.0, -55.0],
    [-3.2,  4.9,  4.3, -2.0,   55.0,  -75.0,  40.0, -15.0],
    [-2.7,  5.2,  3.8, -2.3,  -40.0,  105.0, -50.0,  45.0],
    [-3.0,  5.0,  4.1, -1.9,   90.0,  -20.0, -85.0,  60.0],
    // Group C — centroid (-2, -4, 3, 5) in vars 0-3
    [-2.1, -4.0,  3.1,  5.2,  -70.0,   40.0,  95.0, -80.0],
    [-1.8, -4.3,  2.8,  4.9,   35.0, -115.0, -25.0,  50.0],
    [-2.3, -3.8,  3.3,  5.0,   80.0,   65.0, -90.0, -40.0],
    [-2.0, -4.1,  3.0,  5.3,  -50.0,  -35.0,  60.0,  75.0],
    [-1.9, -4.2,  2.9,  4.8,  110.0,   20.0, -45.0, -60.0],
    [-2.2, -3.9,  3.2,  5.1,  -90.0,   85.0,  15.0,  30.0],
  ];

  @override
  Future<PcaData> loadData({bool scale = false}) async {
    final annotationsCsv = await rootBundle.loadString('assets/data/annotations.csv');
    final annotations = _parseAnnotations(annotationsCsv);

    final nObs = _rawX.length;
    final nVars = _varNames.length;
    final nc = min(5, min(nObs - 1, nVars));

    final result = PcaComputation.compute(X: _rawX, scale: scale, nComponents: nc);

    final scores = List.generate(nObs, (i) => PcaScore(ci: i, values: result.scores[i]));
    final loadings = List.generate(nVars, (j) =>
        PcaLoading(ri: j, variable: _varNames[j], values: result.loadings[j]));
    final variance = List.generate(result.allEigenvalues.length, (k) {
      if (result.allEigenvalues[k] < 1e-12) return null;
      return PcVariance(
        label: 'PC${k + 1}',
        variance: result.allEigenvalues[k],
        percent: result.allVariancePercent[k],
      );
    }).whereType<PcVariance>().toList();

    final fieldNames = annotations.isNotEmpty ? annotations.first.fields.keys.toList() : <String>[];

    return PcaData(
      scores: scores,
      loadings: loadings,
      variance: variance,
      annotations: annotations,
      numComponents: result.nComponents,
      annotationFields: fieldNames,
      defaultColorBy: fieldNames.isNotEmpty ? fieldNames.first : '',
    );
  }

  @override
  Future<void> saveResults(PcaData data) async {}

  List<SampleAnnotation> _parseAnnotations(String csv) {
    final rows = const CsvToListConverter(eol: '\n').convert(csv);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((h) => h.toString()).toList();
    return rows.skip(1).where((r) => r.length >= headers.length).map((row) {
      final fields = <String, String>{};
      for (int i = 1; i < headers.length; i++) {
        fields[headers[i]] = row[i].toString();
      }
      return SampleAnnotation(ci: (row[0] as num).toInt(), fields: fields);
    }).toList();
  }
}
