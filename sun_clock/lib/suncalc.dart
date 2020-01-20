import 'dart:math';

/// Converted to dart from SunCalc library:
///
/// (c) 2011-2015, Vladimir Agafonkin
/// SunCalc is a JavaScript library for calculating sun/moon position and light phases.
/// https://github.com/mourner/suncalc
class Coordinate {
  final double declination;
  final double rightAscension;

  ///distance in km
  final double distance;

  Coordinate({this.declination, this.rightAscension, this.distance = 0});
}

class Position {
  final double azimuth;
  final double altitude;
  final double distance;
  final double parallacticAngle;

  Position(
      {this.azimuth,
      this.altitude,
      this.distance = 0,
      this.parallacticAngle = 0});

  @override
  String toString() {
    return 'Position{azimuth: $azimuth, altitude: $altitude, distance: $distance, parallacticAngle: $parallacticAngle}';
  }
}

class Ilumination {
  final double fraction;
  final double phase;
  final double angle;

  Ilumination({this.fraction, this.phase, this.angle});
}

class SunCalc {
  static const _rad = pi / 180;

  /// sun calculations are based on http://aa.quae.nl/en/reken/zonpositie.html formulas

  /// date/time constants and conversions
  static const _dayMs = 1000 * 60 * 60 * 24, _J1970 = 2440588, _J2000 = 2451545;

  double _toJulian(DateTime date) {
    return date.millisecondsSinceEpoch / _dayMs - 0.5 + _J1970;
  }

  DateTime _fromJulian(double j) {
    return DateTime.fromMillisecondsSinceEpoch(((j + 0.5 - _J1970) * _dayMs).truncate());
  }

  double _toDays(DateTime date) {
    return _toJulian(date) - _J2000;
  }

  /// general calculations for position

  static const e = _rad * 23.4397; // obliquity of the Earth

  _rightAscension(l, b) {
    return atan2(sin(l) * cos(e) - tan(b) * sin(e), cos(l));
  }

  _declination(l, b) {
    return asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l));
  }

  _azimuth(H, phi, dec) {
    return atan2(sin(H), cos(H) * sin(phi) - tan(dec) * cos(phi));
  }

  _altitude(H, phi, dec) {
    return asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H));
  }

  _siderealTime(d, lw) {
    return _rad * (280.16 + 360.9856235 * d) - lw;
  }

  _astroRefraction(h) {
    if (h < 0) // the following formula works for positive altitudes only.
      h = 0; // if h = -0.08901179 a div/0 would occur.

    /// formula 16.4 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    /// 1.02 / tan(h + 10.26 / (h + 5.10)) h in degrees, result in arc minutes -> converted to rad:
    return 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179));
  }

  /// general sun calculations

  _solarMeanAnomaly(d) {
    return _rad * (357.5291 + 0.98560028 * d);
  }

  _eclipticLongitude(M) {
    var C = _rad *
            (1.9148 * sin(M) +
                0.02 * sin(2 * M) +
                0.0003 * sin(3 * M)), // equation of center
        P = _rad * 102.9372; // perihelion of the Earth

    return M + C + P + pi;
  }

  Coordinate _sunCoords(d) {
    var M = _solarMeanAnomaly(d), L = _eclipticLongitude(M);

    return Coordinate(
        declination: _declination(L, 0), rightAscension: _rightAscension(L, 0));
  }

  /// calculates sun position for a given date and latitude/longitude
  Position getPosition(DateTime date,double lat,double lng) {
    var lw = _rad * -lng,
        phi = _rad * lat,
        d = _toDays(date),
        c = _sunCoords(d),
        H = _siderealTime(d, lw) - c.rightAscension;

    return Position(
        azimuth: _azimuth(H, phi, c.declination),
        altitude: _altitude(H, phi, c.declination));
  }

  /// sun times configuration (angle, morning name, evening name)
  final times = [
    [-0.833, 'sunrise', 'sunset'],
    [-0.3, 'sunriseEnd', 'sunsetStart'],
    [-6, 'dawn', 'dusk'],
    [-12, 'nauticalDawn', 'nauticalDusk'],
    [-18, 'nightEnd', 'night'],
    [6, 'goldenHourEnd', 'goldenHour']
  ];

  /// adds a custom time to the times config
  void addTime(angle, riseName, setName) {
    times.add([angle, riseName, setName]);
  }

