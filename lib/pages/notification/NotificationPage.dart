import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ff_annotation_route/ff_annotation_route.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:extended_tabs/extended_tabs.dart';

import 'package:OpenJMU/constants/Constants.dart';

@FFRoute(
  name: "openjmu://notifications",
  routeName: "通知页",
)
class NotificationPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => NotificationPageState();
}

class NotificationPageState extends State<NotificationPage>
    with TickerProviderStateMixin {
  final List<IconData> actionsIcons = [
    Platform.isAndroid
        ? Ionicons.getIconData("md-at")
        : Ionicons.getIconData("ios-at"),
    Platform.isAndroid ? Icons.comment : Foundation.getIconData("comment"),
    Platform.isAndroid ? Icons.thumb_up : Ionicons.getIconData("ios-thumbs-up")
  ];

  TabController _tabController, _mentionTabController;

  PostList _mentionPost;
  CommentList _mentionComment;
  CommentList _replyComment;
  PraiseList _praiseList;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    _mentionTabController = TabController(length: 2, vsync: this);

    postByMention();
    commentByMention();
    commentByReply();
    praiseList();

    super.initState();
  }

  List<Widget> actions() {
    return [
      SizedBox(
        width: suSetWidth(220.0),
        child: Consumer<NotificationProvider>(
          builder: (_, provider, __) => TabBar(
            indicatorColor: ThemeUtils.currentThemeColor,
            indicatorPadding: const EdgeInsets.only(bottom: 18.0),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 6.0,
            labelPadding: EdgeInsets.symmetric(
              horizontal: suSetWidth(10.0),
            ),
            tabs: [
              Tab(
                child: provider.notification.at != 0
                    ? IconButton(
                        icon: Constants.badgeIcon(
                          content: provider.notification.at == 0
                              ? ""
                              : provider.notification.at,
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
                child: provider.notification.comment != 0
                    ? IconButton(
                        icon: Constants.badgeIcon(
                          content: provider.notification.comment == 0
                              ? ""
                              : provider.notification.comment,
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
                child: provider.notification.praise != 0
                    ? IconButton(
                        icon: Constants.badgeIcon(
                          content: provider.notification.praise == 0
                              ? ""
                              : provider.notification.praise,
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
            controller: _tabController,
          ),
        ),
      )
    ];
  }

  Icon getActionIcon(int curIndex) => Icon(actionsIcons[curIndex]);

  void postByMention() {
    _mentionPost = PostList(
      PostController(
        postType: "mention",
        isFollowed: false,
        isMore: false,
        lastValue: (int id) => id,
      ),
      needRefreshIndicator: true,
    );
  }

  void commentByMention() {
    _mentionComment = CommentList(
      CommentController(
        commentType: "mention",
        isMore: false,
        lastValue: (int id) => id,
      ),
      needRefreshIndicator: true,
    );
  }

  void commentByReply() {
    _replyComment = CommentList(
      CommentController(
        commentType: "reply",
        isMore: false,
        lastValue: (int id) => id,
      ),
      needRefreshIndicator: true,
    );
  }

  void praiseList() {
    _praiseList = PraiseList(
      PraiseController(
        isMore: false,
        lastValue: (Praise praise) => praise.id,
      ),
      needRefreshIndicator: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: actions(),
      ),
      body: ExtendedTabBarView(
        cacheExtent: 2,
        controller: _tabController,
        children: <Widget>[
          Column(
            children: <Widget>[
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: suSetSp(42.0),
                child: TabBar(
                  indicatorColor: ThemeUtils.currentThemeColor,
                  indicatorPadding: EdgeInsets.only(
                    bottom: suSetSp(6.0),
                  ),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: suSetSp(4.0),
                  labelStyle: TextStyle(
                    fontSize: suSetSp(17.0),
                  ),
                  tabs: <Tab>[
                    Tab(text: "@我的评论"),
                    Tab(text: "@我的动态"),
                  ],
                  controller: _mentionTabController,
                ),
              ),
              Expanded(
                child: ExtendedTabBarView(
                  cacheExtent: 1,
                  controller: _mentionTabController,
                  children: <Widget>[
                    _mentionComment,
                    _mentionPost,
                  ],
                ),
              ),
            ],
          ),
          _replyComment,
          _praiseList,
        ],
      ),
    );
  }
}
