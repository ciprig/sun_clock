// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import 'suncalc.dart';

enum _Element { text, skyTop, skyBottom }

final _lightTheme = {
  _Element.text: Color(0xFFEBC764),
  _Element.skyTop: Color(0xFFB0DDFA),
  _Element.skyBottom: Colors.white
};

final _darkTheme = {
  _Element.text: Color(0xFFCFCFCF),
  _Element.skyTop: Color(0xFF1D164C),
  _Element.skyBottom: Color(0xFF928DC7)
};

class SunClock extends StatefulWidget {
  const SunClock(this.model);

  final ClockModel model;

  @override
  _SunClockState createState() => _SunClockState();
}

class _SunClockState extends State<SunClock> {
  DateTime _dateTime = DateTime.now();
  Timer _timer;



  Map<String, DateTime> _sunTimes = Map();

  Map<_Element, Color> colors = _lightTheme;

  final showSeconds = false;

  get timerDuration =>
      showSeconds ? Duration(seconds: 1) : Duration(minutes: 1);

  final hasShadow = true;

  get sunShadow => hasShadow ? kElevationToShadow[8] : null;

  get moonShadow => hasShadow ? lightShadow() : null;

  get textShadow => hasShadow ? kElevationToShadow[24] : null;

  @override
  void initState() {
    super.initState();
    developer.log("time ${DateTime.now()} ${DateTime.now().timeZoneName}  ${DateTime.now().timeZoneOffset}");

    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();
  }

  @override
  void didUpdateWidget(SunClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void didChangeDependencies() {
    colors = Theme.of(context).brightness == Brightness.light
        ? _lightTheme
        : _darkTheme;
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

//      final now = DateTime.now();
//      final hour = (now.second * 24 / 60).truncate();
//      final minute = (now.second * 24 - hour * 60);
//      _dateTime = DateTime(now.year, 4, 15, hour, minute, now.second);

      _sunTimes = SunCalc().getTimes(_dateTime, 46.7712, 23.6236);
      // Update once per minute. If you want to update every second, use the
      // following code.
      _timer = showSeconds
          ? Timer(
              Duration(seconds: 1) -
                  Duration(milliseconds: _dateTime.millisecond),
              _updateTime,
            )
          : Timer(
              Duration(minutes: 1) -
                  Duration(seconds: _dateTime.second) -
                  Duration(milliseconds: _dateTime.millisecond),
              _updateTime,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: buildWithConstraints);
  }

  Widget buildWithConstraints(
      BuildContext context, BoxConstraints constraints) {
    final colors = Theme.of(context).brightness == Brightness.light
        ? _lightTheme
        : _darkTheme;

    return Container(
      decoration: _skyDecoration(colors),
      //color: colors[_Element.background],
      child: Center(
        child: Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: <Widget>[
            _buildSun(constraints.maxWidth, constraints.maxHeight),
            _buildMoon(constraints.maxWidth, constraints.maxHeight),
            _buildLandscape(constraints.maxWidth, constraints.maxHeight),
            _buildInfo(constraints.maxWidth, constraints.maxHeight),
          ],
        ),
      ),
    );
  }

