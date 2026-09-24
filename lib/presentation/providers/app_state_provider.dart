import 'dart:async';

import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/pca_data.dart';
import '../../domain/services/data_service.dart';

class AppStateProvider extends ChangeNotifier {
  final DataService _dataService;

  AppStateProvider({DataService? dataService})
      : _dataService = dataService ?? serviceLocator<DataService>();

  // --- Data loading state ---
  bool _isLoading = false;
  String? _error;
  PcaData? _data;

  bool get isLoading => _isLoading;
  String? get error => _error;
  PcaData? get data => _data;

  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _dataService.loadData(scale: _scaleSpots);
      print('PCA Explorer: AppState received data — ${_data!.scores.length} scores, fields=${_data!.annotationFields}, defaultColorBy=${_data!.defaultColorBy}');
      // Set defaults from data
      if (_data!.defaultColorBy.isNotEmpty) {
        _colorBy = _data!.defaultColorBy;
        _labelBy = _data!.defaultColorBy;
      } else if (_data!.annotationFields.isNotEmpty) {
        _colorBy = _data!.annotationFields.first;
        _labelBy = _data!.annotationFields.first;
      }
      print('PCA Explorer: AppState colorBy=$_colorBy, labelBy=$_labelBy');
      _updateColorMapping();
      unawaited(savePcaResults());
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- COMPUTE: Scale spots ---
  bool _scaleSpots = false;
  bool get scaleSpots => _scaleSpots;
  void setScaleSpots(bool value) {
    _scaleSpots = value;
    _hasSaved = false;
    loadData();
  }

  // --- VIEW: Mode (segmented button) ---
  ViewMode _viewMode = ViewMode.scores3d;
  ViewMode get viewMode => _viewMode;
  void setViewMode(ViewMode value) {
    _viewMode = value;
    notifyListeners();
  }

  // --- APPEARANCE: Color By (dropdown) ---
  String _colorBy = '';
  String get colorBy => _colorBy;
  void setColorBy(String value) {
    _colorBy = value;
    _updateColorMapping();
    notifyListeners();
  }

  // --- APPEARANCE: Label By (dropdown) ---
  String _labelBy = '';
  String get labelBy => _labelBy;
  void setLabelBy(String value) {
    _labelBy = value;
    notifyListeners();
  }

  // --- DISPLAY: Point Style (dropdown) ---
  PointStyle _pointStyle = PointStyle.labels;
  PointStyle get pointStyle => _pointStyle;
  void setPointStyle(PointStyle value) {
    _pointStyle = value;
    notifyListeners();
  }

  // --- DISPLAY: 3D Axis selection (dropdowns) ---
  String _scores3dXAxis = 'PC1';
  String _scores3dYAxis = 'PC2';
  String _scores3dZAxis = 'PC3';
  String get scores3dXAxis => _scores3dXAxis;
  String get scores3dYAxis => _scores3dYAxis;
  String get scores3dZAxis => _scores3dZAxis;
  void setScores3dXAxis(String value) {
    _scores3dXAxis = value;
    notifyListeners();
  }

  void setScores3dYAxis(String value) {
    _scores3dYAxis = value;
    notifyListeners();
  }

  void setScores3dZAxis(String value) {
    _scores3dZAxis = value;
    notifyListeners();
  }

  // --- COMPONENTS: Num Components (slider) ---
  int _numComponents = 5;
  int get numComponents => _numComponents;
  void setNumComponents(int value) {
    _numComponents = value.clamp(2, _data?.numComponents ?? 5);
    notifyListeners();
  }

  // --- BIPLOT: X Axis (dropdown) ---
  String _biplotXAxis = 'PC1';
  String get biplotXAxis => _biplotXAxis;
  void setBiplotXAxis(String value) {
    _biplotXAxis = value;
    notifyListeners();
  }

  // --- BIPLOT: Y Axis (dropdown) ---
  String _biplotYAxis = 'PC2';
  String get biplotYAxis => _biplotYAxis;
  void setBiplotYAxis(String value) {
    _biplotYAxis = value;
    notifyListeners();
  }

  // --- BIPLOT: Loading Threshold % (slider 0-100) ---
  double _loadingThreshold = 0.0;
  double get loadingThreshold => _loadingThreshold;
  void setLoadingThreshold(double value) {
    _loadingThreshold = value;
    notifyListeners();
  }

