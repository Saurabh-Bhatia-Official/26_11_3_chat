import 'dart:math';
import 'package:flutter/material.dart';
import '../../constants/game_assets.dart';

class SnakesLaddersView extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onChangeGame;
  final VoidCallback? onStopGame;
  final Map<String, dynamic>? initialGameState;
  final void Function(Map<String, dynamic> newState)? onGameStateChanged;
  final int myPlayerNumber; // 1 or 2
  final String opponentName;
  final String myUsername;
  final String player1Username;
  final String player2Username;

  const SnakesLaddersView({
    super.key,
    required this.onClose,
    this.onMinimize,
    this.onChangeGame,
    this.onStopGame,
    this.initialGameState,
    this.onGameStateChanged,
    this.myPlayerNumber = 1,
    this.opponentName = 'Opponent',
    this.myUsername = '',
    this.player1Username = '',
    this.player2Username = '',
  });

  @override
  State<SnakesLaddersView> createState() => _SnakesLaddersViewState();
}

class _SnakesLaddersViewState extends State<SnakesLaddersView> {
  int player1Pos = 1;
  int player2Pos = 1;
  int activePlayer = 1; // 1 or 2
  String currentTurnUsername = '';
  int lastDice = 1;
  bool isRolling = false;
  String? winner;
  String gameStatus = "Player 1's turn to roll 🎲";

  bool get isMyTurn {
    if (currentTurnUsername.isNotEmpty && widget.myUsername.isNotEmpty) {
      return currentTurnUsername.toLowerCase() == widget.myUsername.toLowerCase();
    }
    return activePlayer == widget.myPlayerNumber;
  }

  final Map<int, int> snakes = {
    99: 12,
    92: 53,
    75: 32,
    55: 14,
    38: 9,
  };

  final Map<int, int> ladders = {
    4: 25,
    13: 46,
    33: 70,
    42: 63,
    50: 89,
    62: 81,
  };

  @override
  void initState() {
    super.initState();
    currentTurnUsername = widget.player1Username.isNotEmpty ? widget.player1Username : widget.myUsername;
    if (widget.initialGameState != null) {
      _applyExternalState(widget.initialGameState!);
    } else {
      _updateStatus();
    }
  }

