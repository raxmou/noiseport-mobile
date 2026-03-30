import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/noiseport_models.dart';
import '../models/jellyfin_models.dart';

/// Helper class for Noiseport users. Note that this class does not talk to the
/// Jellyfin server, so stuff like logging in/out is handled in JellyfinApiData.
class NoiseportUserHelper {
  final _noiseportUserBox = Hive.box<NoiseportUser>("NoiseportUsers");
  final _currentUserIdBox = Hive.box<String>("CurrentUserId");

  /// Checks if there are any saved users.
  bool get isUsersEmpty => _noiseportUserBox.isEmpty;

  /// Loads the id from CurrentUserId. Returns null if no id is stored.
  String? get currentUserId => _currentUserIdBox.get("CurrentUserId");

  /// Loads the NoiseportUser with the id from CurrentUserId. Returns null if no
  /// user exists.
  NoiseportUser? get currentUser =>
      _noiseportUserBox.get(_currentUserIdBox.get("CurrentUserId"));

  ValueListenable<Box<NoiseportUser>> get noiseportUsersListenable =>
      _noiseportUserBox.listenable();

  Iterable<NoiseportUser> get noiseportUsers => _noiseportUserBox.values;

  /// Saves a new user to the Hive box and sets the CurrentUserId.
  Future<void> saveUser(NoiseportUser newUser) async {
    await Future.wait([
      _noiseportUserBox.put(newUser.id, newUser),
      _currentUserIdBox.put("CurrentUserId", newUser.id),
    ]);
  }

  /// Sets the views of the current user
  void setCurrentUserViews(List<BaseItemDto> newViews) {
    final currentUserId = _currentUserIdBox.get("CurrentUserId");
    NoiseportUser currentUserTemp = currentUser!;

    currentUserTemp.views = Map<String, BaseItemDto>.fromEntries(
        newViews.map((e) => MapEntry(e.id, e)));
    currentUserTemp.currentViewId = currentUserTemp.views.keys.first;

    _noiseportUserBox.put(currentUserId, currentUserTemp);
  }

  void setCurrentUserCurrentViewId(String newViewId) {
    final currentUserId = _currentUserIdBox.get("CurrentUserId");
    NoiseportUser currentUserTemp = currentUser!;

    currentUserTemp.currentViewId = newViewId;

    _noiseportUserBox.put(currentUserId, currentUserTemp);
  }

  /// Removes the user with the given id. If the given id is the current user
  /// id, CurrentUserId is cleared.
  void removeUser(String id) {
    if (id == _currentUserIdBox.get("CurrentUserId")) {
      _currentUserIdBox.delete("CurrentUserId");
    }

    _noiseportUserBox.delete(id);
  }
}