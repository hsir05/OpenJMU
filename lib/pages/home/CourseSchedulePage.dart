import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:OpenJMU/constants/Constants.dart';
import 'package:OpenJMU/pages/home/AppCenterPage.dart';

class CourseSchedulePage extends StatefulWidget {
  final AppCenterPageState appCenterPageState;
  const CourseSchedulePage({
    @required Key key,
    @required this.appCenterPageState,
  }) : super(key: key);

  @override
  CourseSchedulePageState createState() => CourseSchedulePageState();
}

class CourseSchedulePageState extends State<CourseSchedulePage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey = GlobalKey();
  final Duration showWeekDuration = const Duration(milliseconds: 300);
  final Curve showWeekCurve = Curves.fastOutSlowIn;
  final double weekSize = 100.0;
  final double monthWidth = 40.0;
  final double indicatorHeight = 60.0;
  final int maxCoursesPerDay = 12;
  ScrollController weekScrollController;

  bool firstLoaded = false,
      hasCourse = true,
      showWeek = false,
      showError = false;
  int currentWeek;
  DateTime now;

  String remark;
  Map<int, Map<int, List<Course>>> courses;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    if (!firstLoaded) initSchedule();

    Instances.eventBus
      ..on<CourseScheduleRefreshEvent>().listen((event) {
        if (this.mounted) {
          refreshIndicatorKey.currentState.show();
        }
      })
      ..on<CurrentWeekUpdatedEvent>().listen((event) {
        if (currentWeek == null) {
          if (now != null) firstLoaded = true;
          currentWeek = DateAPI.currentWeek;
          updateScrollController();
          if (mounted) setState(() {});
          if (weekScrollController.hasClients) scrollToWeek(currentWeek);
          if (widget.appCenterPageState.mounted) {
            widget.appCenterPageState.setState(() {});
          }
        }
      });
    super.initState();
  }

  @override
  void dispose() {
    courses = resetCourse(courses);
    super.dispose();
  }

  Future initSchedule() async {
    if (showWeek) {
      showWeek = false;
      if (widget.appCenterPageState.mounted) {
        widget.appCenterPageState.setState(() {});
      }
    }
    return Future.wait(<Future>[
      getCourses(),
      getRemark(),
    ]).then((responses) {
      currentWeek = DateAPI.currentWeek;
      now = DateTime.now();
      if (!firstLoaded) {
        if (currentWeek != null) firstLoaded = true;
        if (widget.appCenterPageState.mounted) {
          widget.appCenterPageState.setState(() {});
        }
      }
      if (showError) showError = false;
      updateScrollController();
      if (mounted) setState(() {});
      if (DateAPI.currentWeek != null) scrollToWeek(DateAPI.currentWeek);
    }).catchError((e) {
      if (!firstLoaded && currentWeek != null) firstLoaded = true;
      hasCourse = false;
      showError = true;
      if (mounted) setState(() {});
    });
  }

  Map<int, Map<int, List<Course>>> resetCourse(
      Map<int, Map<int, List<Course>>> courses) {
    courses = {
      for (int i = 1; i < 7 + 1; i++)
        i: {for (int i = 1; i < maxCoursesPerDay + 1; i++) i: []},
    };
    for (int key in courses.keys) {
      courses[key] = {for (int i = 1; i < maxCoursesPerDay + 1; i++) i: []};
    }
    return courses;
  }

  Future getCourses() async {
    return CourseAPI.getCourse().then((response) {
      final data = jsonDecode(response.data);
      List _courseList = data['courses'];
      List _customCourseList = data['othCase'];
      Map<int, Map<int, List<Course>>> _courses;
      _courses = resetCourse(_courses);
      if (_courseList.length == 0) {
        hasCourse = false;
      }
      _courseList.forEach((course) {
        Course _c = Course.fromJson(course);
        addCourse(_c, _courses);
      });
      _customCourseList.forEach((course) {
        if (course['content'].trim().isNotEmpty) {
          Course _c = Course.fromJson(course, isCustom: true);
          addCourse(_c, _courses);
        }
      });
      if (courses.toString() != _courses.toString()) {
        courses = _courses;
      }
    });
  }

  Future getRemark() async {
    return CourseAPI.getRemark().then((response) {
      final data = jsonDecode(response.data);
      String _remark;
      if (data != null) _remark = data['classScheduleRemark'];
      if (remark != _remark && _remark != "" && _remark != null) {
        remark = _remark;
      }
    }).catchError((e) {
      debugPrint('Get remark error: $e');
    });
  }

  void updateScrollController() {
    weekScrollController ??= ScrollController(
      initialScrollOffset: DateAPI.currentWeek != null
          ? math.max(
              0,
              (DateAPI.currentWeek - 0.5) * suSetSp(weekSize) -
                  Screen.width / 2,
            )
          : 0.0,
    );
  }

  void scrollToWeek(int week) {
    if (weekScrollController.hasClients)
      weekScrollController.animateTo(
        math.max(0, (week - 0.5) * suSetSp(weekSize) - Screen.width / 2),
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
  }

  void addCourse(Course course, Map<int, Map<int, List<Course>>> courses) {
    if (course.time == "11") {
      courses[course.day][11].add(course);
    } else {
      if (courses.keys.contains(course.day)) {
        courses[course.day][int.parse(course.time.substring(0, 1))].add(course);
      }
    }
  }

  void showRemarkDetail() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          backgroundColor: Theme.of(context).canvasColor.withOpacity(0.8),
          contentPadding: EdgeInsets.zero,
          children: [
            Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(bottom: suSetSp(10.0)),
                    child: Text(
                      "班级备注",
                      style: Theme.of(context).textTheme.title.copyWith(
                            fontSize: suSetSp(23.0),
                          ),
                    ),
                  ),
                  Text(
                    "$remark",
                    style: TextStyle(
                      fontSize: suSetSp(18.0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void showWeekWidget() {
    showWeek = !showWeek;
    widget.appCenterPageState.setState(() {});
    if (mounted) setState(() {});
  }

  int maxWeekDay() {
    int _maxWeekday = 5;
    for (int count in courses[6].keys) {
      if (courses[6][count].isNotEmpty) {
        if (_maxWeekday != 7) _maxWeekday = 6;
        break;
      }
    }
    for (int count in courses[7].keys) {
      if (courses[7][count].isNotEmpty) {
        _maxWeekday = 7;
        break;
      }
    }
    return _maxWeekday;
  }

  Widget _week(context, int index) {
    return InkWell(
      onTap: () {
        now = now.add(Duration(days: 7 * (index + 1 - currentWeek)));
        currentWeek = index + 1;
        if (mounted) setState(() {});
        scrollToWeek(index + 1);
      },
      child: Container(
        width: suSetSp(weekSize),
        padding: EdgeInsets.all(suSetSp(10.0)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(suSetSp(20.0)),
            border: (DateAPI.currentWeek == index + 1 &&
                    currentWeek != DateAPI.currentWeek)
                ? Border.all(
                    color: ThemeUtils.currentThemeColor.withAlpha(100),
                    width: 2.0,
                  )
                : null,
            color: currentWeek == index + 1
                ? ThemeUtils.currentThemeColor.withAlpha(100)
                : null,
          ),
          child: Center(
            child: Stack(
              children: <Widget>[
                SizedBox.expand(
                  child: Center(
                    child: RichText(
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: "第",
                          ),
                          TextSpan(
                            text: "${index + 1}",
                            style: TextStyle(
                              fontSize: suSetSp(26.0),
                            ),
                          ),
                          TextSpan(
                            text: "周",
                          ),
                        ],
                        style: Theme.of(context).textTheme.body1.copyWith(
                              fontSize: suSetSp(16.0),
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget get remarkWidget => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: showRemarkDetail,
        child: AnimatedContainer(
          duration: showWeekDuration,
          width: Screen.width,
          constraints: BoxConstraints(
            maxHeight: suSetSp(48.0),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: suSetSp(30.0),
          ),
          color: showWeek
              ? Theme.of(context).primaryColor
              : Theme.of(context).canvasColor,
          child: Center(
            child: RichText(
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: "班级备注: ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: "$remark",
                  ),
                ],
                style: Theme.of(context).textTheme.body1.copyWith(
                      fontSize: suSetSp(17.0),
                    ),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

  Widget weekSelection(context) => AnimatedContainer(
        curve: showWeekCurve,
        duration: const Duration(milliseconds: 300),
        width: Screen.width,
        height: showWeek ? suSetSp(weekSize / 1.5) : 0.0,
        child: ListView.builder(
          controller: weekScrollController,
          physics: const ClampingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemCount: 20,
          itemBuilder: _week,
        ),
      );

  Widget weekDayIndicator(context) {
    String _month() => DateFormat("MMM", "zh_CN").format(
          now.subtract(Duration(days: now.weekday - 1)),
        );
    String _weekday(int i) => DateFormat("EEE", "zh_CN").format(
          now.subtract(Duration(days: now.weekday - 1 - i)),
        );
    String _date(int i) => DateFormat("MM/dd").format(
          now.subtract(Duration(days: now.weekday - 1 - i)),
        );

    return Container(
      color: Theme.of(context).canvasColor,
      height: suSetSp(indicatorHeight),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: monthWidth,
            child: Center(
              child: Text(
                "${_month().substring(0, _month().length - 1)}"
                "\n"
                "${_month().substring(
                  _month().length - 1,
                  _month().length,
                )}",
                style: TextStyle(
                  fontSize: suSetSp(16),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          for (int i = 0; i < maxWeekDay(); i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(suSetSp(5.0)),
                  color: DateFormat("MM/dd").format(
                            now.subtract(Duration(days: now.weekday - 1 - i)),
                          ) ==
                          DateFormat("MM/dd").format(DateTime.now())
                      ? ThemeUtils.currentThemeColor.withAlpha(100)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        _weekday(i),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: suSetSp(16),
                        ),
                      ),
                      Text(
                        _date(i),
                        style: TextStyle(
                          fontSize: suSetSp(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget courseLineGrid(context) {
    final double totalHeight = Screen.height -
        Screen.topSafeHeight -
        kToolbarHeight -
        suSetSp(indicatorHeight);

    bool hasEleven = false;
    int _maxCoursesPerDay = 8;
    for (int day in courses.keys) {
      if (courses[day][9].isNotEmpty && _maxCoursesPerDay < 10) {
        _maxCoursesPerDay = 10;
      } else if (courses[day][9].isNotEmpty &&
          courses[day][9].where((course) => course.isEleven).isNotEmpty &&
          _maxCoursesPerDay < 11) {
        hasEleven = true;
        _maxCoursesPerDay = 11;
      } else if (courses[day][11].isNotEmpty && _maxCoursesPerDay < 12) {
        _maxCoursesPerDay = 12;
        break;
      }
    }
    if (mounted) setState(() {});

    return Expanded(
      child: Row(
        children: <Widget>[
          Container(
            color: Theme.of(context).canvasColor,
            width: monthWidth,
            height: totalHeight,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < _maxCoursesPerDay; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        (i + 1).toString(),
                        style: TextStyle(
                          fontSize: suSetSp(16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (int day = 1; day < maxWeekDay() + 1; day++)
            Expanded(
              child: Column(
                children: <Widget>[
                  for (int count = 1; count < _maxCoursesPerDay + 1; count++)
                    if (count.isEven)
                      CourseWidget(
                        courseList: courses[day][count - 1],
                        hasEleven: hasEleven && count == 10,
                        currentWeek: currentWeek,
                        coordinate: [day, count],
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget get emptyTips => Expanded(
        child: Center(
          child: Text(
            "没有课的日子\n往往就是这么的朴实无华\n且枯燥\n😆",
            style: TextStyle(
              fontSize: suSetSp(30.0),
            ),
            strutStyle: StrutStyle(
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );

  Widget get errorTips => Expanded(
        child: Center(
          child: Text(
            "成绩看起来还未准备好\n不如到广场放松一下？\n🤒",
            style: TextStyle(
              fontSize: suSetSp(30.0),
            ),
            strutStyle: StrutStyle(
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );

  @mustCallSuper
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      key: refreshIndicatorKey,
      child: Container(
        width: Screen.width,
        constraints: BoxConstraints(maxWidth: Screen.width),
        color: Theme.of(context).primaryColor,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: !firstLoaded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Center(child: Constants.progressIndicator()),
          secondChild: Column(
            children: <Widget>[
              if (remark != null) remarkWidget,
              weekSelection(context),
              if (firstLoaded && hasCourse) weekDayIndicator(context),
              if (firstLoaded && hasCourse) courseLineGrid(context),
              if (firstLoaded && !hasCourse && !showError) emptyTips,
              if (firstLoaded && !hasCourse && showError) errorTips,
            ],
          ),
        ),
      ),
      onRefresh: initSchedule,
    );
  }
}

class CourseWidget extends StatelessWidget {
  final List<Course> courseList;
  final List<int> coordinate;
  final bool hasEleven;
  final int currentWeek;

  const CourseWidget({
    Key key,
    @required this.courseList,
    @required this.coordinate,
    this.hasEleven,
    this.currentWeek,
  })  : assert(coordinate.length == 2, "Invalid course coordinate"),
        super(key: key);

  void showCoursesDetail(context) {
    showDialog(
      context: context,
      builder: (context) {
        return CoursesDialog(
          courseList: courseList,
          currentWeek: currentWeek,
          coordinate: coordinate,
        );
      },
    );
  }

  Widget courseCustomIndicator(Course course) => Positioned(
        bottom: 1.5,
        left: 1.5,
        child: Container(
          width: suSetSp(24.0),
          height: suSetSp(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(10.0),
              bottomLeft: Radius.circular(5.0),
            ),
            color: ThemeUtils.currentThemeColor.withAlpha(100),
          ),
          child: Center(
            child: Text(
              "✍️",
              style: TextStyle(
                color: !CourseAPI.inCurrentWeek(
                  course,
                  currentWeek: currentWeek,
                )
                    ? Colors.grey
                    : Colors.black,
                fontSize: suSetSp(12.0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );

  Widget get courseCountIndicator => Positioned(
        bottom: 1.5,
        right: 1.5,
        child: Container(
          width: suSetSp(24.0),
          height: suSetSp(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10.0),
              bottomRight: Radius.circular(5.0),
            ),
            color: ThemeUtils.currentThemeColor.withAlpha(100),
          ),
          child: Center(
            child: Text(
              "${courseList.length}",
              style: TextStyle(
                color: Colors.black,
                fontSize: suSetSp(14.0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    bool isEleven = false;
    Course course;
    if (courseList != null && courseList.isNotEmpty) {
      course = courseList.firstWhere(
        (c) => CourseAPI.inCurrentWeek(c, currentWeek: currentWeek),
        orElse: () => null,
      );
    }
    if (course == null && courseList.isNotEmpty) course = courseList[0];
    if (hasEleven) isEleven = course?.isEleven ?? false;
    return Expanded(
      flex: hasEleven ? 3 : 2,
      child: Column(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                      ),
                      splashFactory: InkSplash.splashFactory,
                      hoverColor: Colors.black,
                      onTap: () {
                        if (courseList.isNotEmpty) showCoursesDetail(context);
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) => CourseEditDialog(
                            course: null,
                            coordinate: coordinate,
                          ),
                          barrierDismissible: false,
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(suSetSp(8.0)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5.0),
                          color: courseList.isNotEmpty
                              ? CourseAPI.inCurrentWeek(course,
                                      currentWeek: currentWeek)
                                  ? course.color.withAlpha(200)
                                  : Theme.of(context).dividerColor
                              : null,
                        ),
                        child: SizedBox.expand(
                          child: course != null
                              ? RichText(
                                  text: TextSpan(
                                    children: <InlineSpan>[
                                      if (!CourseAPI.inCurrentWeek(course,
                                          currentWeek: currentWeek))
                                        TextSpan(
                                          text: "[非本周]\n",
                                        ),
                                      TextSpan(
                                        text: course.name.substring(
                                          0,
                                          math.min(10, course.name.length),
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (course.name.length > 10)
                                        TextSpan(text: "..."),
                                      if (course.location != null)
                                        TextSpan(
                                          text: "\n📍${course.location}",
                                        ),
                                    ],
                                    style: Theme.of(context)
                                        .textTheme
                                        .body1
                                        .copyWith(
                                          color: !CourseAPI.inCurrentWeek(
                                            course,
                                            currentWeek: currentWeek,
                                          )
                                              ? Colors.grey
                                              : Colors.black,
                                          fontSize: suSetSp(14.0),
                                        ),
                                  ),
                                  overflow: TextOverflow.fade,
                                )
                              : Icon(
                                  Icons.add,
                                  color: Theme.of(context)
                                      .iconTheme
                                      .color
                                      .withOpacity(0.15)
                                      .withRed(180)
                                      .withBlue(180)
                                      .withGreen(180),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (courseList.where((course) => course.isCustom).isNotEmpty)
                  courseCustomIndicator(course),
                if (courseList.length > 1) courseCountIndicator,
              ],
            ),
          ),
          if (!isEleven && hasEleven) Spacer(flex: 1),
        ],
      ),
    );
  }
}

class CoursesDialog extends StatelessWidget {
  final List<Course> courseList;
  final int currentWeek;
  final List<int> coordinate;

  const CoursesDialog({
    Key key,
    @required this.courseList,
    @required this.currentWeek,
    @required this.coordinate,
  }) : super(key: key);

  final int darkModeAlpha = 200;

  void showCoursesDetail(context, Course course) {
    showDialog(
      context: context,
      builder: (context) => CoursesDialog(
        courseList: [course],
        currentWeek: currentWeek,
        coordinate: coordinate,
      ),
    );
  }

  Widget get coursesPage => PageView.builder(
        controller: PageController(viewportFraction: 0.8),
        physics: const BouncingScrollPhysics(),
        itemCount: courseList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 0.2 * 0.7 * Screen.height / 3 + 10.0,
            ),
            child: GestureDetector(
              onTap: () {
                showCoursesDetail(context, courseList[index]);
              },
              child: Stack(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      color: courseList.isNotEmpty
                          ? CourseAPI.inCurrentWeek(
                              courseList[index],
                              currentWeek: currentWeek,
                            )
                              ? ThemeUtils.isDark
                                  ? courseList[index]
                                      .color
                                      .withAlpha(darkModeAlpha)
                                  : courseList[index].color
                              : Colors.grey
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (courseList[index].isCustom)
                            Text(
                              "[自定义]",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: suSetSp(20.0),
                                height: 1.5,
                              ),
                            ),
                          if (!CourseAPI.inCurrentWeek(
                            courseList[index],
                            currentWeek: currentWeek,
                          ))
                            Text(
                              "[非本周]",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: suSetSp(20.0),
                                height: 1.5,
                              ),
                            ),
                          Text(
                            courseList[index].name,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: suSetSp(20.0),
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                          if (courseList[index].location != null)
                            Text(
                              "📍${courseList[index].location}",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: suSetSp(20.0),
                                height: 1.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget courseDetail(Course course) {
    final style = TextStyle(
      color: Colors.black,
      fontSize: suSetSp(20.0),
      height: 1.8,
    );
    return Container(
      width: double.maxFinite,
      height: double.maxFinite,
      padding: EdgeInsets.all(suSetSp(12.0)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.0),
        color: courseList.isNotEmpty
            ? CourseAPI.inCurrentWeek(course, currentWeek: currentWeek)
                ? ThemeUtils.isDark
                    ? course.color.withAlpha(darkModeAlpha)
                    : course.color
                : Colors.grey
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (course.isCustom)
              Text(
                "[自定义]",
                style: style,
              ),
            if (!CourseAPI.inCurrentWeek(
              course,
              currentWeek: currentWeek,
            ))
              Text(
                "[非本周]",
                style: style,
              ),
            Text(
              "${courseList[0].name}",
              style: style.copyWith(
                fontSize: suSetSp(24.0),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (course.location != null)
              Text(
                "📍 ${course.location}",
                style: style,
              ),
            if (course.startWeek != null && course.endWeek != null)
              Text(
                "📅 ${course.startWeek}"
                "-"
                "${course.endWeek}"
                "${course.oddEven == 1 ? "单" : course.oddEven == 2 ? "双" : ""}周",
                style: style,
              ),
            Text(
              "⏰ ${DateAPI.shortWeekdays[course.day - 1]} "
              "${CourseAPI.courseTimeChinese[course.time]}",
              style: style,
            ),
            if (course.teacher != null)
              Text(
                "🎓 ${course.teacher}",
                style: style,
              ),
            SizedBox(height: 12.0),
          ],
        ),
      ),
    );
  }

  Widget closeButton(context) => Positioned(
        top: 0.0,
        right: 0.0,
        child: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bool isDetail = courseList.length == 1;
    final Course firstCourse = courseList[0];
    return SimpleDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      contentPadding: EdgeInsets.zero,
      children: <Widget>[
        SizedBox(
          width: Screen.width / 2,
          height: suSetSp(370.0),
          child: Stack(
            children: <Widget>[
              !isDetail ? coursesPage : courseDetail(firstCourse),
              closeButton(context),
              if (isDetail && courseList[0].isCustom)
                Theme(
                  data: Theme.of(context).copyWith(
                    splashFactory: InkSplash.splashFactory,
                  ),
                  child: Positioned(
                    bottom: 10.0,
                    left: Screen.width / 7,
                    right: Screen.width / 7,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        MaterialButton(
                          padding: EdgeInsets.zero,
                          minWidth: 40.0,
                          height: 40.0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(Screen.width / 2),
                          ),
                          child: Icon(
                            Icons.delete,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            CourseAPI.setCustomCourse({
                              "content": Uri.encodeComponent(""),
                              "couDayTime": courseList[0].day,
                              "coudeTime": courseList[0].time,
                            }).then((response) {
                              if (jsonDecode(response.data)['isOk']) {
                                navigatorState
                                    .popUntil(ModalRoute.withName('/home'));
                              }
                              Instances.eventBus
                                  .fire(CourseScheduleRefreshEvent());
                            });
                            courseList.removeAt(0);
                          },
                        ),
                        MaterialButton(
                          padding: EdgeInsets.zero,
                          minWidth: 40.0,
                          height: 40.0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(Screen.width / 2),
                          ),
                          child: Icon(
                            Icons.edit,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => CourseEditDialog(
                                course: courseList[0],
                                coordinate: coordinate,
                              ),
                              barrierDismissible: false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class CourseEditDialog extends StatefulWidget {
  final Course course;
  final List<int> coordinate;

  const CourseEditDialog({
    Key key,
    @required this.course,
    @required this.coordinate,
  }) : super(key: key);

  @override
  _CourseEditDialogState createState() => _CourseEditDialogState();
}

class _CourseEditDialogState extends State<CourseEditDialog> {
  final int darkModeAlpha = 200;

  TextEditingController _controller;
  String content;
  bool loading = false;

  @override
  void initState() {
    content = widget.course?.name;
    _controller = TextEditingController(text: content);
    super.initState();
  }

  Widget get courseEditField {
    return Container(
      padding: EdgeInsets.all(suSetSp(12.0)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.0),
        color: widget.course != null
            ? ThemeUtils.isDark
                ? widget.course.color.withAlpha(darkModeAlpha)
                : widget.course.color
            : Theme.of(context).dividerColor,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: suSetSp(30.0),
          bottom: suSetSp(30.0),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Screen.width / 2,
            ),
            child: ScrollConfiguration(
              behavior: NoGlowScrollBehavior(),
              child: TextField(
                controller: _controller,
                autofocus: true,
                enabled: !loading,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: suSetSp(24.0),
                  height: 1.5,
                  textBaseline: TextBaseline.alphabetic,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "自定义内容",
                  hintStyle: TextStyle(
                    color: Colors.grey,
                    fontSize: suSetSp(24.0),
                    height: 1.5,
                    textBaseline: TextBaseline.alphabetic,
                  ),
                ),
                maxLines: null,
                maxLength: 30,
                buildCounter: (_, {currentLength, maxLength, isFocused}) =>
                    SizedBox.shrink(),
                onChanged: (String value) {
                  content = value;
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget closeButton(context) => Positioned(
        top: 0.0,
        right: 0.0,
        child: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      );

  Widget updateButton(context) => Theme(
        data: Theme.of(context).copyWith(
          splashFactory: InkSplash.splashFactory,
        ),
        child: Positioned(
          bottom: suSetSp(8.0),
          left: Screen.width / 7,
          right: Screen.width / 7,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              MaterialButton(
                padding: EdgeInsets.zero,
                minWidth: suSetSp(48.0),
                height: suSetSp(48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Screen.width / 2),
                ),
                child: loading
                    ? Center(
                        child: SizedBox(
                          width: suSetSp(30.0),
                          height: suSetSp(30.0),
                          child: Constants.progressIndicator(),
                        ),
                      )
                    : Icon(
                        Icons.check,
                        color: content == widget.course?.name
                            ? Colors.black.withAlpha(50)
                            : Colors.black,
                      ),
                onPressed: content == widget.course?.name
                    ? null
                    : () {
                        loading = true;
                        if (mounted) setState(() {});
                        CourseAPI.setCustomCourse({
                          "content": Uri.encodeComponent(content),
                          "couDayTime": widget.course != null
                              ? widget.course.time
                              : widget.coordinate[0],
                          "coudeTime": widget.course != null
                              ? widget.course.time
                              : "${widget.coordinate[1] - 1}${widget.coordinate[1]}",
                        }).then((response) {
                          loading = false;
                          if (mounted) setState(() {});
                          if (jsonDecode(response.data)['isOk']) {
                            navigatorState
                                .popUntil(ModalRoute.withName('/home'));
                          }
                          Instances.eventBus.fire(CourseScheduleRefreshEvent());
                        });
                      },
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      contentPadding: EdgeInsets.zero,
      children: <Widget>[
        SizedBox(
          width: Screen.width / 2,
          height: suSetSp(370.0),
          child: Stack(
            children: <Widget>[
              courseEditField,
              closeButton(context),
              updateButton(context),
            ],
          ),
        ),
      ],
    );
  }
}
