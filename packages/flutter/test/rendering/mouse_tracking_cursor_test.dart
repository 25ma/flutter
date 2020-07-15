// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:collection' show LinkedHashMap;
import 'dart:ui' as ui;
import 'dart:ui' show PointerChange;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../flutter_test_alternative.dart';

typedef MethodCallHandler = Future<dynamic> Function(MethodCall call);

_TestGestureFlutterBinding _binding = _TestGestureFlutterBinding();

void _ensureTestGestureBinding() {
  _binding ??= _TestGestureFlutterBinding();
  assert(GestureBinding.instance != null);
}

typedef SimpleAnnotationFinder = Iterable<MouseTrackerAnnotation> Function(Offset offset);

void main() {
  MethodCallHandler _methodCallHandler;

  // Only one of `logCursors` and `cursorHandler` should be specified.
  void _setUpMouseTracker({
    SimpleAnnotationFinder annotationFinder,
    List<_CursorUpdateDetails> logCursors,
    MethodCallHandler cursorHandler,
  }) {
    assert(logCursors == null || cursorHandler == null);
    _methodCallHandler = logCursors != null
      ? (MethodCall call) async {
        logCursors.add(_CursorUpdateDetails.wrap(call));
        return;
      }
      : cursorHandler;
    final MouseTracker mouseTracker = MouseTracker(
      GestureBinding.instance.pointerRouter,
      (Offset offset) => LinkedHashMap<MouseTrackerAnnotation, Matrix4>.fromEntries(
        annotationFinder(offset).map(
          (MouseTrackerAnnotation annotation) => MapEntry<MouseTrackerAnnotation, Matrix4>(annotation, Matrix4.identity()),
        ),
      ),
    );
    RendererBinding.instance.initMouseTracker(mouseTracker);
  }

  setUp(() {
    _ensureTestGestureBinding();
    _binding.postFrameCallbacks.clear();
    SystemChannels.mouseCursor.setMockMethodCallHandler((MethodCall call) async {
      if (_methodCallHandler != null)
        return _methodCallHandler(call);
    });
  });

  tearDown(() {
    SystemChannels.mouseCursor.setMockMethodCallHandler(null);
  });

  test('Should work on platforms that does not support mouse cursor', () async {
    const MouseTrackerAnnotation annotation = MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing);

    _setUpMouseTracker(
      annotationFinder: (Offset position) => <MouseTrackerAnnotation>[annotation],
      cursorHandler: (MethodCall call) async {
        return null;
      },
    );

    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    // Passes if no errors are thrown
  });

  test('pointer is added and removed out of any annotations', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    MouseTrackerAnnotation annotation;
    _setUpMouseTracker(
      annotationFinder: (Offset position) => <MouseTrackerAnnotation>[if (annotation != null) annotation],
      logCursors: logCursors,
    );

    // Pointer is added outside of the annotation.
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.basic.kind),
    ]);
    logCursors.clear();

    // Pointer moves into the annotation
    annotation = const MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing);
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(5.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.grabbing.kind),
    ]);
    logCursors.clear();

    // Pointer moves within the annotation
    annotation = const MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing);
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(10.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
    ]);
    logCursors.clear();

    // Pointer moves out of the annotation
    annotation = null;
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.basic.kind),
    ]);
    logCursors.clear();

    // Pointer is removed outside of the annotation.
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.remove, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, const <_CursorUpdateDetails>[
    ]);
  });

  test('pointer is added and removed in an annotation', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    MouseTrackerAnnotation annotation;
    _setUpMouseTracker(
      annotationFinder: (Offset position) => <MouseTrackerAnnotation>[if (annotation != null) annotation],
      logCursors: logCursors,
    );

    // Pointer is added in the annotation.
    annotation = const MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing);
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.grabbing.kind),
    ]);
    logCursors.clear();

    // Pointer moves out of the annotation
    annotation = null;
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(5.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.basic.kind),
    ]);
    logCursors.clear();

    // Pointer moves around out of the annotation
    annotation = null;
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(10.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
    ]);
    logCursors.clear();

    // Pointer moves back into the annotation
    annotation = const MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing);
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.grabbing.kind),
    ]);
    logCursors.clear();

    // Pointer is removed within the annotation.
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.remove, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
    ]);
  });

  test('pointer change caused by new frames', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    MouseTrackerAnnotation annotation;
    _setUpMouseTracker(
      annotationFinder: (Offset position) => <MouseTrackerAnnotation>[if (annotation != null) annotation],
      logCursors: logCursors,
    );

    // Pointer is added outside of the annotation.
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.basic.kind),
    ]);
    logCursors.clear();

    // Synthesize a new frame while changing annotation
    annotation = const MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing);
    _binding.scheduleMouseTrackerPostFrameCheck();
    _binding.flushPostFrameCallbacks(Duration.zero);

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.grabbing.kind),
    ]);
    logCursors.clear();

    // Synthesize a new frame without changing annotation
    annotation = const MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing);
    _binding.scheduleMouseTrackerPostFrameCheck();

    expect(logCursors, <_CursorUpdateDetails>[
    ]);
    logCursors.clear();

    // Pointer is removed outside of the annotation.
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.remove, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
    ]);
  });

  test('The first annotation with non-deferring cursor is used', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    List<MouseTrackerAnnotation> annotations;
    _setUpMouseTracker(
      annotationFinder: (Offset position) sync* { yield* annotations; },
      logCursors: logCursors,
    );

    annotations = <MouseTrackerAnnotation>[
      const MouseTrackerAnnotation(cursor: MouseCursor.defer),
      const MouseTrackerAnnotation(cursor: SystemMouseCursors.click),
      const MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing),
    ];
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.click.kind),
    ]);
    logCursors.clear();

    // Remove
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.remove, const Offset(5.0, 0.0)),
    ]));
  });

  test('Annotations with deferring cursors are ignored', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    List<MouseTrackerAnnotation> annotations;
    _setUpMouseTracker(
      annotationFinder: (Offset position) sync* { yield* annotations; },
      logCursors: logCursors,
    );

    annotations = <MouseTrackerAnnotation>[
      const MouseTrackerAnnotation(cursor: MouseCursor.defer),
      const MouseTrackerAnnotation(cursor: MouseCursor.defer),
      const MouseTrackerAnnotation(cursor: SystemMouseCursors.grabbing),
    ];
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.grabbing.kind),
    ]);
    logCursors.clear();

    // Remove
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.remove, const Offset(5.0, 0.0)),
    ]));
  });

  test('Finding no annotation is equivalent to specifying default cursor', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    MouseTrackerAnnotation annotation;
    _setUpMouseTracker(
      annotationFinder: (Offset position) => <MouseTrackerAnnotation>[if (annotation != null) annotation],
      logCursors: logCursors,
    );

    // Pointer is added outside of the annotation.
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.basic.kind),
    ]);
    logCursors.clear();

    // Pointer moved to an annotation specified with the default cursor
    annotation = const MouseTrackerAnnotation(cursor: SystemMouseCursors.basic);
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(5.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
    ]);
    logCursors.clear();

    // Pointer moved to no annotations
    annotation = null;
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
    ]);
    logCursors.clear();

    // Remove
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.remove, const Offset(0.0, 0.0)),
    ]));
  });

  test('Removing a pointer resets it back to the default cursor', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    MouseTrackerAnnotation annotation;
    _setUpMouseTracker(
      annotationFinder: (Offset position) => <MouseTrackerAnnotation>[if (annotation != null) annotation],
      logCursors: logCursors,
    );

    // Pointer is added to the annotation, then removed
    annotation = const MouseTrackerAnnotation(cursor: SystemMouseCursors.click);
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
      _pointerData(PointerChange.hover, const Offset(5.0, 0.0)),
      _pointerData(PointerChange.remove, const Offset(5.0, 0.0)),
    ]));

    logCursors.clear();

    // Pointer is added out of the annotation
    annotation = null;
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 0, kind: SystemMouseCursors.basic.kind),
    ]);
    logCursors.clear();
  });

  test('Pointing devices display cursors separately', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    _setUpMouseTracker(
      annotationFinder: (Offset position) sync* {
        if (position.dx > 200) {
          yield const MouseTrackerAnnotation(cursor: SystemMouseCursors.forbidden);
        } else if (position.dx > 100) {
          yield const MouseTrackerAnnotation(cursor: SystemMouseCursors.click);
        } else {}
      },
      logCursors: logCursors,
    );

    // Pointers are added outside of the annotation.
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0), device: 1),
      _pointerData(PointerChange.add, const Offset(0.0, 0.0), device: 2),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 1, kind: SystemMouseCursors.basic.kind),
      _CursorUpdateDetails.activateSystemCursor(device: 2, kind: SystemMouseCursors.basic.kind),
    ]);
    logCursors.clear();

    // Pointer 1 moved to cursor "click"
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(101.0, 0.0), device: 1),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 1, kind: SystemMouseCursors.click.kind),
    ]);
    logCursors.clear();

    // Pointer 2 moved to cursor "click"
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(102.0, 0.0), device: 2),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 2, kind: SystemMouseCursors.click.kind),
    ]);
    logCursors.clear();

    // Pointer 2 moved to cursor "forbidden"
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.hover, const Offset(202.0, 0.0), device: 2),
    ]));

    expect(logCursors, <_CursorUpdateDetails>[
      _CursorUpdateDetails.activateSystemCursor(device: 2, kind: SystemMouseCursors.forbidden.kind),
    ]);
    logCursors.clear();

    // Remove
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.remove, const Offset(0.0, 0.0)),
    ]));
  });
}