// calculations for sun times
  var _J0 = 0.0009;

  _julianCycle(d, lw) {
    return (d - _J0 - lw / (2 * pi)).round();
  }

  _approxTransit(Ht, lw, n) {
    return _J0 + (Ht + lw) / (2 * pi) + n;
  }

  _solarTransitJ(ds, M, L) {
    return _J2000 + ds + 0.0053 * sin(M) - 0.0069 * sin(2 * L);
  }

  _hourAngle(h, phi, d) {
    return acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)));
  }

  _observerAngle(height) {
    return -2.076 * sqrt(height) / 60;
  }

  /// returns set time for the given sun altitude
  getSetJ(h, lw, phi, dec, n, M, L) {
    var w = _hourAngle(h, phi, dec), a = _approxTransit(w, lw, n);
    return _solarTransitJ(a, M, L);
  }

  /// calculates sun times for a given date, latitude/longitude, and, optionally,
  /// the observer height (in meters) relative to the horizon
  Map<String,dynamic> getTimes(DateTime date,double lat,double lng, {double height = 0}) {
    var lw = _rad * -lng,
        phi = _rad * lat,
        dh = _observerAngle(height),
        d = _toDays(date),
        n = _julianCycle(d, lw),
        ds = _approxTransit(0, lw, n),
        M = _solarMeanAnomaly(ds),
        L = _eclipticLongitude(M),
        dec = _declination(L, 0),
        Jnoon = _solarTransitJ(ds, M, L),
        i,
        len,
        time,
        h0,
        Jset,
        Jrise;

    var result = {
      'solarNoon': _fromJulian(Jnoon),
      'nadir': _fromJulian(Jnoon - 0.5)
    };

    for (i = 0; i < times.length; i++) {
      time = times[i];
      h0 = (time[0] + dh) * _rad;

      Jset = getSetJ(h0, lw, phi, dec, n, M, L);
      Jrise = Jnoon - (Jset - Jnoon);

      result[time[1]] = _fromJulian(Jrise);
      result[time[2]] = _fromJulian(Jset);
    }

    return result;
  }

  /// moon calculations, based on http://aa.quae.nl/en/reken/hemelpositie.html formulas
  Coordinate moonCoords(d) {
    // geocentric ecliptic coordinates of the moon

    var L = _rad * (218.316 + 13.176396 * d), // ecliptic longitude
        M = _rad * (134.963 + 13.064993 * d), // mean anomaly
        F = _rad * (93.272 + 13.229350 * d), // mean distance

        l = L + _rad * 6.289 * sin(M), // longitude
        b = _rad * 5.128 * sin(F), // latitude
        dt = 385001 - 20905 * cos(M); // distance to the moon in km

    return Coordinate(
        declination: _declination(l, b),
        rightAscension: _rightAscension(l, b),
        distance: dt);
  }

  Position getMoonPosition(date, lat, lng) {
    var lw = _rad * -lng,
        phi = _rad * lat,
        d = _toDays(date),
        c = moonCoords(d),
        H = _siderealTime(d, lw) - c.rightAscension,
        h = _altitude(H, phi, c.declination),

        /// formula 14.1 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
        pa = atan2(sin(H),
            tan(phi) * cos(c.declination) - sin(c.declination) * cos(H));

    h = h + _astroRefraction(h); // altitude correction for refraction

    return Position(
        azimuth: _azimuth(H, phi, c.declination),
        altitude: h,
        distance: c.distance,
        parallacticAngle: pa);
  }

  /// calculations for illumination parameters of the moon,
  /// based on http://idlastro.gsfc.nasa.gov/ftp/pro/astro/mphase.pro formulas and
  /// Chapter 48 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
  getMoonIllumination(DateTime date) {
    var d = _toDays(date ?? DateTime.now()),
        s = _sunCoords(d),
        m = moonCoords(d),
        sdist = 149598000, // distance from Earth to Sun in km

        phi = acos(sin(s.declination) * sin(m.declination) +
            cos(s.declination) *
                cos(m.declination) *
                cos(s.rightAscension - m.rightAscension)),
        inc = atan2(sdist * sin(phi), m.distance - sdist * cos(phi)),
        angle = atan2(
            cos(s.declination) * sin(s.rightAscension - m.rightAscension),
            sin(s.declination) * cos(m.declination) -
                cos(s.declination) *
                    sin(m.declination) *
                    cos(s.rightAscension - m.rightAscension));

    return Ilumination(
        fraction: (1 + cos(inc)) / 2,
        phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / pi,
        angle: angle);
  }

  _hoursLater(DateTime date, h) {
    return DateTime.fromMillisecondsSinceEpoch(
        date.millisecondsSinceEpoch + h * _dayMs / 24);
  }

  /// calculations for moon rise/set times are based on http://www.stargazing.net/kepler/moonrise.html article
  getMoonTimes(DateTime date, lat, lng, inUTC) {
    var t = DateTime.fromMillisecondsSinceEpoch(date.millisecondsSinceEpoch);

    if (inUTC) {
      final DateTime utc = date.toUtc();
      t = DateTime(utc.year, utc.month, utc.day);
    } else {
      t = DateTime(date.year, date.month, date.day);
    }

    var hc = 0.133 * _rad,
        h0 = getMoonPosition(t, lat, lng).altitude - hc,
        h1,
        h2,
        rise,
        set,
        a,
        b,
        xe,
        ye,
        d,
        roots,
        x1,
        x2,
        dx;

    /// go in 2-hour chunks, each time seeing if a 3-point quadratic curve crosses zero (which means rise or set)
    for (var i = 1; i <= 24; i += 2) {
      h1 = getMoonPosition(_hoursLater(t, i), lat, lng).altitude - hc;
      h2 = getMoonPosition(_hoursLater(t, i + 1), lat, lng).altitude - hc;

      a = (h0 + h2) / 2 - h1;
      b = (h2 - h0) / 2;
      xe = -b / (2 * a);
      ye = (a * xe + b) * xe + h1;
      d = b * b - 4 * a * h1;
      roots = 0;

      if (d >= 0) {
        dx = sqrt(d) / (a.abs() * 2);
        x1 = xe - dx;
        x2 = xe + dx;
        if (x1.abs() <= 1) roots++;
        if (x2.abs() <= 1) roots++;
        if (x1 < -1) x1 = x2;
      }

      if (roots == 1) {
        if (h0 < 0)
          rise = i + x1;
        else
          set = i + x1;
      } else if (roots == 2) {
        rise = i + (ye < 0 ? x2 : x1);
        set = i + (ye < 0 ? x1 : x2);
      }

      if (rise && set) break;

      h0 = h2;
    }

    var result = Map();

    if (rise) result['rise'] = _hoursLater(t, rise);
    if (set) result['set'] = _hoursLater(t, set);

    if (!rise && !set) result[ye > 0 ? 'alwaysUp' : 'alwaysDown'] = true;

    return result;
  }
}
