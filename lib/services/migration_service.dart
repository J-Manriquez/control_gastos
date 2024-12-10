import 'package:control_gastos/migrations/migrations_manager.dart';
import 'package:control_gastos/utils/custom_logger.dart';

class MigrationService {
  final MigrationsManager _migrationsManager = MigrationsManager();
  final CustomLogger _logger = CustomLogger();

  Future<void> migrateUserIfNeeded(String uid) async {
    try {
      await _migrationsManager.runMigrations(uid);
    } catch (e) {
      _logger.logError('Error durante la migración del usuario: $e');
      throw Exception('Error durante la migración: $e');
    }
  }
}