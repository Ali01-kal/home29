

part of 'app_database.dart';


class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  $TasksTable(this.attachedDatabase, [this._alias]);

  @override
  String get actualTableName => 'tasks';

  @override
  VerificationContext validateIntegrity(
      Insertable<Task> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  $TagsTable(this.attachedDatabase, [this._alias]);

  @override
  String get actualTableName => 'tags';
}

class $TaskTagsTable extends TaskTags
    with TableInfo<$TaskTagsTable, TaskTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  $TaskTagsTable(this.attachedDatabase, [this._alias]);

  @override
  String get actualTableName => 'task_tags';
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);

  late final $TasksTable tasks = $TasksTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TaskTagsTable taskTags = $TaskTagsTable(this);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      [tasks, tags, taskTags];
}
