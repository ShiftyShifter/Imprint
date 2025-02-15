// Import Flutter's material design library
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

// Entry point of the application
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

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
      home: const TouchTracker(),
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

  HandData clone() {
    final clone = HandData();
    if (startPosition != null) {
      final startPoints = <int, Offset>{};
      for (var i = 0; i < startPosition!.points.length; i++) {
        if (startPosition!.points[i] != null) {
          startPoints[i] = startPosition!.points[i]!.translate(0, 0);
        }
      }
      clone.startPosition = HandPosition(startPoints);
    }
    if (finishPosition != null) {
      final finishPoints = <int, Offset>{};
      for (var i = 0; i < finishPosition!.points.length; i++) {
        if (finishPosition!.points[i] != null) {
          finishPoints[i] = finishPosition!.points[i]!.translate(0, 0);
        }
      }
      clone.finishPosition = HandPosition(finishPoints);
    }
    return clone;
  }

  void copyFrom(HandData other) {
    if (other.startPosition != null) {
      final startPoints = <int, Offset>{};
      for (var i = 0; i < other.startPosition!.points.length; i++) {
        if (other.startPosition!.points[i] != null) {
          startPoints[i] = other.startPosition!.points[i]!.translate(0, 0);
        }
      }
      startPosition = HandPosition(startPoints);
    } else {
      startPosition = null;
    }

    if (other.finishPosition != null) {
      final finishPoints = <int, Offset>{};
      for (var i = 0; i < other.finishPosition!.points.length; i++) {
        if (other.finishPosition!.points[i] != null) {
          finishPoints[i] = other.finishPosition!.points[i]!.translate(0, 0);
        }
      }
      finishPosition = HandPosition(finishPoints);
    } else {
      finishPosition = null;
    }
  }
}

class TouchTracker extends StatefulWidget {
  const TouchTracker({super.key});

  @override
  State<TouchTracker> createState() => _TouchTrackerState();
}

