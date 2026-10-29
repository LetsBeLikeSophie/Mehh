part of 'sort_screen.dart';

/// 끌어서 여러 장 선택, 가장자리에서 밀면 뒤로
extension _Paint on _SortScreenState {
  String? _photoAt(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(global));
    for (final e in result.path) {
      final t = e.target;
      if (t is RenderMetaData && t.metaData is String) {
        return t.metaData as String;
      }
    }
    return null;
  }

  void _paintStart(Offset global) {
    final width = MediaQuery.sizeOf(context).width;
    if (global.dx < backEdge || global.dx > width - backEdge) {
      _edgeFrom = global;
      _edgeDx = 0;
      return;
    }
    final id = _photoAt(global);
    if (id == null) return;
    _painted.clear();
    _paintTo = !_markedNow.contains(id);
    _paint(id);
  }

  void _paintMove(Offset global) {
    if (_edgeFrom case final from?) {
      _edgeDx = global.dx - from.dx;
      return;
    }
    if (_paintTo == null) return;
    final id = _photoAt(global);
    if (id == null || id == _paintLast) return;
    // 빨리 끌어 건너뛴 사진도: 화면 순서로 지난 사진과 지금 사진 사이를 모두
    final a = _order.indexOf(_paintLast ?? id), b = _order.indexOf(id);
    if (a < 0 || b < 0) {
      if (!_painted.contains(id)) _paint(id);
    } else {
      for (var i = a < b ? a : b; i <= (a < b ? b : a); i++) {
        if (!_painted.contains(_order[i])) _paint(_order[i]);
      }
    }
    _paintLast = id;
  }

  void _paint(String id) {
    _painted.add(id);
    // 끌어서 고른 것도 직접 고른 사진
    _paintTo! ? _chosen.add(id) : _chosen.remove(id);
    _paintLast = id;
    // X 버튼과 같은 결과: 켜면 정리(X), 끄면 킵
    ref.read(decisionsProvider.notifier).set([
      id,
    ], _paintTo! ? DecisionState.toTrash : DecisionState.keep);
  }

  void _paintEnd(double? velocity) {
    // 가장자리에서 안쪽으로 충분히(또는 빠르게) 밀었으면 뒤로
    if (_edgeFrom != null &&
        (_edgeDx.abs() > backSwipeDistance || (velocity ?? 0).abs() > 600)) {
      _edgeFrom = null;
      Navigator.of(context).maybePop();
      return;
    }
    _edgeFrom = null;
    _paintTo = null;
    _paintLast = null;
    _painted.clear();
  }
}
