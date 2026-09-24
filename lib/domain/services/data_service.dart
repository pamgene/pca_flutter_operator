import '../models/pca_data.dart';

abstract class DataService {
  Future<PcaData> loadData({bool scale = false});
  Future<void> saveResults(PcaData data);
}
