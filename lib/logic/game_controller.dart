import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/piece.dart';
import '../constants.dart';
import '../utils/board_utils.dart';
import '../models/board_config.dart';
import '../logic/square_board_logic.dart' as square;
import '../logic/aadu_puli_logic.dart' as aadu;
import '../providers/background_audio_provider.dart';
import 'dart:math';

enum PlayerType { human, computer }
enum GameMode { pvp, pvc }
enum PlayerSide { tiger, goat }

class GameController extends ChangeNotifier {
  List<List<Point>> board = [];
  int placedGoats = 0;
  int capturedGoats = 0;
  bool isGoatMovementPhase = false;
  PieceType currentTurn = PieceType.goat;
  Point? selectedPiece;
  List<Point> validMoves = [];
  String? gameMessage;
  GameMode gameMode = GameMode.pvp;
  PlayerType tigerPlayer = PlayerType.human;
  PlayerType goatPlayer = PlayerType.human;
  PlayerSide playerSide = PlayerSide.tiger;
  Difficulty difficulty = Difficulty.easy;
  BoardType boardType = BoardType.square;
  BoardConfig? boardConfig;
  
  bool _isPaused = false;
  bool get isPaused => _isPaused;

  GameController() {
    resetGame();
  }

  void setBoardType(BoardType type) {
    boardType = type;
    resetGame();
  }

