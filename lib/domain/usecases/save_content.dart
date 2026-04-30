import '../../data/repositories/content_repository.dart';

class SaveContent {
  final ContentRepository _contentRepo;

  SaveContent(this._contentRepo);

  Future<void> call(String type, int contentId) =>
      _contentRepo.saveContent(type, contentId);
}
