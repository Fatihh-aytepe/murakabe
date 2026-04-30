import '../../data/models/hadis_model.dart';
import '../../data/repositories/content_repository.dart';

class GetDailyHadis {
  final ContentRepository _contentRepo;

  GetDailyHadis(this._contentRepo);

  Future<HadisModel> call() => _contentRepo.getTodayHadis();
}
