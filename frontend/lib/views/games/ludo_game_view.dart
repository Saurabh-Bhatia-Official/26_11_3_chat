import 'dart:math';
import 'package:flutter/material.dart';

class LudoGameView extends StatefulWidget {
  final VoidCallback onClose;
  const LudoGameView({super.key, required this.onClose});

  @override
  State<LudoGameView> createState() => _LudoGameViewState();
}

class _LudoGameViewState extends State<LudoGameView> {
  int redScore = 0;
  int greenScore = 0;
  int currentDice = 6;
  String currentTurn = 'RED'; // RED or GREEN
  bool isRolling = false;
  String? winner;

  void _rollDice() async {
    if (winner != null || isRolling) return;
    setState(() => isRolling = true);
    await Future.delayed(const Duration(milliseconds: 350));

    final roll = Random().nextInt(6) + 1;
    setState(() {
      isRolling = false;
      currentDice = roll;

      if (currentTurn == 'RED') {
        redScore = min(56, redScore + roll);
        if (redScore >= 56) winner = 'RED (Player 1)';
        currentTurn = 'GREEN';
      } else {
        greenScore = min(56, greenScore + roll);
        if (greenScore >= 56) winner = 'GREEN (Player 2)';
        currentTurn = 'RED';
      }
    });
  }

  void _resetGame() {
    setState(() {
      redScore = 0;
      greenScore = 0;
      currentDice = 6;
      currentTurn = 'RED';
      winner = null;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.casino, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    'PlayTogether Ludo 🎲',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  winner != null
                      ? '🏆 $winner Wins!'
                      : 'Turn: $currentTurn • Last Roll: $currentDice',
                  style: TextStyle(
                    color: winner != null ? const Color(0xFFFBBF24) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentTurn == 'RED' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
                  label: Text('Roll $currentTurn'),
                  onPressed: winner == null && !isRolling ? _rollDice : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Ludo board stylized quadrants
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF475569), width: 3),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // RED Base
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('🔴 RED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('Progress: $redScore/56', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // GREEN Base
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('🟢 GREEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('Progress: $greenScore/56', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Center Cross Track
                      Container(
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text('Red track: $redScore', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                            const Icon(Icons.stars, color: Color(0xFFFBBF24)),
                            Text('Green track: $greenScore', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            // YELLOW Base
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text('🟡 YELLOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            // BLUE Base
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text('🔵 BLUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
