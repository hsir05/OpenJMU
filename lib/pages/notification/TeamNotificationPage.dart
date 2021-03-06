///
/// [Author] Alex (https://github.com/AlexVincent525)
/// [Date] 2019-11-23 06:50
///
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ff_annotation_route/ff_annotation_route.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:extended_tabs/extended_tabs.dart';

import 'package:OpenJMU/constants/Constants.dart';
import 'package:OpenJMU/pages/post/TeamMentionListPage.dart';
import 'package:OpenJMU/pages/post/TeamReplyListPage.dart';
import 'package:OpenJMU/pages/post/TeamPraiseListPage.dart';

@FFRoute(
  name: "openjmu://team-notifications",
  routeName: "小组通知页",
)
class TeamNotificationPage extends StatefulWidget {
  @override
  _TeamNotificationPageState createState() => _TeamNotificationPageState();
}

class _TeamNotificationPageState extends State<TeamNotificationPage>
    with TickerProviderStateMixin {
  final List<IconData> actionsIcons = [
    Platform.isAndroid
        ? Ionicons.getIconData("md-at")
        : Ionicons.getIconData("ios-at"),
    Platform.isAndroid ? Icons.comment : Foundation.getIconData("comment"),
    Platform.isAndroid ? Icons.thumb_up : Ionicons.getIconData("ios-thumbs-up"),
  ];

  NotificationProvider provider;
  TabController _tabController;

  @override
  void initState() {
    provider = Provider.of<NotificationProvider>(navigatorState.context);

    _tabController = TabController(
      initialIndex: initialIndex(),
      length: 3,
      vsync: this,
    );
    super.initState();
  }

  int initialIndex() {
    final latestNotify = provider.teamNotification.latestNotify;
    int index = 0;
    switch (latestNotify) {
      case "mention":
        index = 0;
        break;
      case "reply":
        index = 1;
        break;
      case "praise":
        index = 2;
        break;
    }
    return index;
  }

  Widget actions() {
    final notification = provider.teamNotification;
    return SizedBox(
      width: suSetWidth(220.0),
      child: Consumer<NotificationProvider>(
        builder: (_, provider, __) => TabBar(
          controller: _tabController,
          indicatorColor: ThemeUtils.currentThemeColor,
          indicatorPadding: EdgeInsets.only(bottom: 16.0),
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: suSetHeight(7.0),
          labelPadding: EdgeInsets.symmetric(
            horizontal: suSetWidth(10.0),
          ),
          tabs: [
            Tab(
              child: notification.mention != 0
                  ? IconButton(
                      icon: Constants.badgeIcon(
                        showBadge: notification.mention != 0,
                        content: notification.mention,
                        icon: Icon(
                          actionsIcons[0],
                          size: suSetSp(26.0),
                        ),
                      ),
                      onPressed: () {
                        _tabController.animateTo(0);
                        provider.readMention();
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        actionsIcons[0],
                        size: suSetSp(26.0),
                      ),
                    ),
            ),
            Tab(
              child: notification.reply != 0
                  ? IconButton(
                      icon: Constants.badgeIcon(
                        showBadge: notification.reply != 0,
                        content: notification.reply,
                        icon: Icon(
                          actionsIcons[1],
                          size: suSetSp(26.0),
                        ),
                      ),
                      onPressed: () {
                        _tabController.animateTo(1);
                        provider.readReply();
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        actionsIcons[1],
                        size: suSetSp(26.0),
                      ),
                    ),
            ),
            Tab(
              child: notification.praise != 0
                  ? IconButton(
                      icon: Constants.badgeIcon(
                        showBadge: notification.praise != 0,
                        content: notification.praise,
                        icon: Icon(
                          actionsIcons[2],
                          size: suSetSp(26.0),
                        ),
                      ),
                      onPressed: () {
                        _tabController.animateTo(2);
                        provider.readPraise();
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        actionsIcons[2],
                        size: suSetSp(26.0),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [actions()],
      ),
      body: ExtendedTabBarView(
        cacheExtent: 2,
        controller: _tabController,
        children: <Widget>[
          TeamMentionListPage(),
          TeamReplyListPage(),
          TeamPraiseListPage(),
        ],
      ),
    );
  }
}
