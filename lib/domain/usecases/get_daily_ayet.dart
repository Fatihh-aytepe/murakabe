import '../../data/models/ayet_model.dart';
import '../../data/repositories/content_repository.dart';

class GetDailyAyet {
  final ContentRepository _contentRepo;

  GetDailyAyet(this._contentRepo);

  Future<AyetModel> call() => _contentRepo.getTodayAyet();
}
