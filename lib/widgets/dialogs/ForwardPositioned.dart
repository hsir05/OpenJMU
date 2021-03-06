import 'dart:io';
import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:ff_annotation_route/ff_annotation_route.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import 'package:OpenJMU/constants/Constants.dart';
import 'package:OpenJMU/widgets/ToggleButton.dart';
import 'package:OpenJMU/widgets/RoundedCheckBox.dart';
import 'package:OpenJMU/widgets/dialogs/MentionPeopleDialog.dart';

@FFRoute(
  name: "openjmu://add-forward",
  routeName: "新增转发",
  argumentNames: ["post"],
  pageRouteType: PageRouteType.transparent,
)
class ForwardPositioned extends StatefulWidget {
  final Post post;

  const ForwardPositioned({
    Key key,
    @required this.post,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => ForwardPositionedState();
}

class ForwardPositionedState extends State<ForwardPositioned> {
  final _forwardController = TextEditingController();
  final _focusNode = FocusNode();
  File _image;
  int _imageID;

  bool _forwarding = false;
  bool commentAtTheMeanTime = false;

  bool emoticonPadActive = false;

  double _keyboardHeight;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _forwardController?.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
    final file = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    _image = file;
    if (mounted) setState(() {});
  }

  FormData createForm(File file) => FormData.from({
        "image": UploadFileInfo(file, path.basename(file.path)),
        "image_type": 0,
      });

  Future getImageRequest(FormData formData) async =>
      NetUtils.postWithCookieAndHeaderSet(
        API.postUploadImage,
        data: formData,
      );

  Widget get textField => ExtendedTextField(
        specialTextSpanBuilder: StackSpecialTextFieldSpanBuilder(),
        focusNode: _focusNode,
        controller: _forwardController,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(suSetSp(12.0)),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: ThemeUtils.currentThemeColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: ThemeUtils.currentThemeColor,
            ),
          ),
          suffixIcon: _image != null
              ? SizedBox(
                  width: suSetSp(70.0),
                  child: Container(
                    margin: EdgeInsets.only(right: suSetSp(14.0)),
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: FileImage(_image),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              : null,
        ),
        enabled: !_forwarding,
        style: Theme.of(context).textTheme.body1.copyWith(
              fontSize: suSetSp(20.0),
              textBaseline: TextBaseline.alphabetic,
            ),
        cursorColor: ThemeUtils.currentThemeColor,
        autofocus: true,
        maxLines: 3,
      );

  void _request(context) async {
    setState(() {
      _forwarding = true;
    });
    String content;
    _forwardController.text.length == 0
        ? content = "转发"
        : content = _forwardController.text;

    /// Sending image if it exist.
    if (_image != null) {
      Map<String, dynamic> data =
          (await getImageRequest(createForm(_image))).data;
      _imageID = int.parse(data['image_id']);
      content += " |$_imageID| ";
    }

    PostAPI.postForward(
      content,
      widget.post.id,
      commentAtTheMeanTime,
    ).then((response) {
      showShortToast("转发成功");
      _forwarding = false;
      if (mounted) setState(() {});
      Navigator.of(context).pop();
      Instances.eventBus.fire(PostForwardedEvent(
        widget.post.id,
        widget.post.forwards,
      ));
    });
  }

  void updatePadStatus(context, bool active) {
    final change = () {
      emoticonPadActive = active;
      if (mounted) setState(() {});
    };
    emoticonPadActive
        ? change()
        : MediaQuery.of(context).viewInsets.bottom != 0.0
            ? SystemChannels.textInput
                .invokeMethod('TextInput.hide')
                .whenComplete(
                () async {
                  Future.delayed(const Duration(milliseconds: 300), () {})
                      .whenComplete(change);
                },
              )
            : change();
  }

  void insertText(String text) {
    final value = _forwardController.value;
    final start = value.selection.baseOffset;
    final end = value.selection.extentOffset;
    if (value.selection.isValid) {
      String newText = "";
      if (value.selection.isCollapsed) {
        if (end > 0) {
          newText += value.text.substring(0, end);
        }
        newText += text;
        if (value.text.length > end) {
          newText += value.text.substring(end, value.text.length);
        }
      } else {
        newText = value.text.replaceRange(start, end, text);
      }
      _forwardController.value = value.copyWith(
        text: newText,
        selection: value.selection.copyWith(
          baseOffset: end + text.length,
          extentOffset: end + text.length,
        ),
      );
      if (mounted) setState(() {});
    }
  }

  Widget get emoticonPad => Visibility(
        visible: emoticonPadActive,
        child: EmotionPad(
          route: "comment",
          height: _keyboardHeight,
          controller: _forwardController,
        ),
      );

  void mentionPeople(context) {
    showDialog<User>(
      context: context,
      builder: (BuildContext context) => MentionPeopleDialog(),
    ).then((user) {
      if (_focusNode.canRequestFocus) _focusNode.requestFocus();
      if (user != null) {
        Future.delayed(const Duration(milliseconds: 250), () {
          insertText("<M ${user.id}>@${user.nickname}<\/M>");
        });
      }
    });
  }

  Widget get toolbar => SizedBox(
        height: suSetSp(40.0),
        child: Row(
          children: <Widget>[
            RoundedCheckbox(
              activeColor: ThemeUtils.currentThemeColor,
              value: commentAtTheMeanTime,
              onChanged: (value) {
                setState(() {
                  commentAtTheMeanTime = value;
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(
              "同时评论到微博",
              style: TextStyle(
                fontSize: suSetSp(16.0),
              ),
            ),
            Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _addImage,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: suSetSp(6.0),
                ),
                child: Icon(
                  Icons.add_photo_alternate,
                  size: suSetSp(26.0),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                mentionPeople(context);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: suSetSp(6.0),
                ),
                child: Icon(
                  Icons.alternate_email,
                  size: suSetSp(26.0),
                ),
              ),
            ),
            ToggleButton(
              activeWidget: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: suSetSp(6.0),
                ),
                child: Icon(
                  Icons.sentiment_very_satisfied,
                  size: suSetSp(26.0),
                  color: ThemeUtils.currentThemeColor,
                ),
              ),
              unActiveWidget: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: suSetSp(6.0),
                ),
                child: Icon(
                  Icons.sentiment_very_satisfied,
                  size: suSetSp(26.0),
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
              activeChanged: (bool active) {
                if (active && _focusNode.canRequestFocus) {
                  _focusNode.requestFocus();
                }
                updatePadStatus(context, active);
              },
              active: emoticonPadActive,
            ),
            !_forwarding
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: suSetSp(6.0),
                      ),
                      child: Icon(
                        Icons.send,
                        size: suSetSp(26.0),
                        color: ThemeUtils.currentThemeColor,
                      ),
                    ),
                    onTap: () {
                      _request(context);
                    },
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: suSetSp(14.0),
                    ),
                    child: SizedBox(
                      width: suSetSp(10.0),
                      height: suSetSp(10.0),
                      child: Constants.progressIndicator(strokeWidth: 2.0),
                    ),
                  ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) {
      emoticonPadActive = false;
    }
    _keyboardHeight = max(keyboardHeight, _keyboardHeight ?? 0);

    return Material(
      color: Colors.black38,
      child: Column(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          Container(
            color: Theme.of(context).cardColor,
            padding: EdgeInsets.only(
              bottom: !emoticonPadActive
                  ? MediaQuery.of(context).padding.bottom
                  : 0.0,
            ),
            child: Padding(
              padding: EdgeInsets.all(suSetSp(10.0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  textField,
                  toolbar,
                ],
              ),
            ),
          ),
          emoticonPad,
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
