import 'dart:math';
import 'package:flutter/material.dart';
import '../../constants/game_assets.dart';

class LudoGameView extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onChangeGame;
  final VoidCallback? onStopGame;
  final Map<String, dynamic>? initialGameState;
  final void Function(Map<String, dynamic> newState)? onGameStateChanged;
  final String myPlayer; // 'RED' or 'GREEN'
  final String opponentName;
  final String myUsername;
  final String player1Username;
  final String player2Username;

  const LudoGameView({
    super.key,
    required this.onClose,
    this.onMinimize,
    this.onChangeGame,
    this.onStopGame,
    this.initialGameState,
    this.onGameStateChanged,
    this.myPlayer = 'RED',
    this.opponentName = 'Opponent',
    this.myUsername = '',
    this.player1Username = '',
    this.player2Username = '',
  });

  @override
  State<LudoGameView> createState() => _LudoGameViewState();
}

class _LudoGameViewState extends State<LudoGameView> {
  int redScore = 0;
  int greenScore = 0;
  int currentDice = 6;
  String currentTurn = 'RED'; // RED or GREEN
  String currentTurnUsername = '';
  bool isRolling = false;
  String? winner;

  @override
  void initState() {
    super.initState();
    currentTurnUsername = widget.player1Username.isNotEmpty ? widget.player1Username : widget.myUsername;
    if (widget.initialGameState != null) {
      _applyExternalState(widget.initialGameState!);
    }
  }

  @override
  void didUpdateWidget(covariant LudoGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGameState != null && widget.initialGameState != oldWidget.initialGameState) {
      _applyExternalState(widget.initialGameState!);
    }
  }

  void _applyExternalState(Map<String, dynamic> state) {
    setState(() {
      redScore = state['redScore'] ?? redScore;
      greenScore = state['greenScore'] ?? greenScore;
      currentDice = state['currentDice'] ?? currentDice;
      currentTurn = state['currentTurn'] ?? currentTurn;
      winner = state['winner'];
      currentTurnUsername = state['currentTurnUsername'] ??
          (currentTurn == 'RED' ? widget.player1Username : widget.player2Username);
    });
  }

  bool get isMyTurn {
    if (currentTurnUsername.isNotEmpty && widget.myUsername.isNotEmpty) {
      return currentTurnUsername.toLowerCase() == widget.myUsername.toLowerCase();
    }
    return currentTurn == widget.myPlayer;
  }

  void _rollDice() async {
    if (winner != null || isRolling || !isMyTurn) return;
    setState(() => isRolling = true);
    await Future.delayed(const Duration(milliseconds: 300));

    final roll = Random().nextInt(6) + 1;
    String nextTurn = currentTurn;
    String? newWinner = winner;
    int newRed = redScore;
    int newGreen = greenScore;

    if (currentTurn == 'RED') {
      newRed = min(56, redScore + roll);
      if (newRed >= 56) newWinner = widget.player1Username.isNotEmpty ? widget.player1Username : 'RED';
      nextTurn = 'GREEN';
    } else {
      newGreen = min(56, greenScore + roll);
      if (newGreen >= 56) newWinner = widget.player2Username.isNotEmpty ? widget.player2Username : 'GREEN';
      nextTurn = 'RED';
    }

    final nextTurnUsername = (nextTurn == 'RED')
        ? (widget.player1Username.isNotEmpty ? widget.player1Username : widget.myUsername)
        : (widget.player2Username.isNotEmpty ? widget.player2Username : widget.opponentName);

    setState(() {
      isRolling = false;
      currentDice = roll;
      redScore = newRed;
      greenScore = newGreen;
      winner = newWinner;
      currentTurn = nextTurn;
      currentTurnUsername = nextTurnUsername;
    });

    widget.onGameStateChanged?.call({
      'game': 'LUDO',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'redScore': newRed,
      'greenScore': newGreen,
      'currentDice': roll,
      'currentTurn': nextTurn,
      'player1Username': widget.player1Username,
      'player2Username': widget.player2Username,
      'currentTurnUsername': nextTurnUsername,
      'winner': newWinner,
      'lastAction': '@${widget.myUsername} rolled a $roll',
    });
  }

  void _resetGame({bool notify = true}) {
    setState(() {
      redScore = 0;
      greenScore = 0;
      currentDice = 6;
      currentTurn = 'RED';
      currentTurnUsername = widget.player1Username.isNotEmpty ? widget.player1Username : widget.myUsername;
      winner = null;
    });

    if (notify) {
      widget.onGameStateChanged?.call({
        'redScore': 0,
        'greenScore': 0,
        'currentDice': 6,
        'currentTurn': 'RED',
        'currentTurnUsername': currentTurnUsername,
        'player1Username': widget.player1Username,
        'player2Username': widget.player2Username,
        'winner': null,
        'lastAction': 'Ludo game reset',
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
            color: const Color(0xFF10B981).withOpacity(0.12),
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
                  const Icon(Icons.casino, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Ludo 🎲',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMyTurn ? const Color(0xFF10B981).withOpacity(0.2) : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMyTurn ? const Color(0xFF10B981) : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isMyTurn ? "Your turn (@${widget.myUsername})" : "Turn: @$currentTurnUsername ($currentTurn)",
                      style: TextStyle(
                        color: isMyTurn ? const Color(0xFF10B981) : Colors.white70,
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

          // Control & Dice bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      GameCloudAssets.getDice(currentDice),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          '$currentDice',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    winner != null
                        ? '🏆 @$winner Wins!'
                        : 'Roll: $currentDice • ${isMyTurn ? "Your turn (@${widget.myUsername})!" : "Waiting for @$currentTurnUsername..."}',
                    style: TextStyle(
                      color: winner != null ? const Color(0xFFFBBF24) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMyTurn
                        ? (currentTurn == 'RED' ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                        : Colors.white12,
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
                    isMyTurn ? 'Roll Dice' : 'Wait (@$currentTurnUsername)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: winner == null && !isRolling && isMyTurn ? _rollDice : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Board quadrants
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF475569), width: 2),
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
                                      Text(
                                        '🔴 RED ${widget.player1Username.isNotEmpty ? "(@${widget.player1Username})" : ""}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text('Progress: $redScore/56', style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
                                      Text(
                                        '🟢 GREEN ${widget.player2Username.isNotEmpty ? "(@${widget.player2Username})" : ""}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text('Progress: $greenScore/56', style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text('Red: $redScore', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                            const Icon(Icons.stars, color: Color(0xFFFBBF24), size: 16),
                            Text('Green: $greenScore', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
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
                                  child: Text('🟡 YELLOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
                                  child: Text('🔵 BLUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