  // --- BIPLOT: Loading Zoom % (slider 1-400) ---
  double _loadingZoom = 1.0;
  double get loadingZoom => _loadingZoom;
  void setLoadingZoom(double value) {
    _loadingZoom = value;
    notifyListeners();
  }

  // --- BIPLOT: Label Font Size (slider 8-24) ---
  double _biplotLabelFontSize = 14.0;
  double get biplotLabelFontSize => _biplotLabelFontSize;
  void setBiplotLabelFontSize(double value) {
    _biplotLabelFontSize = value;
    notifyListeners();
  }

  // --- BIPLOT: Axis Padding % (slider 5-50) ---
  double _biplotAxisPadding = 20.0;
  double get biplotAxisPadding => _biplotAxisPadding;
  void setBiplotAxisPadding(double value) {
    _biplotAxisPadding = value;
    notifyListeners();
  }

  // --- 3D rotation/zoom (gesture-driven, not a panel control) ---
  double _rotationX = 0.3;
  double _rotationY = 0.5;
  double _zoom3d = 1.0;
  double get rotationX => _rotationX;
  double get rotationY => _rotationY;
  double get zoom3d => _zoom3d;
  void setRotation(double x, double y) {
    _rotationX = x;
    _rotationY = y;
    notifyListeners();
  }

  void setZoom3d(double value) {
    _zoom3d = value.clamp(0.3, 5.0);
    notifyListeners();
  }

  // --- Hover state (for tooltip) ---
  int? _hoveredPointIndex;
  Offset? _hoverPosition;
  int? get hoveredPointIndex => _hoveredPointIndex;
  Offset? get hoverPosition => _hoverPosition;
  void setHoveredPoint(int? index, Offset? position) {
    if (_hoveredPointIndex == index) return;
    _hoveredPointIndex = index;
    _hoverPosition = position;
    notifyListeners();
  }

  // --- Color mapping ---
  Map<String, Color> _colorMap = {};
  Map<String, Color> get colorMap => _colorMap;

  static const _palette = [
    Color(0xFF1E40AF), // blue
    Color(0xFFDC2626), // red
    Color(0xFF059669), // green
    Color(0xFFD97706), // amber
    Color(0xFF7C3AED), // purple
    Color(0xFFDB2777), // pink
    Color(0xFF0891B2), // cyan
    Color(0xFF65A30D), // lime
  ];

  void _updateColorMapping() {
    if (_data == null || _colorBy.isEmpty) return;
    final values = _data!.getAnnotationValues(_colorBy);
    _colorMap = {
      for (var i = 0; i < values.length; i++)
        values[i]: _palette[i % _palette.length],
    };
  }

  Color getColorForSample(int ci) {
    if (_data == null) return _palette[0];
    final value = _data!.getAnnotationForSample(ci, _colorBy);
    return _colorMap[value] ?? _palette[0];
  }

  String getLabelForSample(int ci) {
    if (_data == null) return '';
    return _data!.getAnnotationForSample(ci, _labelBy);
  }

  /// Helper: get PC index from label like "PC1" -> 0
  int pcIndex(String pcLabel) => int.parse(pcLabel.substring(2)) - 1;

  // --- EXPORT: PNG callback registered by the active view ---
  void Function(BuildContext)? _exportCallback;
  bool get canExport => _exportCallback != null;

  void registerExportCallback(void Function(BuildContext) cb) {
    _exportCallback = cb;
    notifyListeners();
  }

  void unregisterExportCallback() {
    _exportCallback = null;
    notifyListeners();
  }

  void triggerExport(BuildContext context) {
    _exportCallback?.call(context);
  }

  // --- ACTIONS: Save state ---
  bool _hasSaved = false;
  bool _isSaving = false;
  String? _saveError;
  bool get hasSaved => _hasSaved;
  bool get isSaving => _isSaving;
  String? get saveError => _saveError;

  Future<void> savePcaResults() async {
    if (_data == null || _hasSaved || _isSaving) return;
    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      await _dataService.saveResults(_data!);
      _hasSaved = true;
    } catch (e) {
      _saveError = e.toString();
      print('Save error: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
