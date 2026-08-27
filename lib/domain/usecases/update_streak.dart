import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../core/services/notification_service.dart';

/// DİKKAT — şu an UYGULAMA İÇİNDE HİÇBİR YERDEN ÇAĞRILMIYOR: "merhamet günü"
/// (mercy day) toleranslı seri (streak) sıfırlama mantığı yalnızca burada
/// tanımlı, hiçbir ekran/servis bunu çalıştırmıyor. Gerçek seri artışı hâlâ
/// UserRepository.markQuranRead içindeki basit (mercy day'siz) mantıkla
/// yapılıyor; bu yüzden kullanıcı bir gün Kur'ân okumayı atlarsa seri o an
/// SIFIRLANMIYOR (yalnızca bir sonraki okumada `1`'e düşüyor), "merhamet
/// günü" hakkı hiç işletilmiyor.
///
/// Bilerek burada OTOMATİK olarak günlük bir akışa (ör. HomeScreen açılışı)
/// bağlanmadı: bu sınıfın kendi mantığında da ayrı bir boşluk var — kullanıcı
/// BİRDEN FAZLA gün art arda okumadıysa ve `lastStreakDate` "dün" değilse,
/// `else` dalındaki iç koşul (`lastStreakDate == yesterday`) hiç
/// tetiklenmiyor ve seri yanlışlıkla KORUNUYOR (sıfırlanmıyor), üstelik
/// `lastStreakDate` yine de "bugün"e güncelleniyor — bu da bir sonraki
/// günlerde erken/geç mercy-day hesaplarını bozabilir. Bu, kullanıcıya
/// görünen seri/rozet davranışını değiştiren bir ürün kararı olduğundan,
/// geniş bir statik inceleme sırasında sessizce etkinleştirilmedi; önce bu
/// ikinci boşluk giderilmeli, sonra bilinçli olarak (ör. HomeScreen
/// initState'inde `lastStreakDate != today` ise) bağlanmalı.
class UpdateStreak {
  final UserRepository _userRepo;
  final NotificationService _notifService = NotificationService();

  UpdateStreak(this._userRepo);

  Future<UserModel?> call() async {
    final user = await _userRepo.getCurrentUser();
    if (user == null) return null;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    // Bugün zaten işlendiyse tekrar hesaplama
    if (user.lastStreakDate == today) return user;

    int newStreak = user.streakDays;
    int newMercyUsed = user.mercyDaysUsed;
    List<String> newMissed = List.from(user.missedQuranDays);

    final quranReadToday = await _userRepo.isQuranReadToday();

    if (quranReadToday) {
      // Bugün okundu — streak artır
      if (user.lastStreakDate == yesterday || user.lastStreakDate.isEmpty) {
        newStreak++;
      } else {
        // Ara verilmiş, mercy day kontrolü
        final daysDiff = _daysBetween(user.lastStreakDate, today);
        if (daysDiff <= user.allowedMercyDays + 1) {
          newMercyUsed += daysDiff - 1;
          newStreak++;
        } else {
          newStreak = 1;
          newMercyUsed = 0;
        }
      }
    } else {
      // Bugün okunmadı
      if (user.lastStreakDate == yesterday) {
        // Dün okunmuş, mercy day var mı?
        if (newMercyUsed < user.allowedMercyDays) {
          newMercyUsed++;
          // Streak koruyor, uyarı bildirimi gönder
          await _sendStreakWarning(user.streakDays);
        } else {
          // Streak sıfırla
          newStreak = 0;
          newMercyUsed = 0;
          newMissed.add(today);
        }
      }
    }

    final updatedUser = user.copyWith(
      streakDays: newStreak,
      mercyDaysUsed: newMercyUsed,
      missedQuranDays: newMissed,
      lastStreakDate: today,
    );

    await _userRepo.updateUser(updatedUser);
    return updatedUser;
  }

  int _daysBetween(String from, String to) {
    final f = DateTime.parse(from);
    final t = DateTime.parse(to);
    return t.difference(f).inDays;
  }

  Future<void> _sendStreakWarning(int currentStreak) async {
    await _notifService.showImmediateNotification(
      id: 99,
      title: '🌙 Serini Koruma Vakti!',
      body:
          'Hala vaktin var, Heybenin bereketini ve serini korumak için bugün gayret et! 🌙',
      channelId: 'streak_channel',
      channelName: 'Seri Uyarısı',
    );
  }
}