  @override
  void didUpdateWidget(covariant SnakesLaddersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGameState != null && widget.initialGameState != oldWidget.initialGameState) {
      _applyExternalState(widget.initialGameState!);
    }
  }

  void _applyExternalState(Map<String, dynamic> state) {
    setState(() {
      player1Pos = state['player1Pos'] ?? player1Pos;
      player2Pos = state['player2Pos'] ?? player2Pos;
      activePlayer = state['activePlayer'] ?? activePlayer;
      if (state['currentTurnUsername'] != null && state['currentTurnUsername'].toString().isNotEmpty) {
        currentTurnUsername = state['currentTurnUsername'].toString();
      } else {
        currentTurnUsername = activePlayer == 1 ? widget.player1Username : widget.player2Username;
      }
      lastDice = state['lastDice'] ?? lastDice;
      winner = state['winner'];
      gameStatus = state['gameStatus'] ?? gameStatus;
    });
  }

  void _updateStatus() {
    final activeUser = currentTurnUsername.isNotEmpty
        ? currentTurnUsername
        : (activePlayer == 1 ? widget.player1Username : widget.player2Username);
    if (isMyTurn) {
      gameStatus = "Your turn to roll! (@${widget.myUsername} - P$activePlayer) 🎲";
    } else {
      gameStatus = "Waiting for @$activeUser (P$activePlayer)... 🎲";
    }
  }

  void _rollDice() async {
    if (winner != null || isRolling || !isMyTurn) return;

    setState(() => isRolling = true);
    await Future.delayed(const Duration(milliseconds: 300));

    final roll = Random().nextInt(6) + 1;
    int current = activePlayer == 1 ? player1Pos : player2Pos;
    int next = current + roll;

    String note = "";
    if (next > 100) {
      next = current; // wait rule
      note = " (Need exact roll to reach 100)";
    } else {
      if (snakes.containsKey(next)) {
        final drop = snakes[next]!;
        note = " 🐍 Bit by Snake! $next ➔ $drop";
        next = drop;
      } else if (ladders.containsKey(next)) {
        final climb = ladders[next]!;
        note = " 🪜 Climbed Ladder! $next ➔ $climb";
        next = climb;
      }
    }

    String? newWinner = winner;
    String newStatus = "";
    int nextPlayer = activePlayer == 1 ? 2 : 1;
    final nextTurnUsername = nextPlayer == 1 ? widget.player1Username : widget.player2Username;
    final activeUser = currentTurnUsername.isNotEmpty
        ? currentTurnUsername
        : (activePlayer == 1 ? widget.player1Username : widget.player2Username);

    if (next == 100) {
      newWinner = activeUser.isNotEmpty ? "@$activeUser" : "Player $activePlayer";
      newStatus = "🏆 $newWinner Wins the Match!";
    } else {
      newStatus = "Rolled $roll.$note Turn: @$nextTurnUsername (P$nextPlayer)";
    }

    int newP1 = activePlayer == 1 ? next : player1Pos;
    int newP2 = activePlayer == 2 ? next : player2Pos;

    setState(() {
      lastDice = roll;
      isRolling = false;
      player1Pos = newP1;
      player2Pos = newP2;
      winner = newWinner;
      activePlayer = nextPlayer;
      currentTurnUsername = nextTurnUsername;
      gameStatus = newStatus;
    });

    widget.onGameStateChanged?.call({
      'player1Pos': newP1,
      'player2Pos': newP2,
      'activePlayer': nextPlayer,
      'currentTurnUsername': nextTurnUsername,
      'player1Username': widget.player1Username,
      'player2Username': widget.player2Username,
      'lastDice': roll,
      'winner': newWinner,
      'gameStatus': newStatus,
      'lastAction': '@$activeUser rolled a $roll',
    });
  }

  void _resetGame({bool notify = true}) {
    setState(() {
      player1Pos = 1;
      player2Pos = 1;
      activePlayer = 1;
      currentTurnUsername = widget.player1Username.isNotEmpty ? widget.player1Username : widget.myUsername;
      lastDice = 1;
      winner = null;
      _updateStatus();
    });

    if (notify) {
      widget.onGameStateChanged?.call({
        'player1Pos': 1,
        'player2Pos': 1,
        'activePlayer': 1,
        'currentTurnUsername': currentTurnUsername,
        'player1Username': widget.player1Username,
        'player2Username': widget.player2Username,
        'lastDice': 1,
        'winner': null,
        'gameStatus': "Game reset to start",
        'lastAction': 'Game reset',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stairs, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Snakes & Ladders 🪜',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMyTurn ? const Color(0xFF10B981).withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMyTurn ? const Color(0xFF10B981) : Colors.amber.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isMyTurn ? "Your turn (@${widget.myUsername})" : "Wait (@$currentTurnUsername)",
                      style: TextStyle(
                        color: isMyTurn ? const Color(0xFF10B981) : Colors.amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (widget.onChangeGame != null)
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Color(0xFF06B6D4), size: 20),
                      onPressed: widget.onChangeGame,
                      tooltip: 'Change Game',
                    ),
                  if (widget.onStopGame != null)
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFEF4444), size: 20),
                      onPressed: widget.onStopGame,
                      tooltip: 'Stop Game',
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                    onPressed: () => _resetGame(notify: true),
                    tooltip: 'Reset Game',
                  ),
                  if (widget.onMinimize != null)
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                      onPressed: widget.onMinimize,
                      tooltip: 'Minimize Game',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    onPressed: widget.onClose,
                    tooltip: 'Close Game View',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Status & Dice Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Cloud-hosted Dice Graphic Asset
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 4),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      GameCloudAssets.getDice(lastDice),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          '$lastDice',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    gameStatus,
                    style: TextStyle(
                      color: winner != null ? const Color(0xFFF59E0B) : Colors.white70,
                      fontWeight: winner != null ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMyTurn
                        ? (activePlayer == 1 ? const Color(0xFF06B6D4) : const Color(0xFFEC4899))
                        : Colors.white24,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: isRolling
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.casino, size: 14),
                  label: Text(
                    winner != null
                        ? 'Ended'
                        : (isMyTurn ? 'Roll Dice' : 'Wait (@$currentTurnUsername)'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: winner == null && !isRolling && isMyTurn ? _rollDice : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 100-Tile Grid
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155), width: 2),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                    itemCount: 100,
                    itemBuilder: (context, index) {
                      int row = 9 - (index ~/ 10);
                      int col = index % 10;
                      int tileNum;
                      if (row % 2 == 1) {
                        tileNum = (row * 10) + col + 1;
                      } else {
                        tileNum = (row * 10) + (9 - col) + 1;
                      }

                      bool isP1Here = player1Pos == tileNum;
                      bool isP2Here = player2Pos == tileNum;
                      bool isSnakeHead = snakes.containsKey(tileNum);
                      bool isLadderBottom = ladders.containsKey(tileNum);

                      Color tileBg = (row + col) % 2 == 0
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF0F172A);

                      if (isSnakeHead) tileBg = const Color(0xFFEF4444).withOpacity(0.2);
                      if (isLadderBottom) tileBg = const Color(0xFF10B981).withOpacity(0.2);

                      return Container(
                        decoration: BoxDecoration(
                          color: tileBg,
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 1,
                              left: 2,
                              child: Text(
                                '$tileNum',
                                style: const TextStyle(fontSize: 7, color: Colors.white38),
                              ),
                            ),
                            if (isSnakeHead)
                              const Positioned(
                                top: 1,
                                right: 1,
                                child: Text('🐍', style: TextStyle(fontSize: 8)),
                              ),
                            if (isLadderBottom)
                              const Positioned(
                                top: 1,
                                right: 1,
                                child: Text('🪜', style: TextStyle(fontSize: 8)),
                              ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isP1Here)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF06B6D4), // Cyan
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (isP1Here && isP2Here) const SizedBox(width: 1),
                                  if (isP2Here)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEC4899), // Pink
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
