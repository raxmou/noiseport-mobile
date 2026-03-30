import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/noiseport_models.dart';
import '../models/jellyfin_models.dart';
import 'get_internal_song_dir.dart';

class NoiseportSettingsHelper {
  static ValueListenable<Box<NoiseportSettings>> get noiseportSettingsListener =>
      Hive.box<NoiseportSettings>("NoiseportSettings")
          .listenable(keys: ["NoiseportSettings"]);

  // This shouldn't be null as NoiseportSettings is created on startup.
  // This decision will probably come back to haunt me later.
  static NoiseportSettings get noiseportSettings =>
      Hive.box<NoiseportSettings>("NoiseportSettings").get("NoiseportSettings")!;

  /// Deletes the downloadLocation at the given index.
  static void deleteDownloadLocation(String id) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.downloadLocationsMap.remove(id);
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  /// Add a new download location to NoiseportSettings
  static void addDownloadLocation(DownloadLocation downloadLocation) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.downloadLocationsMap[downloadLocation.id] =
        downloadLocation;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static Future<DownloadLocation> resetDefaultDownloadLocation() async {
    final newInternalSongDir = await getInternalSongDir();

    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    final internalSongDownloadLocation = noiseportSettingsTemp.internalSongDir;

    internalSongDownloadLocation.path = newInternalSongDir.path;
    noiseportSettingsTemp.downloadLocationsMap[internalSongDownloadLocation.id] =
        internalSongDownloadLocation;

    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);

    return internalSongDownloadLocation;
  }

  /// Set the isOffline property
  static void setIsOffline(bool isOffline) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.isOffline = isOffline;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  /// Set the shouldTranscode property
  static void setShouldTranscode(bool shouldTranscode) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.shouldTranscode = shouldTranscode;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setTranscodeBitrate(int transcodeBitrate) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.transcodeBitrate = transcodeBitrate;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setShowTab(TabContentType tabContentType, bool value) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.showTabs[tabContentType] = value;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setIsFavourite(bool isFavourite) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.isFavourite = isFavourite;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setSortBy(TabContentType tabType, SortBy sortBy) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.tabSortBy[tabType] = sortBy;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setSortOrder(TabContentType tabType, SortOrder sortOrder) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.tabSortOrder[tabType] = sortOrder;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setAndroidStopForegroundOnPause(
      bool androidStopForegroundOnPause) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.androidStopForegroundOnPause =
        androidStopForegroundOnPause;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setSongShuffleItemCount(int songShuffleItemCount) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.songShuffleItemCount = songShuffleItemCount;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setContentGridViewCrossAxisCountPortrait(
      int contentGridViewCrossAxisCountPortrait) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.contentGridViewCrossAxisCountPortrait =
        contentGridViewCrossAxisCountPortrait;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setContentGridViewCrossAxisCountLandscape(
      int contentGridViewCrossAxisCountLandscape) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.contentGridViewCrossAxisCountLandscape =
        contentGridViewCrossAxisCountLandscape;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setContentViewType(ContentViewType contentViewType) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.contentViewType = contentViewType;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setShowTextOnGridView(bool showTextOnGridView) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.showTextOnGridView = showTextOnGridView;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setSleepTimerSeconds(int sleepTimerSeconds) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.sleepTimerSeconds = sleepTimerSeconds;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void overwriteNoiseportSettings(NoiseportSettings newNoiseportSettings) {
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", newNoiseportSettings);
  }

  static void setShowCoverAsPlayerBackground(bool showCoverAsPlayerBackground) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.showCoverAsPlayerBackground =
        showCoverAsPlayerBackground;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setHideSongArtistsIfSameAsAlbumArtists(
      bool hideSongArtistsIfSameAsAlbumArtists) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.hideSongArtistsIfSameAsAlbumArtists =
        hideSongArtistsIfSameAsAlbumArtists;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setDisableGesture(bool disableGesture) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.disableGesture = disableGesture;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setShowFastScroller(bool showFastScroller) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.showFastScroller = showFastScroller;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setBufferDuration(Duration bufferDuration) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.bufferDuration = bufferDuration;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setHasCompletedBlurhashImageMigration(
      bool hasCompletedBlurhashImageMigration) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.hasCompletedBlurhashImageMigration =
        hasCompletedBlurhashImageMigration;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setHasCompletedBlurhashImageMigrationIdFix(
      bool hasCompletedBlurhashImageMigrationIdFix) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.hasCompletedBlurhashImageMigrationIdFix =
        hasCompletedBlurhashImageMigrationIdFix;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setHasCompletedDiscoverTabMigration(
      bool hasCompletedDiscoverTabMigration) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.hasCompletedDiscoverTabMigration =
        hasCompletedDiscoverTabMigration;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setTabOrder(int index, TabContentType tabContentType) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.tabOrder[index] = tabContentType;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void resetTabs() {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.tabOrder = TabContentType.values;
    noiseportSettingsTemp.showTabs = Map.fromEntries(
      TabContentType.values.map(
        (e) => MapEntry(e, true),
      ),
    );
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setSwipeInsertQueueNext(bool swipeInsertQueueNext) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.swipeInsertQueueNext = swipeInsertQueueNext;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setSlskdHost(String host) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.slskdHost = host;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setSlskdUsername(String username) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.slskdUsername = username;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setSlskdPassword(String password) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.slskdPassword = password;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setNoiseportServerIp(String serverIp) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.noiseportServerIp = serverIp;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setMpdEnabled(bool enabled) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.mpdEnabled = enabled;
    if (!enabled) {
      noiseportSettingsTemp.isMpdMode = false;
    }
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setMpdHost(String host) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.mpdHost = host;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setMpdPort(int port) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.mpdPort = port;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setMpdPassword(String password) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.mpdPassword = password;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }

  static void setIsMpdMode(bool isMpdMode) {
    NoiseportSettings noiseportSettingsTemp = noiseportSettings;
    noiseportSettingsTemp.isMpdMode = isMpdMode;
    Hive.box<NoiseportSettings>("NoiseportSettings")
        .put("NoiseportSettings", noiseportSettingsTemp);
  }
}
