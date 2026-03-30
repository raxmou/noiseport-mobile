import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../models/jellyfin_models.dart';
import '../../services/noiseport_user_helper.dart';
import '../view_icon.dart';

class ViewListTile extends StatelessWidget {
  const ViewListTile({Key? key, required this.view}) : super(key: key);

  final BaseItemDto view;

  @override
  Widget build(BuildContext context) {
    final noiseportUserHelper = GetIt.instance<NoiseportUserHelper>();

    return ListTile(
      leading: ViewIcon(
        collectionType: view.collectionType,
        color: noiseportUserHelper.currentUser!.currentViewId == view.id
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      title: Text(
        view.name ?? "Unknown Name",
        style: TextStyle(
          color: noiseportUserHelper.currentUser!.currentViewId == view.id
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      ),
      onTap: () => noiseportUserHelper.setCurrentUserCurrentViewId(view.id),
    );
  }
}