  BoxDecoration _skyDecoration(Map<_Element, Color> colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        // 10% of the width, so there are ten blinds.
        colors: [colors[_Element.skyTop], colors[_Element.skyBottom]],
        // whitish to gray
        tileMode: TileMode.clamp, // repeats the gradient over the canvas
      ),
    );
  }

  Widget _buildSun(double maxWidth, double maxHeight) {
    final position = SunCalc().getPosition(_dateTime, 46.7712, 23.6236);

    final sunDiameter = maxWidth / 8;

    final width = maxWidth - sunDiameter;
    final height = maxHeight - sunDiameter;

    final left = width / 2 * (1 + sin(position.azimuth));

    final bottom = height * sin(position.altitude);
    final start = _sunTimes["sunrise"];
    final end = _sunTimes["sunsetStart"];


    final sunColor =  _dateTime.isAfter(start)&&_dateTime.isBefore(end)?Colors.amber:Colors.red;// colors[_Element.text] ;

    return AnimatedPositioned(
      duration: timerDuration,
      bottom: bottom,
      left: left,
      child: AnimatedContainer(
        duration: timerDuration * 15,
        width: sunDiameter,
        height: sunDiameter,
        decoration: BoxDecoration(
            boxShadow: sunShadow,
            color: sunColor,
            shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildMoon(double maxWidth, double maxHeight) {
    final position = SunCalc().getMoonPosition(_dateTime, 46.7712, 23.6236);

    final moonDiameter = maxWidth / 9;
    final width = maxWidth - moonDiameter;
    final height = maxHeight - moonDiameter;

    final left = width / 2 * (1 + sin(position.azimuth));

    final bottom = height * sin(position.altitude);

    return AnimatedPositioned(
        duration: timerDuration,
        bottom: bottom,
        left: left,
        child: Container(
          width: moonDiameter,
          height: moonDiameter,
          decoration: BoxDecoration(
              boxShadow: moonShadow,
              color: Colors.white24,
              shape: BoxShape.circle),
        ));
  }

  Widget _buildLandscape(double maxWidth, double maxHeight) {
    final mountainsPath = Theme.of(context).brightness == Brightness.light
        ? "assets/mountains_day.svg"
        : "assets/mountains_night.svg";
    return Positioned(
      bottom: 0,
      child: SvgPicture.asset(
        mountainsPath,
        width: maxWidth,
      ),
    );
  }

  Widget _buildInfo(double maxWidth, double maxHeight) {
    final time = DateFormat((widget.model.is24HourFormat ? 'HH' : 'hh') +
            (showSeconds ? ":mm:ss" : ":mm"))
        .format(_dateTime);

    final timeStyle = TextStyle(
        color: colors[_Element.text],
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w700,
        fontSize: maxWidth / 8,
        shadows: textShadow);

    final lineHeight = maxHeight / 128;

    return Positioned(
        bottom: maxHeight / 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(time, style: timeStyle),
            Container(
              width: maxWidth * 0.8,
              color: colors[_Element.text],
              height: lineHeight,
            ),
            _buildInfoDetailsRow(context, maxWidth, maxHeight),
          ],
        ));
  }

  Widget _buildInfoDetailsRow(
      BuildContext context, double maxWidth, double maxHeight) {
    final Locale locale = Localizations.localeOf(context);
    final String strLocale = "${locale.languageCode}_${locale.countryCode}";

    final colors = Theme.of(context).brightness == Brightness.light
        ? _lightTheme
        : _darkTheme;

    final detailStyle = TextStyle(
        color: colors[_Element.text],
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w700,
        fontSize: maxWidth / 40,
        shadows: kElevationToShadow[24]);

    final lineHeight = maxHeight / 128;

    final padding = EdgeInsets.only(
        left: maxWidth / 32,
        top: maxHeight / 32,
        right: maxWidth / 32,
        bottom: maxHeight / 32);

    final dot = Container(
      width: lineHeight,
      height: lineHeight,
      color: colors[_Element.text],
    );

    return DefaultTextStyle(
      style: detailStyle,
      child: Container(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
                padding: padding,
                child: Text(DateFormat.yMMMd(strLocale).format(_dateTime))),
            dot,
            Container(padding: padding, child: Text(widget.model.location)),
            dot,
            Container(
              padding: padding,
              child: _weatherDetailsRow(maxWidth, maxHeight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherDetailsRow(double maxWidth, double maxHeight) {
    final String temperatureMinMaxString =
        "${widget.model.highString}/${widget.model.lowString}";

    final iconSize = maxWidth / 40;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text("${widget.model.temperatureString} "),
        Icon(
          Icons.arrow_upward,
          color: colors[_Element.text],
          size: iconSize,
        ),
        Text(temperatureMinMaxString),
        Icon(
          Icons.arrow_downward,
          color: colors[_Element.text],
          size: iconSize,
        ),
      ],
    );
  }
}

lightShadow() {
  const Color _kKeyUmbraOpacity = Color(0x0C000000); // alpha = 0.2
  const Color _kKeyPenumbraOpacity = Color(0x09000000); // alpha = 0.14
  const Color _kAmbientShadowOpacity = Color(0x07000000); // alpha = 0.12

  return <BoxShadow>[
    BoxShadow(
        offset: Offset(0.0, 5.0),
        blurRadius: 6.0,
        spreadRadius: -3.0,
        color: _kKeyUmbraOpacity),
    BoxShadow(
        offset: Offset(0.0, 9.0),
        blurRadius: 12.0,
        spreadRadius: 1.0,
        color: _kKeyPenumbraOpacity),
    BoxShadow(
        offset: Offset(0.0, 3.0),
        blurRadius: 16.0,
        spreadRadius: 2.0,
        color: _kAmbientShadowOpacity),
  ];
}
