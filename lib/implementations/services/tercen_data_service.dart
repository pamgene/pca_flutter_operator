import 'dart:math';
import 'package:sci_tercen_context/sci_tercen_context.dart';

import '../../core/math/pca_computation.dart';
import '../../domain/models/pca_data.dart';
import '../../domain/services/data_service.dart';
import 'mock_data_service.dart';

class TercenDataService implements DataService {
  final ServiceFactoryBase _factory;
  final String _taskId;
  final MockDataService _mockService = MockDataService();

  AbstractOperatorContext? _ctx;

  TercenDataService(this._factory, this._taskId);

  Future<AbstractOperatorContext> _getContext() async {
    if (_ctx != null) return _ctx!;
    print('PCA Explorer: creating OperatorContext for taskId=$_taskId');
    _ctx = await OperatorContext.create(
      serviceFactory: _factory,
      taskId: _taskId,
    );
    print('PCA Explorer: OperatorContext created, task=${_ctx!.task?.runtimeType}');
    return _ctx!;
  }

  @override
  Future<PcaData> loadData({bool scale = true}) async {
    try {
      final ctx = await _getContext();

      // Use scale value from UI (overrides operator property)
      final scaleSpots = scale;
      final nComponentsProp =
          (await ctx.opDoubleValue('Number of Components', defaultValue: 5))
              .toInt();
      final subtractComponent =
          (await ctx.opDoubleValue('Subtract component', defaultValue: 0))
              .toInt();

      // 2. Fetch three tables
      await ctx.progress('Loading data...', actual: 0, total: 5);
      final qtData = await ctx.select(names: ['.y', '.ci', '.ri']);
      await ctx.progress('Loading column metadata...', actual: 1, total: 5);
      final colData = await ctx.cselect();
      await ctx.progress('Loading row metadata...', actual: 2, total: 5);
      final rowData = await ctx.rselect();

      // 3. Get color factors for default Color By
      List<String> colorFactors;
      try {
        colorFactors = await ctx.colors;
      } catch (_) {
        colorFactors = [];
      }

      // 4. Parse qtData arrays
      List ciRaw = [];
      List riRaw = [];
      List<double> yValues = [];
      for (final col in qtData.columns) {
        final values = col.values as List?;
        if (values == null) continue;
        switch (col.name) {
          case '.ci':
            ciRaw = values;
          case '.ri':
            riRaw = values;
          case '.y':
            yValues = values.map((v) => (v as num).toDouble()).toList();
        }
      }

      if (yValues.isEmpty) {
        throw StateError('No .y values returned from ctx.select()');
      }

      // 5. Build unique sorted ci and ri lists
      final uniqueCi = <int>{};
      final uniqueRi = <int>{};
      for (int i = 0; i < ciRaw.length; i++) {
        uniqueCi.add(_toInt(ciRaw[i]));
        uniqueRi.add(_toInt(riRaw[i]));
      }
      final sortedCi = uniqueCi.toList()..sort();
      final sortedRi = uniqueRi.toList()..sort();
      final ciIdx = {
        for (var i = 0; i < sortedCi.length; i++) sortedCi[i]: i,
      };
      final riIdx = {
        for (var i = 0; i < sortedRi.length; i++) sortedRi[i]: i,
      };

      final nObs = sortedCi.length;
      final nVars = sortedRi.length;

      // 6. Build X matrix (n_obs x n_vars)
      final X = List.generate(nObs, (_) => List.filled(nVars, 0.0));
      for (int i = 0; i < ciRaw.length; i++) {
        final ci = _toInt(ciRaw[i]);
        final ri = _toInt(riRaw[i]);
        X[ciIdx[ci]!][riIdx[ri]!] = yValues[i];
      }

      // 7. Compute PCA
      await ctx.progress('Computing PCA...', actual: 3, total: 5);
      print('PCA Explorer: scaleSpots=$scaleSpots, nComponents=$nComponentsProp, subtractComponent=$subtractComponent');
      print('PCA Explorer: matrix ${nObs}x$nVars');

      // Jacobi self-test: 4x4 matrix with known eigenvalues [4, 4, 4, 0]
      // (4I - J, where J is all-ones matrix — simulates centered data)
      final testEV = PcaComputation.testEigen([
        [3, -1, -1, -1],
        [-1, 3, -1, -1],
        [-1, -1, 3, -1],
        [-1, -1, -1, 3],
      ]);
      print('PCA Explorer: Jacobi self-test=${testEV.map((v) => v.toStringAsFixed(4)).toList()} (expected: [4, 4, 4, 0])');

      // Second test: 2x2 with known eigenvalues [3, 1]
      final testEV2 = PcaComputation.testEigen([
        [2, 1],
        [1, 2],
      ]);
      print('PCA Explorer: Jacobi self-test2=${testEV2.map((v) => v.toStringAsFixed(4)).toList()} (expected: [3, 1])');

      final pcaResult = PcaComputation.compute(
        X: X,
        scale: scaleSpots,
        nComponents: min(nComponentsProp, min(nObs - 1, nVars)),
        subtractComponent: subtractComponent,
      );
      print('PCA Explorer: top 5 eigenvalues=${pcaResult.allEigenvalues.take(5).toList()}');
      print('PCA Explorer: last eigenvalue=${pcaResult.allEigenvalues.last} (should be ~0 for centered data)');
      print('PCA Explorer: totalVariance=${pcaResult.allEigenvalues.fold(0.0, (a, b) => a + b).toStringAsFixed(2)}');

      // 8. Build index maps from column/row metadata
      final colMetadata = _buildIndexMap(colData);
      final rowMetadata = _buildIndexMap(rowData);

      // 9. Build scores
      final scores = <PcaScore>[];
      for (int i = 0; i < nObs; i++) {
        scores.add(PcaScore(ci: sortedCi[i], values: pcaResult.scores[i]));
      }

      // 10. Build loadings
      final loadings = <PcaLoading>[];
      for (int j = 0; j < nVars; j++) {
        final ri = sortedRi[j];
        // Variable name from row metadata — pick first non-dot column value
        String varName = 'var_$ri';
        final meta = rowMetadata[j];
        if (meta != null) {
          for (final entry in meta.entries) {
            if (!entry.key.startsWith('.')) {
              varName = _stripNamespace(entry.value.toString());
              break;
            }
          }
        }
        loadings
            .add(PcaLoading(ri: ri, variable: varName, values: pcaResult.loadings[j]));
      }

      // 11. Build variance — first 10 components for screeplot (matching R's screeplot default)
      final variance = <PcVariance>[];
      final maxScreePCs = pcaResult.allEigenvalues.length < 10
          ? pcaResult.allEigenvalues.length
          : 10;
      for (int k = 0; k < maxScreePCs; k++) {
        if (pcaResult.allEigenvalues[k] < 1e-12) continue;
        variance.add(PcVariance(
          label: 'PC${k + 1}',
          variance: pcaResult.allEigenvalues[k],
          percent: pcaResult.allVariancePercent[k],
        ));
      }

      // 12. Build annotations from column metadata
      final annotationFieldNames = <String>{};
      // Color factors first
      for (final cf in colorFactors) {
        annotationFieldNames.add(_stripNamespace(cf));
      }
      // All cselect columns (non-system)
      for (final meta in colMetadata.values) {
        for (final key in meta.keys) {
          if (!key.startsWith('.')) {
            annotationFieldNames.add(_stripNamespace(key));
          }
        }
      }

      final fieldList = annotationFieldNames.toList();
      final annotations = <SampleAnnotation>[];
      for (int i = 0; i < nObs; i++) {
        final ci = sortedCi[i];
        final meta = colMetadata[i] ?? {};
        final fields = <String, String>{};
        for (final fieldName in fieldList) {
          String value = '';
          for (final entry in meta.entries) {
            if (_stripNamespace(entry.key) == fieldName) {
              value = entry.value?.toString() ?? '';
              break;
            }
          }
          fields[fieldName] = value;
        }
        annotations.add(SampleAnnotation(ci: ci, fields: fields));
      }

      // 13. Determine default Color By
      String defaultColorBy = fieldList.isNotEmpty ? fieldList.first : '';
      if (colorFactors.isNotEmpty) {
        final stripped = _stripNamespace(colorFactors.first);
        if (fieldList.contains(stripped)) {
          defaultColorBy = stripped;
        }
      }

      await ctx.progress('Done', actual: 5, total: 5);

      print('PCA Explorer: SUCCESS — ${scores.length} scores, ${loadings.length} loadings, ${variance.length} PCs');
      print('PCA Explorer: annotationFields=$fieldList');
      print('PCA Explorer: defaultColorBy=$defaultColorBy');
      if (scores.isNotEmpty) {
        print('PCA Explorer: first score ci=${scores.first.ci}, values=${scores.first.values.take(3).toList()}');
      }
      if (annotations.isNotEmpty) {
        print('PCA Explorer: first annotation ci=${annotations.first.ci}, fields=${annotations.first.fields}');
      }

      return PcaData(
        scores: scores,
        loadings: loadings,
        variance: variance,
        annotations: annotations,
        numComponents: pcaResult.nComponents,
        annotationFields: fieldList,
        defaultColorBy: defaultColorBy,
      );
    } catch (e) {
      print('PCA Explorer: Tercen data loading error: $e');
      await _printDiagnosticReport();
      return _mockService.loadData();
    }
  }