class _TouchTrackerState extends State<TouchTracker>
    with SingleTickerProviderStateMixin {
  final Map<int, TouchPoint> touchPoints = {};
  final List<List<Offset>> leftHandPaths = [];
  final List<List<Offset>> rightHandPaths = [];
  bool isRecordingLeftHand = true;
  late TabController _tabController;
  bool isDataPanelExpanded = true;

  // Vector editing state
  HandData leftHandData = HandData();
  HandData rightHandData = HandData();
  double _scale = 1.0;
  double _rotation = 0.0;
  HandData? _activeHandData;
  int? _activePointIndex;
  bool _isDragging = false;
  bool? _isStartPoint;
  Offset? _selectedPoint;

  // Scroll and zoom state
  final TransformationController _transformationController = TransformationController();
  double _viewScale = 1.0;

  // Undo/redo stacks
  final List<HandData> _undoStack = [];
  final List<HandData> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _saveState() {
    _undoStack.add(_activeHandData!.clone());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;

    final lastState = _undoStack.removeLast();
    _redoStack.add(_activeHandData!.clone());

    setState(() {
      if (_activeHandData == leftHandData) {
        leftHandData.copyFrom(lastState);
      } else {
        rightHandData.copyFrom(lastState);
      }
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    final nextState = _redoStack.removeLast();
    _undoStack.add(_activeHandData!.clone());

    setState(() {
      if (_activeHandData == leftHandData) {
        leftHandData.copyFrom(nextState);
      } else {
        rightHandData.copyFrom(nextState);
      }
    });
  }

  void _handleVectorDragStart(
      HandData handData, int pointIndex, bool isStart, Offset position) {
    setState(() {
      _activeHandData = handData;
      _activePointIndex = pointIndex;
      _isStartPoint = isStart;
      _isDragging = true;
      _selectedPoint = position;
      _saveState();
    });
  }

  void _handleVectorDragUpdate(Offset position) {
    if (!_isDragging || _activeHandData == null || _activePointIndex == null)
      return;

    setState(() {
      if (_isStartPoint!) {
        _activeHandData!.startPosition!.points[_activePointIndex!] = position;
      } else {
        _activeHandData!.finishPosition!.points[_activePointIndex!] = position;
      }
      _selectedPoint = position;
    });
  }

  void _handleVectorDragEnd() {
    setState(() {
      _isDragging = false;
      _selectedPoint = null;
      _activeHandData = null;
      _activePointIndex = null;
      _isStartPoint = null;
    });
  }

  void _handleScale(double scale) {
    if (_activeHandData == null) return;

    _saveState();
    setState(() {
      _scale = scale;
      final center = _calculateCenter(_activeHandData!);

      // Scale points around center
      for (var i = 0; i < 5; i++) {
        var start = _activeHandData!.startPosition?.points[i];
        var finish = _activeHandData!.finishPosition?.points[i];

        if (start != null) {
          start = _scalePoint(start, center, scale);
          _activeHandData!.startPosition!.points[i] = start;
        }

        if (finish != null) {
          finish = _scalePoint(finish, center, scale);
          _activeHandData!.finishPosition!.points[i] = finish;
        }
      }
    });
  }

  void _handleRotation(double angle) {
    if (_activeHandData == null) return;

    _saveState();
    setState(() {
      _rotation = angle;
      final center = _calculateCenter(_activeHandData!);

      // Rotate points around center
      for (var i = 0; i < 5; i++) {
        var start = _activeHandData!.startPosition?.points[i];
        var finish = _activeHandData!.finishPosition?.points[i];

        if (start != null) {
          start = _rotatePoint(start, center, angle);
          _activeHandData!.startPosition!.points[i] = start;
        }

        if (finish != null) {
          finish = _rotatePoint(finish, center, angle);
          _activeHandData!.finishPosition!.points[i] = finish;
        }
      }
    });
  }

  Offset _calculateCenter(HandData handData) {
    double sumX = 0, sumY = 0;
    int count = 0;

    for (var i = 0; i < 5; i++) {
      final start = handData.startPosition?.points[i];
      final finish = handData.finishPosition?.points[i];

      if (start != null) {
        sumX += start.dx;
        sumY += start.dy;
        count++;
      }

      if (finish != null) {
        sumX += finish.dx;
        sumY += finish.dy;
        count++;
      }
    }

    return count > 0 ? Offset(sumX / count, sumY / count) : Offset.zero;
  }

  Offset _scalePoint(Offset point, Offset center, double scale) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    return Offset(
      center.dx + dx * scale,
      center.dy + dy * scale,
    );
  }

  Offset _rotatePoint(Offset point, Offset center, double angle) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(
      center.dx + dx * cos - dy * sin,
      center.dy + dx * sin + dy * cos,
    );
  }

  Widget _buildVectorControls() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoStack.isEmpty ? null : _undo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _redoStack.isEmpty ? null : _redo,
            tooltip: 'Redo',
          ),
          const VerticalDivider(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scale: '),
              SizedBox(
                width: 200,
                child: Slider(
                  value: _scale,
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  label: '${_scale.toStringAsFixed(2)}x',
                  onChanged: (value) => _handleScale(value),
                ),
              ),
            ],
          ),
          const VerticalDivider(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rotation: '),
              SizedBox(
                width: 200,
                child: Slider(
                  value: _rotation,
                  min: -math.pi,
                  max: math.pi,
                  divisions: 36,
                  label: '${(_rotation * 180 / math.pi).toStringAsFixed(0)}°',
                  onChanged: (value) => _handleRotation(value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVectorView() {
    return Column(
      children: [
        _buildVectorControls(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left hand view
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Left Hand',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 800, // Fixed width in pixels
                          height: 600, // Fixed height in pixels
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: const Size(800, 600),
                                painter: GridPainter(
                                  scale: _scale,
                                  gridSize: 50.0,
                                ),
                              ),
                              GestureDetector(
                                onPanDown: (details) {
                                  final point = _findNearestPoint(details.localPosition, leftHandData);
                                  if (point != null) {
                                    _handleVectorDragStart(leftHandData, point.pointIndex, point.isStart, details.localPosition);
                                  }
                                },
                                onPanUpdate: (details) {
                                  _handleVectorDragUpdate(details.localPosition);
                                },
                                onPanEnd: (_) {
                                  _handleVectorDragEnd();
                                },
                                child: CustomPaint(
                                  size: const Size(800, 600),
                                  painter: VectorPainter(
                                    handData: leftHandData,
                                    color: Colors.blue,
                                    selectedPoint: _selectedPoint,
                                    isDragging: _isDragging && _activeHandData == leftHandData,
                                    scale: _scale,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 100), // 100px gap
                    // Right hand view
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Right Hand',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 800, // Fixed width in pixels
                          height: 600, // Fixed height in pixels
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: const Size(800, 600),
                                painter: GridPainter(
                                  scale: _scale,
                                  gridSize: 50.0,
                                ),
                              ),
                              GestureDetector(
                                onPanDown: (details) {
                                  final point = _findNearestPoint(details.localPosition, rightHandData);
                                  if (point != null) {
                                    _handleVectorDragStart(rightHandData, point.pointIndex, point.isStart, details.localPosition);
                                  }
                                },
                                onPanUpdate: (details) {
                                  _handleVectorDragUpdate(details.localPosition);
                                },
                                onPanEnd: (_) {
                                  _handleVectorDragEnd();
                                },
                                child: CustomPaint(
                                  size: const Size(800, 600),
                                  painter: VectorPainter(
                                    handData: rightHandData,
                                    color: Colors.red,
                                    selectedPoint: _selectedPoint,
                                    isDragging: _isDragging && _activeHandData == rightHandData,
                                    scale: _scale,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  VectorPoint? _findNearestPoint(Offset position, HandData handData) {
    const hitTestRadius = 20.0;
    VectorPoint? nearest;
    double minDistance = double.infinity;

    for (var i = 0; i < 5; i++) {
      final start = handData.startPosition?.points[i];
      final finish = handData.finishPosition?.points[i];

      if (start != null) {
        final distance = (position - start).distance;
        if (distance < hitTestRadius && distance < minDistance) {
          minDistance = distance;
          nearest = VectorPoint(i, true);
        }
      }

      if (finish != null) {
        final distance = (position - finish).distance;
        if (distance < hitTestRadius && distance < minDistance) {
          minDistance = distance;
          nearest = VectorPoint(i, false);
        }
      }
    }

    return nearest;
  }

  void _handlePointerDown(PointerDownEvent event) {
    print('Pointer down: ${event.pointer} at ${event.localPosition}');
    setState(() {
      touchPoints[event.pointer] = TouchPoint(
        position: event.localPosition,
        pathHistory: [event.localPosition],
        isLeftHand: isRecordingLeftHand,
      );
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    print('Pointer move: ${event.pointer} at ${event.localPosition}');
    setState(() {
      if (touchPoints.containsKey(event.pointer)) {
        final oldPoint = touchPoints[event.pointer]!;
        touchPoints[event.pointer] = TouchPoint(
          position: event.localPosition,
          pathHistory: [...oldPoint.pathHistory, event.localPosition],
          isLeftHand: oldPoint.isLeftHand,
        );
      }
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    print('Pointer up: ${event.pointer}');
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
    final handData = isRecordingLeftHand ? leftHandData : rightHandData;
    final points = <int, Offset>{};

    final currentHandPoints = touchPoints.entries
        .where((entry) => entry.value.isLeftHand == isRecordingLeftHand)
        .toList();

    if (currentHandPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No points to record! Place your fingers first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Sort points by x-coordinate
    currentHandPoints
        .sort((a, b) => a.value.position.dx.compareTo(b.value.position.dx));

    // Take up to 5 points
    for (var i = 0; i < currentHandPoints.length && i < 5; i++) {
      points[i] = currentHandPoints[i].value.position;
    }

    setState(() {
      if (isStart) {
        handData.startPosition = HandPosition(points);
      } else {
        handData.finishPosition = HandPosition(points);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recorded ${isStart ? "start" : "finish"} position for ${isRecordingLeftHand ? "left" : "right"} hand (${points.length} points)',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Imprint'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearPoints,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Record', icon: Icon(Icons.touch_app)),
            Tab(text: 'Edit Vectors', icon: Icon(Icons.edit)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Touch recording view
          Column(
            children: [
              // Control bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ToggleButtons(
                      isSelected: [isRecordingLeftHand, !isRecordingLeftHand],
                      onPressed: (index) {
                        setState(() {
                          isRecordingLeftHand = index == 0;
                        });
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Left'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('Right'),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flag, size: 18),
                        label: const Text('Start'),
                        onPressed: () => _recordCurrentPosition(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Finish'),
                        onPressed: () => _recordCurrentPosition(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cleaning_services, size: 18),
                        label: Text(
                            'Clear ${isRecordingLeftHand ? "Left" : "Right"}'),
                        onPressed: () => _clearPaths(isRecordingLeftHand),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isRecordingLeftHand ? Colors.orange : Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(isDataPanelExpanded
                          ? Icons.chevron_right
                          : Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          isDataPanelExpanded = !isDataPanelExpanded;
                        });
                      },
                      tooltip:
                          '${isDataPanelExpanded ? "Hide" : "Show"} Data Panel',
                    ),
                  ],
                ),
              ),
              // Touch area and data panel
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Listener(
                        onPointerDown: _handlePointerDown,
                        onPointerMove: _handlePointerMove,
                        onPointerUp: _handlePointerUp,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: Colors.grey.withOpacity(0.1),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: TouchPainter(
                              touchPoints: touchPoints,
                              isRecordingLeftHand: isRecordingLeftHand,
                              leftHandPaths: leftHandPaths,
                              rightHandPaths: rightHandPaths,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isDataPanelExpanded) ...[
                      SizedBox(
                        width: 300,
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
                                        DataCell(Text(point.position.dx
                                            .toStringAsFixed(1))),
                                        DataCell(Text(point.position.dy
                                            .toStringAsFixed(1))),
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
                  ],
                ),
              ),
            ],
          ),
          // Vector editing view
          _buildVectorView(),
        ],
      ),
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
        point.position
            .translate(-textPainter.width / 2, -textPainter.height / 2),
      );
    });
  }

  @override
  bool shouldRepaint(TouchPainter oldDelegate) {
    return true;
  }
}

class VectorPainter extends CustomPainter {
  final HandData handData;
  final Color color;
  final Offset? selectedPoint;
  final bool isDragging;
  final double scale;
  static const double controlPointRadius = 10.0;
  static const double selectedPointRadius = 15.0;
  static const double vectorWidth = 3.0;

  VectorPainter({
    required this.handData,
    required this.color,
    this.selectedPoint,
    this.isDragging = false,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (handData.startPosition == null || handData.finishPosition == null) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = vectorWidth / scale
      ..style = PaintingStyle.stroke;

    final controlPaint = Paint()
      ..color = color
      ..strokeWidth = 2 / scale
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw vectors between corresponding points
    for (var i = 0; i < handData.startPosition!.points.length; i++) {
      if (!handData.finishPosition!.points.containsKey(i)) continue;

      final start = handData.startPosition!.points[i]!;
      final finish = handData.finishPosition!.points[i]!;

      // Draw vector line
      canvas.drawLine(start, finish, paint);

      // Draw control points
      final startRadius = (selectedPoint == start ? selectedPointRadius : controlPointRadius) / scale;
      final finishRadius = (selectedPoint == finish ? selectedPointRadius : controlPointRadius) / scale;

      canvas.drawCircle(start, startRadius, controlPaint);
      canvas.drawCircle(finish, finishRadius, controlPaint);
      canvas.drawCircle(start, startRadius - 1 / scale, fillPaint);
      canvas.drawCircle(finish, finishRadius - 1 / scale, fillPaint);

      // Draw point numbers
      final textPainter = TextPainter(
        text: TextSpan(
          text: (i + 1).toString(),
          style: TextStyle(
            color: color,
            fontSize: 12 / scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      // Draw number at start point
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          start.dx - textPainter.width / 2,
          start.dy - textPainter.height / 2,
        ),
      );

      // Draw number at finish point
      textPainter.paint(
        canvas,
        Offset(
          finish.dx - textPainter.width / 2,
          finish.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(VectorPainter oldDelegate) {
    return oldDelegate.handData != handData ||
        oldDelegate.color != color ||
        oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.scale != scale;
  }
}

class VectorPoint {
  final int pointIndex;
  final bool isStart;

  VectorPoint(this.pointIndex, this.isStart);
}

class GridPainter extends CustomPainter {
  final double scale;
  final double gridSize;

  GridPainter({
    required this.scale,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1.0;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw measurements
    final textStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10 / scale,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw x-axis measurements
    for (double x = 0; x <= size.width; x += gridSize * 2) {
      textPainter.text = TextSpan(
        text: '${(x).toStringAsFixed(0)}mm',
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, 0));
    }

    // Draw y-axis measurements
    for (double y = 0; y <= size.height; y += gridSize * 2) {
      textPainter.text = TextSpan(
        text: '${(y).toStringAsFixed(0)}mm',
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y));
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.gridSize != gridSize;
  }
}
