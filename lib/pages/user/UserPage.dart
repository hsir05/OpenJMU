import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:ff_annotation_route/ff_annotation_route.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:OpenJMU/constants/Constants.dart';
import 'package:OpenJMU/widgets/dialogs/EditSignatureDialog.dart';
import 'package:OpenJMU/widgets/image/ImageViewer.dart';

@FFRoute(
  name: "openjmu://user",
  routeName: "用户页",
  argumentNames: ["uid"],
)
class UserPage extends StatefulWidget {
  final int uid;

  const UserPage({
    Key key,
    @required this.uid,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _UserPageState();

  static Future jump(int uid) {
    return navigatorState.pushNamed(
      "openjmu://user",
      arguments: {"uid": uid},
    );
  }
}

class _UserPageState extends State<UserPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  UserInfo _user;
  List<UserTag> _tags = [];
  Widget _post;
  String _fansCount, _idolsCount;
  int userLevel;

  bool isSelf = false;
  bool isLoading = true;
  bool showTitle = false;
  bool refreshing = false;

  List<String> _tabList = ["动态", "黑名单"];
  TabController _tabController;
  PostController postController;
  ScrollController _scrollController = ScrollController();
  double tabBarHeight = suSetSp(46.0);
  double expandedHeight = kToolbarHeight + suSetSp(212.0);

  @override
  void initState() {
    if (widget.uid == UserAPI.currentUser.uid) isSelf = true;

    if (isSelf) expandedHeight += tabBarHeight;

    _tabController = TabController(length: _tabList.length, vsync: this);
    postController = PostController(
      postType: "user",
      isFollowed: false,
      isMore: false,
      lastValue: (int id) => id,
      additionAttrs: {'uid': widget.uid},
    );
    _post = PostList(postController, needRefreshIndicator: false);

    _fetchUserInformation(widget.uid);

    Instances.eventBus
      ..on<SignatureUpdatedEvent>().listen((event) {
        Future.delayed(Duration(milliseconds: 2400), () {
          _user.signature = event.signature;
          if (this.mounted) setState(() {});
        });
      })
      ..on<AvatarUpdatedEvent>().listen((event) {
        UserAPI.updateAvatarProvider();
        _fetchUserInformation(widget.uid);
      })
      ..on<BlacklistUpdateEvent>().listen((event) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (this.mounted) setState(() {});
        });
      });

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollController
      ..removeListener(listener)
      ..addListener(listener);
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController?.dispose();
  }

  void listener() {
    double triggerHeight = expandedHeight - suSetSp(20.0);
    if (isSelf) triggerHeight -= tabBarHeight;

    if (_scrollController.offset >= triggerHeight && !showTitle) {
      setState(() {
        showTitle = true;
      });
    } else if (_scrollController.offset < triggerHeight && showTitle) {
      setState(() {
        showTitle = false;
      });
    }
  }

  Future<Null> _fetchUserInformation(uid) async {
    if (uid == UserAPI.currentUser.uid) {
      _user = UserAPI.currentUser;
    } else {
      Map<String, dynamic> user = (await UserAPI.getUserInfo(uid: uid)).data;
      _user = UserInfo.fromJson(user);
    }

    Future.wait(<Future>[
      UserAPI.getLevel(uid).then((response) {
        userLevel =
            int.parse(response.data['score']['levelinfo']['level'].toString());
      }),
      UserAPI.getTags(uid).then((response) {
        List tags = response.data['data'];
        List<UserTag> _userTags = [];
        tags.forEach((tag) {
          _userTags.add(UserAPI.createUserTag(tag));
        });
        _tags = _userTags;
      }),
      _getCount(uid),
    ]).then((whatever) {
      if (mounted) {
        setState(() {
          isLoading = false;
          refreshing = false;
        });
      }
    });
  }

  Future<Null> _getCount(id) async {
    Map data = (await UserAPI.getFansAndFollowingsCount(id)).data;
    if (this.mounted)
      setState(() {
        _user.isFollowing = data['is_following'] == 1;
        _fansCount = data['fans'].toString();
        _idolsCount = data['idols'].toString();
      });
  }

  Widget avatar(context, double width) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        avatarTap(context);
      },
      child: SizedBox(
        width: suSetSp(width),
        height: suSetSp(width),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(suSetSp(width / 2)),
          child: FadeInImage(
            fadeInDuration: const Duration(milliseconds: 100),
            placeholder: AssetImage("assets/avatar_placeholder.png"),
            image: UserAPI.getAvatarProvider(uid: widget.uid),
          ),
        ),
      ),
    );
  }

  Widget followButton() => Container(
        height: suSetSp(48.0),
        padding: EdgeInsets.symmetric(
          horizontal: suSetSp(4.0),
        ),
        child: FlatButton(
          padding: EdgeInsets.symmetric(
            horizontal: suSetSp(28.0),
            vertical: suSetSp(12.0),
          ),
          onPressed: () {
            if (isSelf) {
              showDialog<Null>(
                context: context,
                builder: (BuildContext context) =>
                    EditSignatureDialog(_user.signature),
              );
            } else {
              if (_user.isFollowing) {
                UserAPI.unFollow(widget.uid).then((response) {
                  _user.isFollowing = false;
                  if (mounted) setState(() {});
                });
              } else {
                UserAPI.follow(widget.uid).then((response) {
                  _user.isFollowing = true;
                  if (mounted) setState(() {});
                });
              }
            }
          },
          color: isSelf
              ? Color(0x44ffffff)
              : _user.isFollowing
                  ? Color(0x44ffffff)
                  : Color(ThemeUtils.currentThemeColor.value - 0x33000000),
          child: Text(
            isSelf
                ? "编辑签名"
                : _user.isFollowing
                    ? "已关注"
                    : "关注${_user.gender == 2 ? "她" : "他"}",
            style: TextStyle(
              color: Colors.white,
              fontSize: suSetSp(18.0),
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(suSetSp(32.0)),
          ),
        ),
      );

  Widget qrCode(context) => Container(
        width: suSetSp(48.0),
        height: suSetSp(48.0),
        decoration: BoxDecoration(
          color: const Color(0x44ffffff),
          shape: BoxShape.circle,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: Icon(
            AntDesign.getIconData("qrcode"),
            size: suSetSp(26.0),
            color: Colors.white,
          ),
          onTap: () {
            navigatorState.pushNamed("openjmu://user-qrcode");
          },
        ),
      );

  List<Widget> flexSpaceWidgets(context) => [
        Padding(
          padding: EdgeInsets.only(bottom: suSetSp(12.0)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              avatar(context, 100.0),
              Expanded(child: SizedBox()),
              followButton(),
              if (isSelf) qrCode(context),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              _user.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: suSetSp(24.0),
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Constants.emptyDivider(width: 8.0),
            DecoratedBox(
              decoration: BoxDecoration(
                color:
                    _user.gender == 2 ? Colors.pinkAccent : Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(suSetSp(3.0)),
                child: SvgPicture.asset(
                  "assets/icons/gender/${_user.gender == 2 ? "fe" : ""}male.svg",
                  width: suSetSp(16.0),
                  height: suSetSp(16.0),
                  color: Colors.white,
                ),
              ),
            ),
            Constants.emptyDivider(width: 8.0),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: suSetSp(8.0),
                vertical: suSetSp(4.0),
              ),
              decoration: BoxDecoration(
                color: ThemeUtils.defaultColor,
                borderRadius: BorderRadius.circular(suSetSp(20.0)),
              ),
              child: Text(
                " Lv.$userLevel",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: suSetSp(14.0),
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (Constants.developerList.contains(_user.uid))
              Constants.emptyDivider(width: 8.0),
            if (Constants.developerList.contains(_user.uid))
              Constants.developerTag(
                padding: EdgeInsets.symmetric(
                  horizontal: suSetSp(8.0),
                  vertical: suSetSp(4.0),
                ),
                height: 30.0,
              ),
          ],
        ),
        Text(
          _user.signature ?? "这个人很懒，什么都没写",
          style: TextStyle(
            color: Colors.grey[350],
            fontSize: suSetSp(16.0),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                navigatorState.pushNamed(
                  "openjmu://userlist",
                  arguments: {"user": _user, "type": 1},
                );
              },
              child: RichText(
                  text: TextSpan(children: <TextSpan>[
                TextSpan(
                  text: _idolsCount,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: suSetSp(24.0),
                  ),
                ),
                TextSpan(
                  text: " 关注",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: suSetSp(18.0),
                  ),
                ),
              ])),
            ),
            Constants.emptyDivider(width: 12.0),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                navigatorState.pushNamed(
                  "openjmu://userlist",
                  arguments: {"user": _user, "type": 2},
                );
              },
              child: RichText(
                text: TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                      text: _fansCount,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: suSetSp(24.0),
                      ),
                    ),
                    TextSpan(
                      text: " 粉丝",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: suSetSp(18.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _tags?.length != 0
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < _tags.length; i++)
                      Container(
                        margin: EdgeInsets.only(right: suSetSp(12.0)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(suSetSp(20.0)),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: suSetSp(8.0),
                            ),
                            decoration: BoxDecoration(
                              color: Color(0x44ffffff),
                            ),
                            child: Text(
                              _tags[i].name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: suSetSp(16.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Text(
                "${_user.gender == 2 ? "她" : "他"}还没有设置个性标签",
                style: TextStyle(
                  color: Colors.grey[350],
                  fontSize: suSetSp(16.0),
                ),
              ),
      ];

  Widget blacklistUser(String user) {
    Map<String, dynamic> _user = jsonDecode(user);
    return Padding(
      padding: EdgeInsets.all(suSetSp(8.0)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          SizedBox(
            width: suSetSp(64.0),
            height: suSetSp(64.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(suSetSp(32.0)),
              child: FadeInImage(
                fadeInDuration: const Duration(milliseconds: 100),
                placeholder: AssetImage("assets/avatar_placeholder.png"),
                image: UserAPI.getAvatarProvider(
                    uid: int.parse(_user['uid'].toString())),
              ),
            ),
          ),
          Text(
            _user['username'],
            style: TextStyle(
              fontSize: suSetSp(18.0),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => PlatformAlertDialog(
                  title: Text(
                    "移出黑名单",
                    style: TextStyle(
                      fontSize: suSetSp(22.0),
                    ),
                  ),
                  content: Text(
                    "确定不再屏蔽此人吗？",
                    style: TextStyle(
                      fontSize: suSetSp(18.0),
                    ),
                  ),
                  actions: <Widget>[
                    PlatformButton(
                      android: (BuildContext context) =>
                          MaterialRaisedButtonData(
                        color: Theme.of(context).dialogBackgroundColor,
                        elevation: 0,
                        disabledElevation: 0.0,
                        highlightElevation: 0.0,
                        child: Text("确认",
                            style:
                                TextStyle(color: ThemeUtils.currentThemeColor)),
                      ),
                      ios: (BuildContext context) => CupertinoButtonData(
                        child: Text(
                          "确认",
                          style: TextStyle(color: ThemeUtils.currentThemeColor),
                        ),
                      ),
                      onPressed: () {
                        UserAPI.fRemoveFromBlacklist(
                          uid: int.parse(_user['uid']),
                          name: _user['username'],
                        );
                        Navigator.pop(context);
                      },
                    ),
                    PlatformButton(
                      android: (BuildContext context) =>
                          MaterialRaisedButtonData(
                        color: ThemeUtils.currentThemeColor,
                        elevation: 0,
                        disabledElevation: 0.0,
                        highlightElevation: 0.0,
                        child:
                            Text('取消', style: TextStyle(color: Colors.white)),
                      ),
                      ios: (BuildContext context) => CupertinoButtonData(
                        child: Text("取消",
                            style:
                                TextStyle(color: ThemeUtils.currentThemeColor)),
                      ),
                      onPressed: Navigator.of(context).pop,
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: suSetSp(10.0),
                vertical: suSetSp(6.0),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(suSetSp(10.0)),
                color: ThemeUtils.currentThemeColor.withAlpha(0x88),
              ),
              child: Text(
                "移出黑名单",
                style: TextStyle(
                  fontSize: suSetSp(16.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void avatarTap(context) {
    widget.uid == UserAPI.currentUser.uid
        ? showModalBottomSheet(
            context: context,
            builder: (BuildContext sheetContext) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: Icon(
                      Icons.account_circle,
                      color: Theme.of(context).iconTheme.color,
                      size: suSetSp(30.0),
                    ),
                    title: Text(
                      "查看大头像",
                      style: Theme.of(context).textTheme.body1.copyWith(
                            fontSize: suSetSp(20.0),
                          ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      navigatorState.pushNamed(
                        "openjmu://image-viewer",
                        arguments: {
                          "index": 0,
                          "pics": [
                            ImageBean(
                              id: widget.uid,
                              imageUrl: "${API.userAvatar}"
                                  "?uid=${widget.uid}"
                                  "&size=f640",
                            ),
                          ],
                          "needsClear": true,
                        },
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.photo_library,
                      color: Theme.of(context).iconTheme.color,
                      size: suSetSp(30.0),
                    ),
                    title: Text(
                      "更换头像",
                      style: Theme.of(context).textTheme.body1.copyWith(
                            fontSize: suSetSp(20.0),
                          ),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      navigatorState
                          .pushNamed("openjmu://image-crop")
                          .then((result) {
                        if (result != null && result) {
                          Instances.eventBus.fire(AvatarUpdatedEvent());
                        }
                      });
                    },
                  ),
                  SizedBox(height: Screen.bottomSafeHeight),
                ],
              );
            },
          )
        : navigatorState.pushNamed(
            "openjmu://image-viewer",
            arguments: {
              "index": 0,
              "pics": [
                ImageBean(
                  id: widget.uid,
                  imageUrl: API.userAvatar + "?uid=${widget.uid}&size=f640",
                )
              ],
              "needsClear": true,
            },
          );
  }

  @mustCallSuper
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: isLoading
          ? Center(child: Constants.progressIndicator())
          : NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) => <Widget>[
                SliverAppBar(
                  title: showTitle
                      ? GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTap: () {
                            _scrollController.animateTo(
                              0.0,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.ease,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              avatar(context, 40.0),
                              Constants.emptyDivider(width: 8.0),
                              Text(
                                _user.name,
                                style:
                                    Theme.of(context).textTheme.title.copyWith(
                                          fontSize: suSetSp(21.0),
                                        ),
                              ),
                            ],
                          ),
                        )
                      : null,
                  actions: <Widget>[
                    refreshing
                        ? Container(
                            width: 56.0,
                            padding: EdgeInsets.all(20.0),
                            child: Constants.progressIndicator(
                              strokeWidth: 3.0,
                              color: Colors.white,
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.refresh),
                            onPressed: () {
                              _scrollController.animateTo(
                                0.0,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                              Future.delayed(Duration(milliseconds: 300), () {
                                setState(() {
                                  refreshing = true;
                                });
                                postController.reload();
                                _fetchUserInformation(widget.uid);
                              });
                            },
                          ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: Image(
                            image: UserAPI.getAvatarProvider(uid: widget.uid),
                            fit: BoxFit.fitWidth,
                            width: MediaQuery.of(context).size.width,
                          ),
                        ),
                        BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            color: Color.fromARGB(120, 50, 50, 50),
                          ),
                        ),
                        SafeArea(
                          top: true,
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: suSetSp(20.0)),
                            child: Column(
                              children: <Widget>[
                                Constants.emptyDivider(
                                    height: kToolbarHeight + 4.0),
                                ListView.builder(
                                  physics: NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: flexSpaceWidgets(context).length,
                                  itemBuilder:
                                      (BuildContext context, int index) =>
                                          Padding(
                                    padding:
                                        EdgeInsets.only(bottom: suSetSp(12.0)),
                                    child: flexSpaceWidgets(context)[index],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  bottom: isSelf
                      ? PreferredSize(
                          child: Container(
                            height: suSetSp(40.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(tabBarHeight / 3),
                                topRight: Radius.circular(tabBarHeight / 3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Flexible(
                                    child: TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  indicatorSize: TabBarIndicatorSize.label,
                                  indicatorWeight: suSetSp(3.0),
                                  labelStyle: TextStyle(
                                    fontSize: suSetSp(16.0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  unselectedLabelStyle: TextStyle(
                                    fontSize: suSetSp(16.0),
                                    fontWeight: FontWeight.normal,
                                  ),
                                  tabs: <Widget>[
                                    for (String _tabLabel in _tabList)
                                      Tab(text: _tabLabel)
                                  ],
                                ))
                              ],
                            ),
                          ),
                          preferredSize: Size.fromHeight(tabBarHeight),
                        )
                      : null,
                  expandedHeight: kToolbarHeight + expandedHeight,
                  iconTheme: !showTitle
                      ? Theme.of(context).iconTheme.copyWith(
                            color: Colors.white,
                          )
                      : Theme.of(context).iconTheme,
                  primary: true,
                  centerTitle: true,
                  pinned: true,
                ),
              ],
              body: isSelf
                  ? TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _post,
                        UserAPI.blacklist.length > 0
                            ? GridView.count(
                                crossAxisCount: 3,
                                children: <Widget>[
                                  for (int i = 0;
                                      i < UserAPI.blacklist.length;
                                      i++)
                                    blacklistUser(UserAPI.blacklist[i]),
                                ],
                              )
                            : Center(
                                child: Text(
                                  "黑名单为空",
                                  style: TextStyle(
                                    fontSize: suSetSp(18.0),
                                  ),
                                ),
                              ),
                      ],
                    )
                  : _post,
            ),
    );
  }
}

@FFRoute(
  name: "openjmu://userlist",
  routeName: "用户列表页",
  argumentNames: ["user", "type"],
)
class UserListPage extends StatefulWidget {
  final UserInfo user;
  final int type; // 0 is search, 1 is idols, 2 is fans.

  UserListPage({
    Key key,
    @required this.user,
    @required this.type,
  }) : super(key: key);

  @override
  State createState() => _UserListState();
}

class _UserListState extends State<UserListPage> {
  List _users = [];

  bool canLoadMore = false, isLoading = true;
  int total, pages = 1;

  @override
  void initState() {
    super.initState();
    doUpdate(false);
  }

  void doUpdate(isMore) {
    if (isMore) pages++;
    switch (widget.type) {
      case 1:
        getIdolsList(pages, isMore);
        break;
      case 2:
        getFansList(pages, isMore);
        break;
    }
  }

  void getIdolsList(page, isMore) {
    UserAPI.getIdolsList(widget.user.uid, page).then((response) {
      setUserList(response, isMore);
    });
  }

  void getFansList(page, isMore) {
    UserAPI.getFansList(widget.user.uid, page).then((response) {
      setUserList(response, isMore);
    });
  }

  void setUserList(response, isMore) {
    List data;
    switch (widget.type) {
      case 1:
        data = response.data['idols'];
        break;
      case 2:
        data = response.data['fans'];
        break;
    }
    int total = int.parse(response.data['total'].toString());
    if (_users.length + data.length < total) canLoadMore = true;
    List users = [];
    for (int i = 0; i < data.length; i++) users.add(data[i]);
    if (mounted)
      setState(() {
        if (isMore) {
          List _u = _users;
          _u.addAll(users);
          _users = _u;
        } else {
          _users = users;
        }
        isLoading = false;
      });
  }

  Widget renderRow(context, i) {
    int start = i * 2;
    if (_users != null && i + 1 == (_users.length / 2).ceil() && canLoadMore)
      doUpdate(true);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (int j = start; j < start + 2 && j < _users.length; j++)
          userCard(context, _users[j])
      ],
    );
  }

  Widget userCard(context, userData) {
    var _user = userData['user'];
    String name = _user['nickname'];
    if (name.length > 3) name = "${name.substring(0, 3)}...";
    TextStyle _textStyle = TextStyle(fontSize: suSetSp(16.0));
    return GestureDetector(
      onTap: () => UserPage.jump(int.parse(_user['uid'].toString())),
      child: Container(
        margin: EdgeInsets.fromLTRB(
          suSetSp(12.0),
          suSetSp(20.0),
          suSetSp(12.0),
          suSetSp(0.0),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: suSetSp(20.0),
          vertical: suSetSp(12.0),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(suSetSp(16.0)),
          color: Theme.of(context).canvasColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: suSetSp(64.0),
              height: suSetSp(64.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(suSetSp(32.0)),
                child: FadeInImage(
                  fadeInDuration: const Duration(milliseconds: 100),
                  placeholder: AssetImage("assets/avatar_placeholder.png"),
                  image: UserAPI.getAvatarProvider(
                      uid: int.parse(_user['uid'].toString())),
                ),
              ),
            ),
            SizedBox(width: suSetSp(12.0)),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          name,
                          style: TextStyle(fontSize: suSetSp(20.0)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Divider(height: suSetSp(6.0)),
                    Row(
                      children: <Widget>[
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text("关注", style: _textStyle),
                            Divider(height: suSetSp(4.0)),
                            Text(userData['idols'], style: _textStyle),
                          ],
                        ),
                        SizedBox(width: suSetSp(6.0)),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text("粉丝", style: _textStyle),
                            Divider(height: suSetSp(4.0)),
                            Text(userData['fans'], style: _textStyle),
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String _type;
    switch (widget.type) {
      case 0:
        _type = "用户";
        break;
      case 1:
        _type = "关注";
        break;
      case 2:
        _type = "粉丝";
        break;
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "$_type列表",
          style: Theme.of(context).textTheme.title.copyWith(
                fontSize: suSetSp(21.0),
              ),
        ),
      ),
      body: !isLoading
          ? _users.length != 0
              ? ListView.builder(
                  itemCount: (_users.length / 2).ceil(),
                  itemBuilder: (context, i) => renderRow(context, i),
                )
              : Center(
                  child:
                      Text("暂无内容", style: TextStyle(fontSize: suSetSp(20.0))))
          : Center(
              child: Constants.progressIndicator(),
            ),
    );
  }
}
