import 'package:flutter/material.dart';
import 'package:noiseport/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

import '../models/noiseport_models.dart';
import '../services/noiseport_settings_helper.dart';
import '../services/audio_service_helper.dart';
import '../services/noiseport_user_helper.dart';
import '../components/MusicScreen/music_screen_tab_view.dart';
import '../components/MusicScreen/music_screen_drawer.dart';
import '../components/MusicScreen/sort_by_menu_button.dart';
import '../components/MusicScreen/sort_order_button.dart';
import '../components/now_playing_bar.dart';
import '../components/error_snackbar.dart';
import '../services/jellyfin_api_helper.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({Key? key}) : super(key: key);

  static const routeName = "/music";

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with TickerProviderStateMixin {
  bool isSearching = false;
  bool _showShuffleFab = false;
  TextEditingController textEditingController = TextEditingController();
  String? searchQuery;
  final _musicScreenLogger = Logger("MusicScreen");

  TabController? _tabController;

  final _audioServiceHelper = GetIt.instance<AudioServiceHelper>();
  final _noiseportUserHelper = GetIt.instance<NoiseportUserHelper>();
  final _jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

  void _stopSearching() {
    setState(() {
      textEditingController.clear();
      searchQuery = null;
      isSearching = false;
    });
  }

  void _tabIndexCallback() {
    var tabKey = NoiseportSettingsHelper.noiseportSettings.showTabs.entries
        .where((element) => element.value)
        .elementAt(_tabController!.index)
        .key;
    if (_tabController != null &&
        (tabKey == TabContentType.songs ||
            tabKey == TabContentType.artists ||
            tabKey == TabContentType.albums)) {
      setState(() {
        _showShuffleFab = true;
      });
    } else {
      if (_showShuffleFab) {
        setState(() {
          _showShuffleFab = false;
        });
      }
    }
  }

  void _buildTabController() {
    _tabController?.removeListener(_tabIndexCallback);

    _tabController = TabController(
      length: NoiseportSettingsHelper.noiseportSettings.showTabs.entries
          .where((element) => element.value)
          .length,
      vsync: this,
    );

    _tabController!.addListener(_tabIndexCallback);
  }

  @override
  void initState() {
    super.initState();
    _buildTabController();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  FloatingActionButton? getFloatingActionButton() {
    var tabList = NoiseportSettingsHelper.noiseportSettings.showTabs.entries
        .where((element) => element.value)
        .map((e) => e.key)
        .toList();

    // Show the floating action button only on the albums, artists and songs tab.
    if (_tabController!.index == tabList.indexOf(TabContentType.songs)) {
      return FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.shuffleAll,
        onPressed: () async {
          try {
            await _audioServiceHelper
                .shuffleAll(NoiseportSettingsHelper.noiseportSettings.isFavourite);
          } catch (e) {
            errorSnackbar(e, context);
          }
        },
        child: const Icon(Icons.shuffle),
      );
    } else if (_tabController!.index ==
        tabList.indexOf(TabContentType.artists)) {
      return FloatingActionButton(
          tooltip: AppLocalizations.of(context)!.startMix,
          onPressed: () async {
            try {
              if (_jellyfinApiHelper.selectedMixArtistsIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.startMixNoSongsArtist)));
              } else {
                await _audioServiceHelper.startInstantMixForArtists(
                    _jellyfinApiHelper.selectedMixArtistsIds);
              }
            } catch (e) {
              errorSnackbar(e, context);
            }
          },
          child: const Icon(Icons.explore));
    } else if (_tabController!.index ==
        tabList.indexOf(TabContentType.albums)) {
      return FloatingActionButton(
          tooltip: AppLocalizations.of(context)!.startMix,
          onPressed: () async {
            try {
              if (_jellyfinApiHelper.selectedMixAlbumIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.startMixNoSongsAlbum)));
              } else {
                await _audioServiceHelper.startInstantMixForAlbums(
                    _jellyfinApiHelper.selectedMixAlbumIds);
              }
            } catch (e) {
              errorSnackbar(e, context);
            }
          },
          child: const Icon(Icons.explore));
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<NoiseportUser>>(
      valueListenable: _noiseportUserHelper.noiseportUsersListenable,
      builder: (context, value, _) {
        return ValueListenableBuilder<Box<NoiseportSettings>>(
          valueListenable: NoiseportSettingsHelper.noiseportSettingsListener,
          builder: (context, value, _) {
            final noiseportSettings = value.get("NoiseportSettings");

            // Get the tabs from the user's tab order, and filter them to only
            // include enabled tabs
            final tabs = noiseportSettings!.tabOrder.where((e) =>
                NoiseportSettingsHelper.noiseportSettings.showTabs[e] ?? false);

            if (tabs.length != _tabController?.length) {
              _musicScreenLogger.info(
                  "Rebuilding MusicScreen tab controller (${tabs.length} != ${_tabController?.length})");
              _buildTabController();
            }

            return WillPopScope(
              onWillPop: () async {
                if (isSearching) {
                  _stopSearching();
                  return false;
                }
                return true;
              },
              child: Scaffold(
                appBar: AppBar(
                  title: isSearching
                      ? TextField(
                          controller: textEditingController,
                          autofocus: true,
                          onChanged: (value) => setState(() {
                            searchQuery = value;
                          }),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: MaterialLocalizations.of(context)
                                .searchFieldLabel,
                          ),
                        )
                      : Text(_noiseportUserHelper.currentUser?.currentView?.name ??
                          AppLocalizations.of(context)!.music),
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: tabs
                        .map((tabType) => Tab(
                              text: tabType
                                  .toLocalisedString(context)
                                  .toUpperCase(),
                            ))
                        .toList(),
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                  ),
                  leading: isSearching
                      ? BackButton(
                          onPressed: () => _stopSearching(),
                        )
                      : null,
                  actions: isSearching
                      ? [
                          IconButton(
                            icon: Icon(
                              Icons.cancel,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () => setState(() {
                              textEditingController.clear();
                              searchQuery = null;
                            }),
                            tooltip: AppLocalizations.of(context)!.clear,
                          )
                        ]
                      : [
                          SortOrderButton(
                            tabs.elementAt(_tabController!.index),
                          ),
                          SortByMenuButton(
                            tabs.elementAt(_tabController!.index),
                          ),
                          IconButton(
                            icon: noiseportSettings.isFavourite
                                ? const Icon(Icons.favorite)
                                : const Icon(Icons.favorite_outline),
                            onPressed: noiseportSettings.isOffline
                                ? null
                                : () => NoiseportSettingsHelper.setIsFavourite(
                                    !noiseportSettings.isFavourite),
                            tooltip: AppLocalizations.of(context)!.favourites,
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () => setState(() {
                              isSearching = true;
                            }),
                            tooltip: MaterialLocalizations.of(context)
                                .searchFieldLabel,
                          ),
                        ],
                ),
                bottomNavigationBar: const NowPlayingBar(),
                drawer: const MusicScreenDrawer(),
                floatingActionButton: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: getFloatingActionButton(),
                ),
                body: TabBarView(
                  controller: _tabController,
                  children: tabs
                      .map((tabType) => MusicScreenTabView(
                            tabContentType: tabType,
                            searchTerm: searchQuery,
                            isFavourite: noiseportSettings.isFavourite,
                            sortBy: noiseportSettings.getTabSortBy(tabType),
                            sortOrder: noiseportSettings.getSortOrder(tabType),
                            view: _noiseportUserHelper.currentUser?.currentView,
                          ))
                      .toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}