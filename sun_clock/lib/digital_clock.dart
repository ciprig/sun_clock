// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _Element { background, text, shadow, skyTop, skyBottom }

final _lightTheme = {
  _Element.background: Color(0xFF81B3FE),
  _Element.text: Color(0xFFEBC764C),
  _Element.shadow: Colors.black,
  _Element.skyTop: Color(0xFFB0DDFA),
  _Element.skyBottom: Colors.white
};

final _darkTheme = {
  _Element.background: Colors.black,
  _Element.text: Colors.white,
  _Element.shadow: Color(0xFF174EA6),
  _Element.skyTop: Color(0xFF1D164C),
  //_Element.sky40: Color(0xFF3B337E),
  _Element.skyBottom: Color(0xFF928DC7)
};

/// A basic digital clock.
///
/// You can do better than this!
class DigitalClock extends StatefulWidget {
  const DigitalClock(this.model);

  final ClockModel model;

  @override
  _DigitalClockState createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  DateTime _dateTime = DateTime.now();
  Timer _timer;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();
  }

  @override
  void didUpdateWidget(DigitalClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    widget.model.dispose();
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      // Cause the clock to rebuild when the model changes.
    });
  }

  void _updateTime() {
    setState(() {
      _dateTime = DateTime.now();
      // Update once per minute. If you want to update every second, use the
      // following code.
//      _timer = Timer(
//        Duration(minutes: 1) -
//            Duration(seconds: _dateTime.second) -
//            Duration(milliseconds: _dateTime.millisecond),
//        _updateTime,
//      );
      // Update once per second, but make sure to do it at the beginning of each
      // new second, so that the clock is accurate.
       _timer = Timer(
         Duration(seconds: 1) - Duration(milliseconds: _dateTime.millisecond),
         _updateTime,
       );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.light
        ? _lightTheme
        : _darkTheme;
    final hour =
        DateFormat(widget.model.is24HourFormat ? 'HH' : 'hh').format(_dateTime);
    final minute = DateFormat('mm').format(_dateTime);
    final fontSize = MediaQuery.of(context).size.width / 3.5;
    final offset = -fontSize / 7;
    final defaultStyle = TextStyle(
        color: colors[_Element.text],
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w900,
        fontSize: 103,
        shadows: kElevationToShadow[16]
//        [
//        Shadow(
//          blurRadius: 5,
//          color: colors[_Element.shadow],
//          offset: Offset(10, 10),
//        ),
//      ],
        );

//    TextStyle(
//      color: colors[_Element.text],
//      fontFamily: 'PressStart2P',
//      fontSize: fontSize,
//      shadows: [
//        Shadow(
//          blurRadius: 0,
//          color: colors[_Element.shadow],
//          offset: Offset(10, 10),
//        ),
//      ],
//    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // 10% of the width, so there are ten blinds.
          colors: [colors[_Element.skyTop], colors[_Element.skyBottom]],
          // whitish to gray
          tileMode: TileMode.clamp, // repeats the gradient over the canvas
        ),
      ),
      //color: colors[_Element.background],
      child: Center(
        child: DefaultTextStyle(
          style: defaultStyle,
          child: Stack(
            alignment: AlignmentDirectional.bottomCenter,
            children: <Widget>[
              buildSun(),
              Positioned(bottom: 100, child: Text("$hour:$minute")),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSun() {
    return AnimatedPositioned(
        duration: Duration(seconds: 5),
        top: 100,
        left: (_dateTime.second*10).toDouble(),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
              boxShadow: kElevationToShadow[8],
              color: Colors.orange,
              shape: BoxShape.circle),
        ));
  }
}
