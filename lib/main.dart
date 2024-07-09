import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:math';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polygon Coverage App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DrawingScreen(),
    );
  }
}

class DrawingScreen extends StatefulWidget {
  @override
  _DrawingScreenState createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  List<Offset> points = [];
  bool isPolygonClosed = false;
  List<Offset> coveragePoints = [];
  List<Offset> edgePoints = [];
  double coverageDensity = 10;

  void generateCoveragePoints() {
    if (points.length < 3) return;

    coveragePoints.clear();
    edgePoints.clear();
    Rect bounds = _calculateBounds();
    
    // Generate interior points
    for (double x = bounds.left; x <= bounds.right; x += bounds.width / coverageDensity) {
      for (double y = bounds.top; y <= bounds.bottom; y += bounds.height / coverageDensity) {
        if (_isPointInPolygon(Offset(x, y))) {
          coveragePoints.add(Offset(x, y));
        }
      }
    }

    // Generate edge points
    for (int i = 0; i < points.length; i++) {
      Offset start = points[i];
      Offset end = points[(i + 1) % points.length];
      double distance = (end - start).distance;
      int numberOfPoints = (distance / (bounds.longestSide / coverageDensity)).round();
      
      for (int j = 0; j <= numberOfPoints; j++) {
        double t = j / numberOfPoints;
        Offset point = Offset(
          start.dx + t * (end.dx - start.dx),
          start.dy + t * (end.dy - start.dy)
        );
        if (!point.dx.isNaN && !point.dy.isNaN) {
          edgePoints.add(point);
        }
      }
    }
  }

  Rect _calculateBounds() {
    if (points.isEmpty) return Rect.zero;
    double minX = points[0].dx, maxX = points[0].dx;
    double minY = points[0].dy, maxY = points[0].dy;
    for (Offset point in points) {
      if (!point.dx.isNaN && !point.dy.isNaN) {
        minX = min(minX, point.dx);
        maxX = max(maxX, point.dx);
        minY = min(minY, point.dy);
        maxY = max(maxY, point.dy);
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  bool _isPointInPolygon(Offset point) {
    bool isInside = false;
    int j = points.length - 1;
    for (int i = 0; i < points.length; i++) {
      if (points[i].dy < point.dy && points[j].dy >= point.dy ||
          points[j].dy < point.dy && points[i].dy >= point.dy) {
        if (points[i].dx + (point.dy - points[i].dy) / 
            (points[j].dy - points[i].dy) * (points[j].dx - points[i].dx) < point.dx) {
          isInside = !isInside;
        }
      }
      j = i;
    }
    return isInside;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Polygon Coverage App')),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTapUp: (details) {
                if (!isPolygonClosed) {
                  setState(() {
                    points.add(details.localPosition);
                  });
                }
              },
              child: CustomPaint(
                painter: PolygonPainter(
                  points: points,
                  isPolygonClosed: isPolygonClosed,
                  coveragePoints: coveragePoints,
                  edgePoints: edgePoints,
                ),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          if (isPolygonClosed)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Coverage Density'),
                  Slider(
                    value: coverageDensity,
                    min: 5,
                    max: 50,
                    divisions: 45,
                    label: coverageDensity.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        coverageDensity = value;
                        generateCoveragePoints();
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!isPolygonClosed)
            FloatingActionButton(
              onPressed: () {
                if (points.length >= 3) {
                  setState(() {
                    isPolygonClosed = true;
                    generateCoveragePoints();
                  });
                }
              },
              child: Icon(Icons.check),
              tooltip: 'Close Polygon',
            ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                points.clear();
                coveragePoints.clear();
                edgePoints.clear();
                isPolygonClosed = false;
              });
            },
            child: Icon(Icons.clear),
            tooltip: 'Clear Drawing',
          ),
        ],
      ),
    );
  }
}

class PolygonPainter extends CustomPainter {
  final List<Offset> points;
  final bool isPolygonClosed;
  final List<Offset> coveragePoints;
  final List<Offset> edgePoints;

  PolygonPainter({
    required this.points,
    required this.isPolygonClosed,
    required this.coveragePoints,
    required this.edgePoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final coveragePaint = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final edgePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 6  // Increased from 3 to 6
      ..strokeCap = StrokeCap.round;

    // Draw polygon lines
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
    if (isPolygonClosed && points.length > 2) {
      canvas.drawLine(points.last, points.first, paint);
    }

    // Draw coverage points
    canvas.drawPoints(PointMode.points, coveragePoints, coveragePaint);

    // Draw edge points
    for (var point in edgePoints) {
      canvas.drawCircle(point, 3, edgePaint);  // Draw circles instead of points for edge points
    }

    // Draw polygon vertices
    for (var point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}