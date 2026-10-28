/// AccountRepository and CategoryRepository Drift implementations.
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/services/service_contracts.dart';
import '../database/app_database.dart';
import '../database/tables.dart';

// ─── AccountRepository ────────────────────────────────────────────────────────

class DriftAccountRepository implements AccountRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DriftAccountRepository(this._db);

  Account _rowToAccount(AccountsTableData row) => Account(
        id: row.id,
        nickname: row.nickname,
        type: AccountType.values.firstWhere(
          (e) => e.name == row.type,
          orElse: () => AccountType.other,
        ),
        maskedIdentifier: row.maskedIdentifier,
        isActive: row.isActive,
        createdAt: row.createdAt,
      );

  @override
  Future<List<Account>> listAccounts() async {
    final rows = await (_db.select(_db.accountsTable)
          ..where((t) => t.isActive.equals(true)))
        .get();
    return rows.map(_rowToAccount).toList();
  }

  @override
  Future<Account?> getAccount(String id) async {
    final row = await (_db.select(_db.accountsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _rowToAccount(row);
  }

  @override
  Future<Result<Account>> addAccount(AccountInput input) async {
    final err = input.validate();
    if (err != null) return Failure(AppError(AppErrorKind.validation, err));
    final id = _uuid.v4();
    final now = DateTime.now();
    try {
      await _db.into(_db.accountsTable).insert(
            AccountsTableCompanion.insert(
              id: id,
              nickname: input.nickname.trim(),
              type: input.type.name,
              maskedIdentifier: Value(input.maskedIdentifier),
              createdAt: now,
            ),
          );
      final created = await getAccount(id);
      return Success(created!);
    } catch (_) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not save account'));
    }
  }

  @override
  Future<Result<Account>> updateAccount(String id, AccountInput changes) async {
    final err = changes.validate();
    if (err != null) return Failure(AppError(AppErrorKind.validation, err));
    try {
      await (_db.update(_db.accountsTable)..where((t) => t.id.equals(id)))
          .write(AccountsTableCompanion(
        nickname: Value(changes.nickname.trim()),
        type: Value(changes.type.name),
        maskedIdentifier: Value(changes.maskedIdentifier),
      ));
      return Success((await getAccount(id))!);
    } catch (_) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not update account'));
    }
  }

  @override
  Future<Result<void>> archiveAccount(String id) async {
    try {
      await (_db.update(_db.accountsTable)..where((t) => t.id.equals(id)))
          .write(const AccountsTableCompanion(isActive: Value(false)));
      return const Success(null);
    } catch (_) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not archive account'));
    }
  }

  @override
  Stream<List<Account>> watchAccounts() {
    return (_db.select(_db.accountsTable)
          ..where((t) => t.isActive.equals(true)))
        .watch()
        .map((rows) => rows.map(_rowToAccount).toList());
  }
}

// ─── CategoryRepository ───────────────────────────────────────────────────────

class DriftCategoryRepository implements CategoryRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DriftCategoryRepository(this._db);

  Category _rowToCategory(CategoriesTableData row) => Category(
        id: row.id,
        name: row.name,
        iconKey: row.iconKey,
        colorHex: row.colorHex,
        isArchived: row.isArchived,
        isSystem: row.isSystem,
      );

  @override
  Future<List<Category>> listCategories() async {
    final rows = await (_db.select(_db.categoriesTable)
          ..where((t) => t.isArchived.equals(false)))
        .get();
    return rows.map(_rowToCategory).toList();
  }

  @override
  Future<Result<Category>> createCategory(CategoryInput input) async {
    final err = input.validate();
    if (err != null) return Failure(AppError(AppErrorKind.validation, err));
    final id = _uuid.v4();
    try {
      await _db.into(_db.categoriesTable).insert(
            CategoriesTableCompanion.insert(
              id: id,
              name: input.name.trim(),
              iconKey: input.iconKey,
              colorHex: input.colorHex,
            ),
          );
      final all = await listCategories();
      return Success(all.firstWhere((c) => c.id == id));
    } catch (_) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not save category'));
    }
  }

  @override
  Future<Result<Category>> updateCategory(String id, CategoryInput changes) async {
    final err = changes.validate();
    if (err != null) return Failure(AppError(AppErrorKind.validation, err));
    try {
      await (_db.update(_db.categoriesTable)..where((t) => t.id.equals(id)))
          .write(CategoriesTableCompanion(
        name: Value(changes.name.trim()),
        iconKey: Value(changes.iconKey),
        colorHex: Value(changes.colorHex),
      ));
      final all = await listCategories();
      return Success(all.firstWhere((c) => c.id == id));
    } catch (_) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not update category'));
    }
  }

  @override
  Future<Result<void>> archiveCategory(String id) async {
    // System categories cannot be archived
    final existing = await (_db.select(_db.categoriesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) {
      return Failure(AppError(AppErrorKind.notFound, 'Category not found'));
    }
    if (existing.isSystem) {
      return Failure(AppError(
        AppErrorKind.unsupportedOperation,
        'System categories cannot be deleted',
      ));
    }
    try {
      await (_db.update(_db.categoriesTable)..where((t) => t.id.equals(id)))
          .write(const CategoriesTableCompanion(isArchived: Value(true)));
      return const Success(null);
    } catch (_) {
      return Failure(AppError(AppErrorKind.persistence, 'Could not archive category'));
    }
  }

  @override
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categoriesTable)
          ..where((t) => t.isArchived.equals(false)))
        .watch()
        .map((rows) => rows.map(_rowToCategory).toList());
  }
}

