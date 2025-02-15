// Import Flutter's material design library
import 'package:flutter/material.dart';

// Enum for hand position types
enum HandPositionType {
  handOne,
  handTwo,
}

// Extension to get display names for hand positions
extension HandPositionTypeExtension on HandPositionType {
  String get displayName {
    switch (this) {
      case HandPositionType.handOne:
        return 'Hand One';
      case HandPositionType.handTwo:
        return 'Hand Two';
    }
  }
}

// Entry point of the application
void main() {
  runApp(const MyApp());
}

// Root widget of the application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Imprint',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HandPosition {
  final Map<int, Offset> points;
  HandPosition(this.points);

  HandPosition.empty() : points = {};

  HandPosition copyWith() {
    return HandPosition(Map.from(points));
  }
}

class HandData {
  HandPosition? startPosition;
  HandPosition? finishPosition;

  HandData();

  bool get hasStartPosition => startPosition != null;
  bool get hasFinishPosition => finishPosition != null;
  void clear() {
    startPosition = null;
    finishPosition = null;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Store touch points
  final Map<int, TouchPoint> touchPoints = {};
  bool isRecordingLeftHand = true; // Track which hand we're recording

  // Store recorded positions
  final leftHandData = HandData();
  final rightHandData = HandData();

  // Store persistent paths
  final List<List<Offset>> leftHandPaths = [];
  final List<List<Offset>> rightHandPaths = [];

  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      touchPoints[event.pointer] = TouchPoint(
        position: event.localPosition,
        isLeftHand: isRecordingLeftHand,
      );
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    setState(() {
      if (touchPoints.containsKey(event.pointer)) {
        final oldPoint = touchPoints[event.pointer]!;
        touchPoints[event.pointer] = TouchPoint(
          position: event.localPosition,
          pathHistory: [...oldPoint.pathHistory, event.localPosition],
          isLeftHand: isRecordingLeftHand,
        );
      }
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (touchPoints.containsKey(event.pointer)) {
      final point = touchPoints[event.pointer]!;
      if (point.pathHistory.length > 1) {
        setState(() {
          if (point.isLeftHand) {
            leftHandPaths.add(List.from(point.pathHistory));
          } else {
            rightHandPaths.add(List.from(point.pathHistory));
          }
        });
      }
      setState(() {
        touchPoints.remove(event.pointer);
      });
    }
  }

  void _clearPoints() {
    setState(() {
      touchPoints.clear();
    });
  }

  void _toggleHand() {
    setState(() {
      isRecordingLeftHand = !isRecordingLeftHand;
      touchPoints.clear(); // Clear points when switching hands
    });
  }

  void _recordCurrentPosition(bool isStart) {
    if (touchPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No points to record! Place your fingers first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      // Create a new map with sequential indices (1-5) for the first 5 points
      final sortedPoints = touchPoints.entries.toList()
        ..sort((a, b) => a.value.position.dx.compareTo(b.value.position.dx));

      final positions = Map<int, Offset>.fromEntries(
        sortedPoints
            .take(5)
            .toList()
            .asMap()
            .entries
            .map((entry) => MapEntry(entry.key, entry.value.value.position)),
      );

      final handData = isRecordingLeftHand ? leftHandData : rightHandData;

      if (isStart) {
        handData.startPosition = HandPosition(positions);
      } else {
        handData.finishPosition = HandPosition(positions);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recorded ${isStart ? "start" : "finish"} position for ${isRecordingLeftHand ? "left" : "right"} hand',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearRecordedPositions() {
    setState(() {
      leftHandData.clear();
      rightHandData.clear();
    });
  }

  void _clearPaths(bool leftHand) {
    setState(() {
      if (leftHand) {
        leftHandPaths.clear();
      } else {
        rightHandPaths.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recording ${isRecordingLeftHand ? "Left" : "Right"} Hand'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _toggleHand,
            tooltip: 'Switch Hand',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearPoints,
            tooltip: 'Clear current points',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearRecordedPositions,
            tooltip: 'Clear all recorded positions',
          ),
        ],
      ),
      body: Column(
        children: [
          // Recording buttons at the top
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  'Recording ${isRecordingLeftHand ? "Left" : "Right"} Hand',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.flag),
                  label: const Text('Record Start'),
                  onPressed: () => _recordCurrentPosition(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.done_all),
                  label: const Text('Record Finish'),
                  onPressed: () => _recordCurrentPosition(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Clear Left Paths'),
                  onPressed: () => _clearPaths(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Clear Right Paths'),
                  onPressed: () => _clearPaths(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: Row(
              children: [
                // Touch area
                Expanded(
                  flex: 2,
                  child: Listener(
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    child: CustomPaint(
                      painter: TouchPainter(
                        touchPoints: touchPoints,
                        isRecordingLeftHand: isRecordingLeftHand,
                        leftHandPaths: leftHandPaths,
                        rightHandPaths: rightHandPaths,
                      ),
                      child: Container(
                        color: Colors.grey.withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
                // Data tables
                Expanded(
                  flex: 1,
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            'Recorded Positions',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          _buildRecordedPositionsTable(
                              'Left Hand', leftHandData),
                          const Divider(height: 32),
                          _buildRecordedPositionsTable(
                              'Right Hand', rightHandData),
                          const Divider(height: 32),
                          Text(
                            'Current Touch Points',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          DataTable(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('ID')),
                              DataColumn(label: Text('X')),
                              DataColumn(label: Text('Y')),
                            ],
                            rows: touchPoints.entries.map((entry) {
                              final point = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(Text(entry.key.toString())),
                                  DataCell(Text(
                                      point.position.dx.toStringAsFixed(1))),
                                  DataCell(Text(
                                      point.position.dy.toStringAsFixed(1))),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordedPositionsTable(String title, HandData handData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
          },
          children: [
            const TableRow(
              decoration: BoxDecoration(
                color: Colors.grey,
              ),
              children: [
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Point',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Start Position (x, y)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Finish Position (x, y)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            ...List.generate(5, (index) {
              final startPoint = handData.startPosition?.points[index];
              final finishPoint = handData.finishPosition?.points[index];

              return TableRow(
                children: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text((index + 1).toString()),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        startPoint != null
                            ? '(${startPoint.dx.toStringAsFixed(1)}, ${startPoint.dy.toStringAsFixed(1)})'
                            : '-',
                      ),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        finishPoint != null
                            ? '(${finishPoint.dx.toStringAsFixed(1)}, ${finishPoint.dy.toStringAsFixed(1)})'
                            : '-',
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}

class TouchPoint {
  final Offset position;
  final List<Offset> pathHistory;
  final bool isLeftHand;

  TouchPoint({
    required this.position,
    List<Offset>? pathHistory,
    required this.isLeftHand,
  }) : pathHistory = pathHistory ?? [position];

  TouchPoint copyWith({
    Offset? position,
    List<Offset>? pathHistory,
    bool? isLeftHand,
  }) {
    return TouchPoint(
      position: position ?? this.position,
      pathHistory: pathHistory ?? this.pathHistory,
      isLeftHand: isLeftHand ?? this.isLeftHand,
    );
  }
}

class TouchPainter extends CustomPainter {
  final Map<int, TouchPoint> touchPoints;
  final bool isRecordingLeftHand;
  final List<List<Offset>> leftHandPaths;
  final List<List<Offset>> rightHandPaths;

  TouchPainter({
    required this.touchPoints,
    required this.isRecordingLeftHand,
    required this.leftHandPaths,
    required this.rightHandPaths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftHandPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 30
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rightHandPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..strokeWidth = 30
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw persistent paths
    for (final path in leftHandPaths) {
      if (path.length > 1) {
        final pathObj = Path();
        pathObj.moveTo(path.first.dx, path.first.dy);
        for (var i = 1; i < path.length; i++) {
          pathObj.lineTo(path[i].dx, path[i].dy);
        }
        canvas.drawPath(pathObj, leftHandPaint);
      }
    }

    for (final path in rightHandPaths) {
      if (path.length > 1) {
        final pathObj = Path();
        pathObj.moveTo(path.first.dx, path.first.dy);
        for (var i = 1; i < path.length; i++) {
          pathObj.lineTo(path[i].dx, path[i].dy);
        }
        canvas.drawPath(pathObj, rightHandPaint);
      }
    }

    // Draw current touch points and their paths
    touchPoints.forEach((id, point) {
      final paint = Paint()
        ..color = (point.isLeftHand ? Colors.blue : Colors.red).withOpacity(0.3)
        ..strokeWidth = 30
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (point.pathHistory.length > 1) {
        final path = Path();
        path.moveTo(point.pathHistory.first.dx, point.pathHistory.first.dy);
        for (var i = 1; i < point.pathHistory.length; i++) {
          path.lineTo(point.pathHistory[i].dx, point.pathHistory[i].dy);
        }
        canvas.drawPath(path, paint);
      }

      // Draw the touch point
      canvas.drawCircle(
        point.position,
        15,
        Paint()
          ..color = point.isLeftHand ? Colors.blue : Colors.red
          ..style = PaintingStyle.fill,
      );
      
      // Draw the ID
      final textPainter = TextPainter(
        text: TextSpan(
          text: id.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        point.position.translate(-textPainter.width / 2, -textPainter.height / 2),
      );
    });
  }

  @override
  bool shouldRepaint(TouchPainter oldDelegate) {
    return true;
  }
}
