import '../../data/models/esma_model.dart';
import '../../data/repositories/content_repository.dart';

class GetDailyEsma {
  final ContentRepository _contentRepo;

  GetDailyEsma(this._contentRepo);

  Future<EsmaModel> call() => _contentRepo.getTodayEsma();
}