  void resetGame() {
    if (boardType == BoardType.square) {
      board = square.SquareBoardLogic.initializeBoard();
      boardConfig = null;
    } else {
      boardConfig = BoardUtils.getAaduPuliConfig();
      aadu.AaduPuliLogic.initializeBoard(boardConfig!);
      board = [];
    }
    placedGoats = 0;
    capturedGoats = 0;
    isGoatMovementPhase = false;
    currentTurn = PieceType.goat;
    selectedPiece = null;
    validMoves = [];
    gameMessage = null;
    notifyListeners();

    if (gameMode == GameMode.pvc) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isComputerTurn()) {
          makeComputerMove();
        }
      });
    }
  }

  int get maxGoats => boardType == BoardType.square ? 20 : 15;
  int get requiredCaptures => boardType == BoardType.square ? 5 : 5;

  void handlePointTap(Point point) {
    if (gameMessage != null) return;

    if (!_isHumanTurn()) return;

    if (!isGoatMovementPhase && currentTurn == PieceType.goat) {
      _placeGoat(point);
      debugPrint("Placed goat at ${point.x}, ${point.y}");
    } else {
      _handleMovement(point);
      debugPrint("Moved piece from ${selectedPiece?.x}, ${selectedPiece?.y} to ${point.x}, ${point.y}");
    }
    _playTurnAudio();
    _checkWinConditions();

    if (gameMode == GameMode.pvc && gameMessage == null && _isComputerTurn()) {
      Future.delayed(const Duration(milliseconds: 500), makeComputerMove);
      debugPrint("Computer's turn initiated");
    }
  }

  bool _isHumanTurn() {
    if (gameMode == GameMode.pvp) return true;
    if (currentTurn == PieceType.tiger && tigerPlayer == PlayerType.human) return true;
    if (currentTurn == PieceType.goat && goatPlayer == PlayerType.human) return true;
    return false;
  }

  bool _isComputerTurn() {
    if (gameMode != GameMode.pvc) return false;
    if (currentTurn == PieceType.tiger && tigerPlayer == PlayerType.computer) return true;
    if (currentTurn == PieceType.goat && goatPlayer == PlayerType.computer) return true;
    return false;
  }

  void makeComputerMove() {
    if (!_isComputerTurn() || gameMessage != null) return;

    if (boardType == BoardType.square) {
      _makeSquareComputerMove();
    } else {
      _makeAaduPuliComputerMove();
    }
    _playTurnAudio();
    _checkWinConditions();

    if (gameMode == GameMode.pvc && gameMessage == null && _isComputerTurn()) {
      Future.delayed(const Duration(milliseconds: 400), makeComputerMove);
    }
  }

  void _makeSquareComputerMove() {
    if (!isGoatMovementPhase && currentTurn == PieceType.goat) {
      final emptyPoints = [
        for (var row in board)
          for (var p in row)
            if (p.type == PieceType.empty) p
      ];
      if (emptyPoints.isEmpty) return;
      final selected = _selectGoatPlacement(emptyPoints);
      _placeGoat(selected);
      debugPrint("AI placed goat at ${selected.x}, ${selected.y}");
      return;
    }

    final moves = <Map<String, Point>>[];
    for (var row in board) {
      for (var piece in row.where((p) => p.type == currentTurn)) {
        final valid = square.SquareBoardLogic.getValidMoves(piece, board);
        for (var to in valid) {
          moves.add({'from': piece, 'to': to});
          debugPrint("AI found move: ${piece.x},${piece.y} → ${to.x},${to.y}");
        }
      }
    }
    if (moves.isEmpty) return;

    debugPrint("AI ($currentTurn) evaluating ${moves.length} moves");
    final move = _selectMoveBasedOnDifficulty(moves);
    debugPrint("AI chosen move: ${move['from']} → ${move['to']}");

    _executeMove(move['from']!, move['to']!);
        currentTurn = currentTurn == PieceType.tiger ? PieceType.goat : PieceType.tiger;
    selectedPiece = null;
    validMoves = [];
    notifyListeners();
  }

  void _makeAaduPuliComputerMove() {
    if (boardConfig == null) return;

    if (!isGoatMovementPhase && currentTurn == PieceType.goat) {
      final emptyPoints = boardConfig!.nodes.where((p) => p.type == PieceType.empty).toList();
      if (emptyPoints.isEmpty) return;
      final selected = _selectGoatPlacement(emptyPoints);
      _placeGoat(selected);
      debugPrint("AI placed goat at ${selected.id}");
      return;
    }

    final moves = <Map<String, Point>>[];
    for (final piece in boardConfig!.nodes.where((n) => n.type == currentTurn)) {
      final valid = aadu.AaduPuliLogic.getValidMoves(piece, boardConfig!);
      for (final to in valid) {
        moves.add({'from': piece, 'to': to});
        debugPrint("AI found move: ${piece.id} → ${to.id}");
      }
    }
    if (moves.isEmpty) return;
    final move = _selectMoveBasedOnDifficulty(moves);
    _executeMove(move['from']!, move['to']!);

        currentTurn = currentTurn == PieceType.tiger ? PieceType.goat : PieceType.tiger;
    selectedPiece = null;
    validMoves = [];
    notifyListeners();
  }

  bool _areAdjacent(Point a, Point b) => a.adjacentPoints.contains(b);



  int _calculateGoatSafetyScore(Point position) {
    int score = 0;
    score += position.adjacentPoints
        .where((p) => p.type == PieceType.goat)
        .length * 30;
    score -= position.adjacentPoints
        .where((p) => p.type == PieceType.tiger)
        .length * 40;
    if (boardType == BoardType.square) {
      if ((position.x == 0 || position.x == 4) &&
          (position.y == 0 || position.y == 4)) {
        score += 25;
      }
    }
    if (_moveBlocksTiger(position)) {
      score += 100;
    }
    return score;
  }

  int _goatDangerLevel(Point position) {
    int danger = 0;
    for (final adj in position.adjacentPoints) {
      if (adj.type == PieceType.tiger) {
        danger += 10 + _countFutureJumps(adj) * 5;
      }
    }
    return danger;
  }

  int _countTigerThreats(Point position) {
    int threats = 0;
    if (boardType == BoardType.square) {
      for (final tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
        for (final goat in position.adjacentPoints.where((p) => p.type == PieceType.goat)) {
          int dx = goat.x - tiger.x;
          int dy = goat.y - tiger.y;
          int jumpX = goat.x + dx;
          int jumpY = goat.y + dy;
          if (jumpX >= 0 && jumpX < 5 && jumpY >= 0 && jumpY < 5) {
            if (board[jumpX][jumpY] == position) {
              threats++;
            }
          }
        }
      }
    } else {
      for (final tiger in boardConfig!.nodes.where((n) => n.type == PieceType.tiger)) {
        for (final goat in tiger.adjacentPoints.where((p) => p.type == PieceType.goat)) {
          if (position.adjacentPoints.contains(goat)) {
            for (final landing in goat.adjacentPoints) {
              if (landing == position && aadu.AaduPuliLogic.isJumpTriple('${tiger.id},${goat.id},${position.id}')) {
                threats++;
              }
            }
          }
        }
      }
    }
    return threats;
  }

  bool _protectsGoat(Point position) {
    for (final goat in position.adjacentPoints.where((p) => p.type == PieceType.goat)) {
      if (_countTigerThreats(goat) > 0) {
        return true;
      }
    }
    return false;
  }

  int _calculateStrategicValue(Point position) {
    int value = 0;
    value += _countTigerThreats(position) * 150;
    if (_protectsGoat(position)) {
      value += 200;
    }
    value += position.adjacentPoints
        .where((p) => p.type == PieceType.goat)
        .length * 60;
    value -= position.adjacentPoints
        .where((p) => p.type == PieceType.tiger)
        .length * 50;
    if (boardType == BoardType.square) {
      final centerDist = (position.x - 2).abs() + (position.y - 2).abs();
      value -= centerDist * 20;
      if (placedGoats > 10) {
        if ((position.x == 0 || position.x == 4) && 
            (position.y == 0 || position.y == 4)) {
          value += 100;
        }
      }
    } else {
      if (position.adjacentPoints.length > 2) {
        value += 80;
      }
    }
    return value;
  }

  int _evaluateGoatMove(Map<String, Point> move) {
    int score = 0;
    final to = move['to']!;
    if (!_isGoatPositionSafe(to)) {
      score -= 2000;
    } else {
      score += 300;
    }
    score += _countTigerThreats(to) * 300;
    if (_protectsGoat(to)) {
      score += 500;
    }
    score += to.adjacentPoints
        .where((p) => p.type == PieceType.goat)
        .length * 100;
    for (final tiger in to.adjacentPoints.where((p) => p.type == PieceType.tiger)) {
      score -= _countFutureJumps(tiger) * 80;
    }
    if (boardType == BoardType.square) {
      if (placedGoats < 15) {
        final centerDist = (to.x - 2).abs() + (to.y - 2).abs();
        score -= centerDist * 25;
      }
    }
    return score;
  }

  Point _selectGoatPlacement(List<Point> emptyPoints) {
    final safePositions = emptyPoints.where((p) => _isGoatPositionSafe(p)).toList();

    List<Point> candidatePositions = safePositions.isNotEmpty ? safePositions : emptyPoints;

    candidatePositions.sort((a, b) {
      return _calculateStrategicValue(b).compareTo(_calculateStrategicValue(a));
    });

    switch (difficulty) {
      case Difficulty.easy:
        return candidatePositions[_randomInt(candidatePositions.length)];
      case Difficulty.medium:
        return candidatePositions.take(3).toList()[_randomInt(3)];
      case Difficulty.hard:
        return candidatePositions.first;
    }
  }

  bool _isGoatPositionSafe(Point position) {
    if (boardType == BoardType.square) {
      return _isGoatPositionSafeForSquare(position);
    } else {
      return _isGoatPositionSafeForAaduPuli(position);
    }
  }

  bool _isGoatPositionSafeForSquare(Point goatPosition) {
    for (final tiger in board.expand((row) => row).where((p) => p.type == PieceType.tiger)) {
      final dx = goatPosition.x - tiger.x;
      final dy = goatPosition.y - tiger.y;
      if (dx.abs() <= 1 && dy.abs() <= 1 && !(dx == 0 && dy == 0)) {
        final jumpX = goatPosition.x + dx;
        final jumpY = goatPosition.y + dy;
        if (jumpX >= 0 && jumpX < 5 && jumpY >= 0 && jumpY < 5) {
          if (board[jumpX][jumpY].type == PieceType.empty) {
            return false; 
          }
        }
      }
    }
    return true;
  }

  bool _isGoatPositionSafeForAaduPuli(Point goatPosition) {
    if (boardConfig == null) return true;
    for (final tiger in boardConfig!.nodes.where((n) => n.type == PieceType.tiger)) {
      if (goatPosition.adjacentPoints.contains(tiger)) {
        for (final landing in goatPosition.adjacentPoints) {
          if (landing == tiger || landing.type != PieceType.empty) continue;
          final key = '${tiger.id},${goatPosition.id},${landing.id}';
          if (aadu.AaduPuliLogic.isJumpTriple(key)) {
            return false; 
          }
        }
      }
    }
    return true;
  }

  bool _isJump(Point from, Point to) {
    return !_areAdjacent(from, to);
  }

  bool _moveBlocksTiger(Point to) {
    if (boardType == BoardType.square) {
      for (var row in board) {
        for (var tiger in row.where((p) => p.type == PieceType.tiger)) {
          for (final adj in tiger.adjacentPoints) {
            if (adj.type == PieceType.goat) {
              int dx = adj.x - tiger.x;
              int dy = adj.y - tiger.y;
              int jumpX = adj.x + dx;
              int jumpY = adj.y + dy;
              if (jumpX >= 0 && jumpX < 5 && jumpY >= 0 && jumpY < 5) {
                Point landing = board[jumpX][jumpY];
                if (landing.type == PieceType.empty &&
                    adj.adjacentPoints.contains(landing) &&
                    (to.x == landing.x && to.y == landing.y)) {
                  return true;
                }
              }
            }
          }
        }
      }
      return false;
    } else if (boardType == BoardType.aaduPuli) {
      if (boardConfig == null) return false;
      for (final tiger in boardConfig!.nodes.where((n) => n.type == PieceType.tiger)) {
        for (final goat in tiger.adjacentPoints.where((p) => p.type == PieceType.goat)) {
          for (final landing in goat.adjacentPoints) {
            if (landing == tiger || landing.type != PieceType.empty) continue;
            final key = '${tiger.id},${goat.id},${landing.id}';
            if (aadu.AaduPuliLogic.isJumpTriple(key) &&
                (to.id == landing.id)) {
              return true;
            }
          }
        }
      }
      return false;
    }
    return false;
  }

  int _evaluateMove(Point from, Point to, bool isTiger) {
    if (isTiger) {
      if (_isJump(from, to)) return 100 + _countFutureJumps(to) * 10;
      return _countFutureJumps(to) * 5 - from.adjacentPoints.where((p) => p.type == PieceType.goat).length;
    } else {
      int score = 0;
      if (_moveBlocksTiger(to)) score += 100;
      score += to.adjacentPoints.where((p) => p.type == PieceType.goat).length * 10;
      score -= from.adjacentPoints.where((p) => p.type == PieceType.tiger).length * 5;
      if (!to.adjacentPoints.any((p) => p.type == PieceType.tiger)) score += 20;
      return score;
    }
  }

  double _randomDouble() => Random().nextDouble();
  int _randomInt(int max) => Random().nextInt(max);

  Map<String, Point> _selectMoveBasedOnDifficulty(List<Map<String, Point>> moves) {
    final isGoat = currentTurn == PieceType.goat;

    if (isGoat) {
      final safeMoves = moves.where((m) => !_isGoatMoveDangerous(m)).toList();
      final dangerousMoves = moves.where(_isGoatMoveDangerous).toList();

      switch (difficulty) {
        case Difficulty.easy:
          if (safeMoves.isNotEmpty && _randomDouble() < 0.7) {
            return safeMoves[_randomInt(safeMoves.length)];
          }
          return moves[_randomInt(moves.length)];

        case Difficulty.medium:
          if (safeMoves.isNotEmpty) {
            safeMoves.sort((a, b) {
              final aValue = _calculateStrategicValue(a['to']!);
              final bValue = _calculateStrategicValue(b['to']!);
              final aSafety = _calculateGoatSafetyScore(a['to']!);
              final bSafety = _calculateGoatSafetyScore(b['to']!);
              if (aValue != bValue) return bValue.compareTo(aValue);
              return bSafety.compareTo(aSafety);
            });
            return safeMoves.first;
          }
          dangerousMoves.sort((a, b) {
            return _goatDangerLevel(a['to']!).compareTo(_goatDangerLevel(b['to']!));
          });
          return dangerousMoves.first;

        case Difficulty.hard:
          moves.sort((a, b) {
            final aScore = _evaluateGoatMove(a);
            final bScore = _evaluateGoatMove(b);
            return bScore.compareTo(aScore);
          });
          return moves.first;
      }
    }
    
    final isTiger = !isGoat;
    if (isTiger) {
      switch (difficulty) {
        case Difficulty.easy:
          final captures = moves.where((m) => _isJump(m['from']!, m['to']!)).toList();
          if (captures.isNotEmpty) return (captures..shuffle()).first;
          return (moves..shuffle()).first;

        case Difficulty.medium:
          final captures = moves.where((m) => _isJump(m['from']!, m['to']!)).toList();
          if (captures.isNotEmpty) return (captures..shuffle()).first;

          final threateningMoves = moves.where((m) =>
              m['to']!.adjacentPoints.any((adj) =>
                          adj.type == PieceType.goat &&
                  adj.adjacentPoints.any((adjAdj) =>
                      adjAdj.type == PieceType.empty))).toList();
          if (threateningMoves.isNotEmpty) return (threateningMoves..shuffle()).first;

          return (moves..shuffle()).first;

        case Difficulty.hard:
          moves.sort((a, b) {
            int aScore = _evaluateMove(a['from']!, a['to']!, true);
            int bScore = _evaluateMove(b['from']!, b['to']!, true);
            return bScore.compareTo(aScore);
          });
          return moves.first;
      }
    }
    return moves[_randomInt(moves.length)];
  }

  void _placeGoat(Point point) {
    final maxGoats = boardType == BoardType.square ? 20 : 15;
    if (point.type != PieceType.empty || placedGoats >= maxGoats) return;

    point.type = PieceType.goat;
    placedGoats++;

    if (placedGoats < maxGoats) {
      currentTurn = PieceType.tiger;
    } else {
      isGoatMovementPhase = true;
      currentTurn = PieceType.tiger;
    }
    selectedPiece = null;
    validMoves = [];
    notifyListeners();
  }

  void _handleMovement(Point point) {
    if (selectedPiece == null) {
      if (point.type == currentTurn) {
        selectedPiece = point;
        validMoves = _getValidMoves(point);
      }
    } else {
      if (validMoves.contains(point)) {
        _executeMove(selectedPiece!, point);
        currentTurn = currentTurn == PieceType.tiger ? PieceType.goat : PieceType.tiger;
      }
      selectedPiece = null;
      validMoves = [];
    }
    notifyListeners();
  }

  List<Point> _getValidMoves(Point piece) {
    if (boardType == BoardType.square) {
      return square.SquareBoardLogic.getValidMoves(piece, board);
    } else if (boardConfig != null) {
      return aadu.AaduPuliLogic.getValidMoves(piece, boardConfig!);
    }
    return [];
  }

  void _executeMove(Point from, Point to) {
    var result = boardType == BoardType.square
            ? square.SquareBoardLogic.executeMove(from, to, board)
            : aadu.AaduPuliLogic.executeMove(from, to, boardConfig!);

    if (result == square.MoveResult.capture ||
        result == square.MoveResult.captureWithMoreJumps ||
        result == aadu.MoveResult.capture) {
      capturedGoats++;
      selectedPiece = to;
      validMoves = _getValidMoves(to);
    } else {
      selectedPiece = null;
      validMoves = [];
    }
    notifyListeners();
  }

  void update(double dt) {}

  void movePiece(Point from, Point to) {
    _movePiece(from, to);
    notifyListeners();
  }

  void setGameMode(
    GameMode mode, {
    PlayerType? tigerControl,
    PlayerType? goatControl,
    PlayerSide? side,
    Difficulty? diff,
  }) {
    gameMode = mode;
    if (mode == GameMode.pvc) {
      if (side == PlayerSide.tiger) {
        tigerPlayer = PlayerType.human;
        goatPlayer = PlayerType.computer;
      } else {
        tigerPlayer = PlayerType.computer;
        goatPlayer = PlayerType.human;
      }
      playerSide = side ?? PlayerSide.tiger;
      difficulty = diff ?? Difficulty.easy;
    } else {
      tigerPlayer = PlayerType.human;
      goatPlayer = PlayerType.human;
      playerSide = PlayerSide.tiger;
      difficulty = Difficulty.easy;
    }
  }

  bool get isTigerTurn => currentTurn == PieceType.tiger;
  bool get isGoatTurn => currentTurn == PieceType.goat;

  void _checkWinConditions() {
    if (boardType == BoardType.square) {
      if (square.SquareBoardLogic.checkTigerWin(capturedGoats)) {
        _showGameOver('Tigers Win!');
      } else if (square.SquareBoardLogic.checkGoatWin(board)) {
        _showGameOver('Goats Win!');
      }
    } else {
      if (aadu.AaduPuliLogic.checkTigerWin(capturedGoats)) {
        _showGameOver('Tigers Win!');
      } else if (aadu.AaduPuliLogic.checkGoatWin(boardConfig!)) {
        _showGameOver('Goats Win!');
      }
    }
  }

  void _showGameOver(String message) {
    gameMessage = message;
    notifyListeners();
  }

  void _movePiece(Point from, Point to) {
    final isJump = (to.x - from.x).abs() == 2 || (to.y - from.y).abs() == 2;

    to.type = from.type;
    from.type = PieceType.empty;

    if (isJump) {
      int capturedX = from.x + (to.x - from.x) ~/ 2;
      int capturedY = from.y + (to.y - from.y) ~/ 2;
      if (board[capturedX][capturedY].type == PieceType.goat) {
        board[capturedX][capturedY].type = PieceType.empty;
        capturedGoats++;
      }
    }
  }

  void _playTurnAudio() {
    final context = _findContext();
    if (context == null) return;
    final audio = Provider.of<BackgroundAudioProvider>(context, listen: false);
    if (currentTurn == PieceType.goat) {
      audio.playGoatTurnAudio();
    } else if (currentTurn == PieceType.tiger) {
      audio.playTigerTurnAudio();
    }
  }

  BuildContext? _findContext() {
    try {
      return WidgetsBinding.instance.focusManager.primaryFocus?.context;
    } catch (_) {
      return null;
    }
  }

  int _countFutureJumps(Point tigerPos) {
    int jumpCount = 0;
    if (boardType == BoardType.square) {
      for (final adj in tigerPos.adjacentPoints) {
        if (adj.type == PieceType.goat) {
          int dx = adj.x - tigerPos.x;
          int dy = adj.y - tigerPos.y;
          int jumpX = adj.x + dx;
          int jumpY = adj.y + dy;
          if (jumpX >= 0 && jumpX < 5 && jumpY >= 0 && jumpY < 5) {
            Point landing = board[jumpX][jumpY];
            if (landing.type == PieceType.empty &&
                adj.adjacentPoints.contains(landing) &&
                tigerPos.adjacentPoints.contains(adj)) {
              jumpCount++;
            }
          }
        }
      }
    } else if (boardType == BoardType.aaduPuli && boardConfig != null) {
      for (final goat in tigerPos.adjacentPoints.where((p) => p.type == PieceType.goat)) {
        for (final landing in goat.adjacentPoints) {
          if (landing == tigerPos || landing.type != PieceType.empty) continue;
          final key = '${tigerPos.id},${goat.id},${landing.id}';
          if (aadu.AaduPuliLogic.isJumpTriple(key)) {
            jumpCount++;
          }
        }
      }
    }
    return jumpCount;
  }

  bool _isGoatMoveDangerous(Map<String, Point> move) {
    final to = move['to']!;
    
    for (final adj in to.adjacentPoints) {
      if (adj.type == PieceType.tiger) {
        if (boardType == BoardType.square) {
          int dx = to.x - adj.x;
          int dy = to.y - adj.y;
          int jumpX = to.x + dx;
          int jumpY = to.y + dy;
          if (jumpX >= 0 && jumpX < 5 && jumpY >= 0 && jumpY < 5) {
            Point landing = board[jumpX][jumpY];
            if (landing.type == PieceType.empty &&
                adj.adjacentPoints.contains(landing)) {
              return true; 
            }
          }
        } else if (boardType == BoardType.aaduPuli) {
          for (final landing in to.adjacentPoints) {
            if (landing == adj || landing.type != PieceType.empty) continue;
            final key = '${adj.id},${to.id},${landing.id}';
            if (aadu.AaduPuliLogic.isJumpTriple(key)) {
              return true; 
            }
          }
        }
      }
    }
    return false;
  }

  bool isComputerTurn() => _isComputerTurn();

  void pauseGame() {
    _isPaused = true;
    notifyListeners();
  }

  void resumeGame() {
    _isPaused = false;
    notifyListeners();
  }

  void scheduleComputerMove() {
    if (gameMessage == null && isComputerTurn()) {
      Future.delayed(const Duration(milliseconds: 500), makeComputerMove);
    }
  }
}