  @override
  Future<void> saveResults(PcaData data) async {
    try {
      final ctx = await _getContext();

      await ctx.progress('Saving results...', actual: 0, total: 3);

      final nc = data.numComponents;
      final nRows = data.loadings.length * data.scores.length;

      // Match Shiny's getReturnData(): flat cross-tab with both loadings and scores
      // For each (ri, ci) pair:
      //   PC1..PCn     = loading values (broadcast per ri, same for all ci with same ri)
      //   score1..scoren = score values (broadcast per ci, same for all ri with same ci)
      final outCi = <int>[];
      final outRi = <int>[];
      final outLoading = List.generate(nc, (_) => <double>[]);
      final outScore = List.generate(nc, (_) => <double>[]);

      // Build lookup maps for scores by ci
      final scoresByCi = <int, List<double>>{};
      for (final score in data.scores) {
        scoresByCi[score.ci] = score.values;
      }

      for (final loading in data.loadings) {
        for (final score in data.scores) {
          outRi.add(loading.ri);
          outCi.add(score.ci);
          for (int k = 0; k < nc; k++) {
            outLoading[k].add(loading.values[k]);
            outScore[k].add(score.values[k]);
          }
        }
      }

      await ctx.progress('Building table...', actual: 1, total: 3);

      // Match Shiny column names: PC1..PCn = scores, X1..Xn = loadings
      final scoreNames = List.generate(nc, (k) => 'PC${k + 1}');
      final loadingNames = List.generate(nc, (k) => 'X${k + 1}');
      final nsMap = await ctx.addNamespace([...scoreNames, ...loadingNames]);

      final table = Table();
      table.nRows = nRows;

      // System columns (no namespace)
      table.columns.add(AbstractOperatorContext.makeInt32Column('.ci', outCi));
      table.columns.add(AbstractOperatorContext.makeInt32Column('.ri', outRi));

      // Score columns: PC1..PCn (observation projections)
      for (int k = 0; k < nc; k++) {
        final name = nsMap['PC${k + 1}'] ?? 'PC${k + 1}';
        table.columns.add(
            AbstractOperatorContext.makeFloat64Column(name, outScore[k]));
      }

      // Loading columns: X1..Xn (variable contributions)
      for (int k = 0; k < nc; k++) {
        final name = nsMap['X${k + 1}'] ?? 'X${k + 1}';
        table.columns.add(
            AbstractOperatorContext.makeFloat64Column(name, outLoading[k]));
      }

      // Diagnostic: dump table structure
      print('PCA Explorer: task type=${ctx.task?.runtimeType}, '
          'id=${ctx.task?.id}, '
          'isComputationTask=${ctx.task is ComputationTask}');
      print('PCA Explorer: saving table with $nRows rows, '
          '${table.columns.length} columns');
      for (final col in table.columns) {
        print('  col: ${col.name} type=${col.type} nRows=${col.nRows} '
            'values=${col.values?.runtimeType} cValues=${col.cValues.runtimeType}');
      }

      await ctx.progress('Uploading...', actual: 2, total: 3);
      await ctx.saveTable(table);
      await ctx.progress('Done', actual: 3, total: 3);
      print('PCA Explorer: save completed, '
          'task state=${ctx.task?.state?.runtimeType}');
    } catch (e) {
      print('PCA Explorer: Tercen save error: $e');
      await _printDiagnosticReport();
      rethrow;
    }
  }

