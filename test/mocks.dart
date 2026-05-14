import 'package:mockito/mockito.dart';
import 'package:murakabe/data/local/local_storage.dart';
import 'package:murakabe/data/repositories/reward_repository.dart';
import 'package:murakabe/data/repositories/badge_repository.dart';

class MockLocalStorage extends Mock implements LocalStorage {}

class MockRewardRepository extends Mock implements RewardRepository {}

class MockBadgeRepository extends Mock implements BadgeRepository {}
