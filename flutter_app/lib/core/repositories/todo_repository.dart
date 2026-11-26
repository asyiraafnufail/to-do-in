import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pb_client.dart';

class TodoRepository {
  const TodoRepository();

  Future<List<Map<String, dynamic>>> loadCachedTodos(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_todos_$userId');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr) as List<dynamic>;
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAndCacheTodos(String userId) async {
    final records = await pb.collection('user_todos').getFullList(
          sort: '-created',
          expand: 'source_post',
        );
    final list = records.map((r) => r.toJson()).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_todos_$userId', jsonEncode(list));
    } catch (_) {}
    return list;
  }

  Future<RecordModel> addTodo({
    required String userId,
    required String city,
    required String taskTitle,
    String? sourcePostId,
    String? notes,
    bool notify = true,
  }) async {
    final created = await pb.collection('user_todos').create(body: {
      'user': userId,
      if (sourcePostId != null && sourcePostId.isNotEmpty)
        'source_post': sourcePostId,
      'city': city,
      'task_title': taskTitle,
      if (notes != null) 'notes': notes,
      'is_completed': false,
    });
    if (notify) {
      todoRefreshNotifier.value++;
    }
    return created;
  }

  Future<void> updateNote(String todoId, String notes) async {
    await pb.collection('user_todos').update(todoId, body: {'notes': notes});
  }

  Future<void> setCompleted(String todoId, bool isCompleted) async {
    await pb
        .collection('user_todos')
        .update(todoId, body: {'is_completed': isCompleted});
  }

  Future<void> deleteTodo(String todoId) async {
    await pb.collection('user_todos').delete(todoId);
  }
}

const todoRepo = TodoRepository();