ui.PointerData _pointerData(
  PointerChange change,
  Offset logicalPosition, {
  int device = 0,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) {
  return ui.PointerData(
    change: change,
    physicalX: logicalPosition.dx * ui.window.devicePixelRatio,
    physicalY: logicalPosition.dy * ui.window.devicePixelRatio,
    kind: kind,
    device: device,
  );
}

class _CursorUpdateDetails extends MethodCall {
  const _CursorUpdateDetails(String method, Map<String, dynamic> arguments)
    : assert(arguments != null),
      super(method, arguments);

  _CursorUpdateDetails.wrap(MethodCall call)
    : super(call.method, Map<String, dynamic>.from(call.arguments as Map<dynamic, dynamic>));

  _CursorUpdateDetails.activateSystemCursor({int device, String kind})
    : this('activateSystemCursor', <String, dynamic>{'device': device, 'kind': kind});
  @override
  Map<String, dynamic> get arguments => super.arguments as Map<String, dynamic>;

  @override
  bool operator ==(dynamic other) {
    if (identical(other, this))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is _CursorUpdateDetails
        && other.method == method
        && other.arguments.length == arguments.length
        && other.arguments.entries.every(
          (MapEntry<String, dynamic> entry) =>
            arguments.containsKey(entry.key) && arguments[entry.key] == entry.value,
        );
  }

  @override
  int get hashCode => hashValues(method, arguments);

  @override
  String toString() {
    return '_CursorUpdateDetails(method: $method, arguments: $arguments)';
  }
}

class _TestGestureFlutterBinding extends BindingBase
    with SchedulerBinding, ServicesBinding, GestureBinding, SemanticsBinding, RendererBinding {
  @override
  void initInstances() {
    super.initInstances();
    postFrameCallbacks = <void Function(Duration)>[];
  }

  SchedulerPhase _overridePhase;
  @override
  SchedulerPhase get schedulerPhase => _overridePhase ?? super.schedulerPhase;

  // Manually schedule a post-frame check.
  //
  // In real apps this is done by the renderer binding, but in tests we have to
  // bypass the phase assertion of [MouseTracker.schedulePostFrameCheck].
  void scheduleMouseTrackerPostFrameCheck() {
    final SchedulerPhase lastPhase = _overridePhase;
    _overridePhase = SchedulerPhase.persistentCallbacks;
    mouseTracker.schedulePostFrameCheck();
    _overridePhase = lastPhase;
  }

  List<void Function(Duration)> postFrameCallbacks;

  // Proxy post-frame callbacks.
  @override
  void addPostFrameCallback(void Function(Duration) callback) {
    postFrameCallbacks.add(callback);
  }

  void flushPostFrameCallbacks(Duration duration) {
    for (final void Function(Duration) callback in postFrameCallbacks) {
      callback(duration);
    }
    postFrameCallbacks.clear();
  }
}