  // --- Helpers ---

  Map<int, Map<String, dynamic>> _buildIndexMap(Table table) {
    final result = <int, Map<String, dynamic>>{};
    for (final col in table.columns) {
      final values = col.values as List?;
      if (values == null) continue;
      for (int i = 0; i < values.length; i++) {
        result.putIfAbsent(i, () => {});
        result[i]![col.name] = values[i];
      }
    }
    return result;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.parse(v.toString());
  }

  static String _stripNamespace(String name) {
    return name.contains('.') ? name.split('.').last : name;
  }

  Future<void> _printDiagnosticReport() async {
    print('=== TERCEN DIAGNOSTIC REPORT ===');
    final ctx = _ctx;
    if (ctx == null) {
      print('Context not created yet — cannot report schemas');
      print('=== END REPORT ===');
      return;
    }

    print('Task: ${ctx.taskId} (${ctx.task?.runtimeType})');

    for (final entry in {
      'schema (qtHash)': ctx.schema,
      'cschema (columnHash)': ctx.cschema,
      'rschema (rowHash)': ctx.rschema,
    }.entries) {
      print('\n--- ${entry.key} ---');
      try {
        final s = await entry.value;
        print(
            'Rows: ${s.nRows}, Columns: ${s.columns.map((c) => "${c.name}:${c.type}").join(', ')}');
      } catch (e) {
        print('ERROR: $e');
      }
    }

    try {
      final ns = await ctx.namespace;
      print('\nNamespace: $ns');
    } catch (e) {
      print('\nNamespace ERROR: $e');
    }

    print('=== END REPORT ===');
  }
}
