import 'package:drift_todo/data/db/app_database.dart';
import 'package:drift_todo/data/db/json_backup.dart';
import 'package:drift_todo/data/db/tables.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

enum SortField { date, priority }

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final db = AppDatabase();
  late final backup = JsonBackup(db);

  SortField sortField = SortField.priority;
  bool desc = true;

  bool useWatch = true;
  int getRefreshKey = 0;

  @override
  void dispose() {
    db.close();
    super.dispose();
  }

  void toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> addOrEditTaskDialog({Task? task}) async {
    final titleCtrl = TextEditingController(text: task?.title ?? '');
    final descCtrl = TextEditingController(text: task?.description ?? '');
    int priority = task?.priority ?? 3;
    bool completed = task?.completed ?? false;

    final allTags = await db.getAllTags();
    final selectedTagIds = <int>{};
    if (task != null) {
      final current = await db.getTagsForTask(task.id);
      selectedTagIds.addAll(current.map((e) => e.id));
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(task == null ? 'Add Task' : 'Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Priority: '),
                  DropdownButton<int>(
                    value: priority,
                    items: [1, 2, 3, 4, 5]
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text('$p'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => priority = v ?? priority),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Text('Done'),
                      Checkbox(
                        value: completed,
                        onChanged: (v) {
                          completed = v ?? completed;
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (allTags.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tags:'),
                ),
                Wrap(
                  spacing: 8,
                  children: allTags.map((tag) {
                    final selected = selectedTagIds.contains(tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: selected,
                      onSelected: (v) {
                        if (v) {
                          selectedTagIds.add(tag.id);
                        } else {
                          selectedTagIds.remove(tag.id);
                        }
                        (ctx as Element).markNeedsBuild();
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      toast('Title empty');
      return;
    }

    if (task == null) {
      final id = await db.addTask(
        title: title,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        priority: priority,
      );
      await db.updateTask(id: id, completed: completed);

      for (final tagId in selectedTagIds) {
        await db.attachTagToTask(taskId: id, tagId: tagId);
      }
    } else {
      await db.updateTask(
        id: task.id,
        title: title,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        priority: priority,
        completed: completed,
      );

      final current = await db.getTagsForTask(task.id);
      final currentIds = current.map((e) => e.id).toSet();

      final toAdd = selectedTagIds.difference(currentIds);
      final toRemove = currentIds.difference(selectedTagIds);

      for (final tagId in toAdd) {
        await db.attachTagToTask(taskId: task.id, tagId: tagId);
      }
      for (final tagId in toRemove) {
        await db.detachTagFromTask(taskId: task.id, tagId: tagId);
      }
    }

    if (!useWatch) setState(() => getRefreshKey++);
  }

  Future<void> tagsManagerDialog() async {
    final nameCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tags'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'New tag'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      await db.addTag(name);
                      nameCtrl.clear();
                      (ctx as Element).markNeedsBuild();
                    },
                    child: const Text('Add'),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: StreamBuilder(
                  stream: db.watchAllTags(),
                  builder: (context, snap) {
                    final list = snap.data ?? const <Tag>[];
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (list.isEmpty) return const Text('No tags');
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final t = list[i];
                        return ListTile(
                          title: Text(t.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await db.deleteTag(t.id);
                              if (!useWatch) setState(() => getRefreshKey++);
                            },
                          ),
                          onTap: () async {
                            final editCtrl = TextEditingController(text: t.name);
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c2) => AlertDialog(
                                title: const Text('Edit tag'),
                                content: TextField(controller: editCtrl),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(c2, true), child: const Text('Save')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final newName = editCtrl.text.trim();
                              if (newName.isNotEmpty) {
                                await db.updateTag(id: t.id, name: newName);
                                if (!useWatch) setState(() => getRefreshKey++);
                              }
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  bool get sortByPriority => sortField == SortField.priority;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Drift HW (Tasks + Tags)'),
          actions: [
            IconButton(
              tooltip: 'Tags',
              icon: const Icon(Icons.label),
              onPressed: tagsManagerDialog,
            ),
            IconButton(
              tooltip: 'Export JSON',
              icon: const Icon(Icons.upload_file),
              onPressed: () async {
                await backup.exportToJson();
                toast('Exported to backup.json');
              },
            ),
            IconButton(
              tooltip: 'Import JSON',
              icon: const Icon(Icons.download),
              onPressed: () async {
                await backup.importFromJson();
                toast('Imported from backup.json');
                if (!useWatch) setState(() => getRefreshKey++);
              },
            ),
            IconButton(
              tooltip: 'Wipe all',
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                await db.wipeAll();
                toast('All cleared');
                if (!useWatch) setState(() => getRefreshKey++);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => addOrEditTaskDialog(),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // Controls
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('Sort: '),
                  DropdownButton<SortField>(
                    value: sortField,
                    items: const [
                      DropdownMenuItem(
                        value: SortField.priority,
                        child: Text('Priority'),
                      ),
                      DropdownMenuItem(
                        value: SortField.date,
                        child: Text('Date'),
                      ),
                    ],
                    onChanged: (v) => setState(() => sortField = v ?? sortField),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: desc ? 'DESC' : 'ASC',
                    icon: Icon(desc ? Icons.south : Icons.north),
                    onPressed: () => setState(() => desc = !desc),
                  ),
                  const Spacer(),
                  const Text('watch()'),
                  Switch(
                    value: useWatch,
                    onChanged: (v) => setState(() {
                      useWatch = v;
                      if (!useWatch) getRefreshKey++;
                    }),
                  ),
                  const Text('get()'),
                  if (!useWatch)
                    IconButton(
                      tooltip: 'Refresh get()',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() => getRefreshKey++),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: useWatch
                  ? StreamBuilder<List<Task>>(
                      stream: db.watchTasksSorted(
                        sortByPriority: sortByPriority,
                        desc: desc,
                      ),
                      builder: (context, snap) {
                        final list = snap.data ?? const <Task>[];
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return _TasksList(
                          list: list,
                          db: db,
                          onEdit: (t) => addOrEditTaskDialog(task: t),
                          onChangedForGet: () {},
                        );
                      },
                    )
                  : FutureBuilder<List<Task>>(
                      key: ValueKey(getRefreshKey),
                      future: db.getTasksSorted(
                        sortByPriority: sortByPriority,
                        desc: desc,
                      ),
                      builder: (context, snap) {
                        final list = snap.data ?? const <Task>[];
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return _TasksList(
                          list: list,
                          db: db,
                          onEdit: (t) => addOrEditTaskDialog(task: t),
                          onChangedForGet: () => setState(() => getRefreshKey++),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksList extends StatelessWidget {
  final List<Task> list;
  final AppDatabase db;
  final void Function(Task t) onEdit;
  final VoidCallback onChangedForGet;

  const _TasksList({
    required this.list,
    required this.db,
    required this.onEdit,
    required this.onChangedForGet,
  });

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const Center(child: Text('Empty'));

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final t = list[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              title: Row(
                children: [
                  Checkbox(
                    value: t.completed,
                    onChanged: (v) async {
                      await db.updateTask(id: t.id, completed: v ?? false);
                      onChangedForGet();
                    },
                  ),
                  Expanded(
                    child: Text(
                      t.title,
                      style: TextStyle(
                        decoration: t.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((t.description ?? '').isNotEmpty) Text(t.description!),
                  const SizedBox(height: 6),
                  Text('priority=${t.priority} | createdAt=${t.createdAt}'),
                  const SizedBox(height: 6),
                  StreamBuilder<List<Tag>>(
                    stream: db.watchTagsForTask(t.id),
                    builder: (context, snap) {
                      final tags = snap.data ?? const <Tag>[];
                      if (tags.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        spacing: 6,
                        children: tags.map((tag) => Chip(label: Text(tag.name))).toList(),
                      );
                    },
                  ),
                ],
              ),
              onTap: () => onEdit(t),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await db.deleteTask(t.id);
                  onChangedForGet();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
