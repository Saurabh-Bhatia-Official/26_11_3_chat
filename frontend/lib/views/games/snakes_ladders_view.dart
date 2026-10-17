import 'dart:math';
import 'package:flutter/material.dart';

class SnakesLaddersView extends StatefulWidget {
  final VoidCallback onClose;
  const SnakesLaddersView({super.key, required this.onClose});

  @override
  State<SnakesLaddersView> createState() => _SnakesLaddersViewState();
}

class _SnakesLaddersViewState extends State<SnakesLaddersView> {
  int player1Pos = 1;
  int player2Pos = 1;
  int activePlayer = 1; // 1 or 2
  int lastDice = 1;
  bool isRolling = false;
  String? winner;
  String gameStatus = "Player 1's turn to roll 🎲";

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

  void _rollDice() async {
    if (winner != null || isRolling) return;

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
        note = " 🐍 Bit by Snake! Dropped from $next to $drop";
        next = drop;
      } else if (ladders.containsKey(next)) {
        final climb = ladders[next]!;
        note = " 🪜 Climbed Ladder from $next to $climb!";
        next = climb;
      }
    }

    setState(() {
      lastDice = roll;
      isRolling = false;
      if (activePlayer == 1) {
        player1Pos = next;
      } else {
        player2Pos = next;
      }

      if (next == 100) {
        winner = "Player $activePlayer";
        gameStatus = "🏆 Player $activePlayer Wins the Match!";
      } else {
        // Toggle turn
        activePlayer = activePlayer == 1 ? 2 : 1;
        gameStatus = "Rolled $roll.$note Next: Player $activePlayer's turn";
      }
    });
  }

  void _resetGame() {
    setState(() {
      player1Pos = 1;
      player2Pos = 1;
      activePlayer = 1;
      lastDice = 1;
      winner = null;
      gameStatus = "Player 1's turn to roll 🎲";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stairs, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  const Text(
                    'Snakes & Ladders (Saanp-Seedi) 🎲',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    onPressed: _resetGame,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status & Dice Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    gameStatus,
                    style: TextStyle(
                      color: winner != null ? const Color(0xFFF59E0B) : Colors.white70,
                      fontWeight: winner != null ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activePlayer == 1 ? const Color(0xFF06B6D4) : const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: isRolling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.casino, size: 16),
                  label: Text(
                    winner != null ? 'Match Ended' : 'Roll (P$activePlayer)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: winner == null && !isRolling ? _rollDice : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 100-Tile Grid
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155), width: 2),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
                    itemCount: 100,
                    itemBuilder: (context, index) {
                      // Snakes and ladders numbering runs bottom to top, alternating rows
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
                              top: 2,
                              left: 3,
                              child: Text(
                                '$tileNum',
                                style: const TextStyle(fontSize: 8, color: Colors.white38),
                              ),
                            ),
                            if (isSnakeHead)
                              const Positioned(
                                top: 2,
                                right: 2,
                                child: Text('🐍', style: TextStyle(fontSize: 10)),
                              ),
                            if (isLadderBottom)
                              const Positioned(
                                top: 2,
                                right: 2,
                                child: Text('🪜', style: TextStyle(fontSize: 10)),
                              ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isP1Here)
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF06B6D4), // Cyan
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (isP1Here && isP2Here) const SizedBox(width: 2),
                                  if (isP2Here)
                                    Container(
                                      width: 12,
                                      height: 12,
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
