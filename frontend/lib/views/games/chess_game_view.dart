import 'package:flutter/material.dart';

class ChessGameView extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onChangeGame;
  final VoidCallback? onStopGame;
  final Map<String, dynamic>? initialGameState;
  final void Function(Map<String, dynamic> newState)? onGameStateChanged;
  final String playerColor; // 'WHITE' or 'BLACK'
  final String opponentName;
  final String myUsername;
  final String player1Username;
  final String player2Username;

  const ChessGameView({
    super.key,
    required this.onClose,
    this.onMinimize,
    this.onChangeGame,
    this.onStopGame,
    this.initialGameState,
    this.onGameStateChanged,
    this.playerColor = 'WHITE',
    this.opponentName = 'Opponent',
    this.myUsername = '',
    this.player1Username = '',
    this.player2Username = '',
  });

  @override
  State<ChessGameView> createState() => _ChessGameViewState();
}

class _ChessGameViewState extends State<ChessGameView> {
  // 8x8 Board representation: lowercase = black, uppercase = white
  late List<String> board;
  int? selectedIndex;
  String currentTurn = 'WHITE'; // WHITE or BLACK
  String currentTurnUsername = '';
  List<String> moveHistory = [];
  String statusMessage = "White's turn to move";

  final Map<String, String> pieceSymbols = {
    'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
    'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialGameState != null) {
      _applyExternalState(widget.initialGameState!);
    } else {
      _resetGame(notify: false);
    }
  }

  @override
  void didUpdateWidget(covariant ChessGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGameState != null && widget.initialGameState != oldWidget.initialGameState) {
      _applyExternalState(widget.initialGameState!);
    }
  }

  bool get isMyTurn {
    if (currentTurnUsername.isNotEmpty && widget.myUsername.isNotEmpty) {
      return currentTurnUsername.toLowerCase() == widget.myUsername.toLowerCase();
    }
    return currentTurn == widget.playerColor;
  }

  void _applyExternalState(Map<String, dynamic> state) {
    setState(() {
      if (state['board'] != null) {
        board = List<String>.from(state['board']);
      }
      if (state['currentTurn'] != null) {
        currentTurn = state['currentTurn'];
      }
      if (state['currentTurnUsername'] != null && state['currentTurnUsername'].toString().isNotEmpty) {
        currentTurnUsername = state['currentTurnUsername'].toString();
      } else {
        currentTurnUsername = currentTurn == 'WHITE' ? widget.player1Username : widget.player2Username;
      }
      if (state['moveHistory'] != null) {
        moveHistory = List<String>.from(state['moveHistory']);
      }
      selectedIndex = null;
      _updateStatusMessage();
    });
  }

  void _updateStatusMessage() {
    final activeUser = currentTurnUsername.isNotEmpty
        ? currentTurnUsername
        : (currentTurn == 'WHITE' ? widget.player1Username : widget.player2Username);
    if (isMyTurn) {
      statusMessage = "Your turn (@${widget.myUsername}) - $currentTurn";
    } else {
      statusMessage = "Waiting for @$activeUser's turn ($currentTurn)...";
    }
  }

  void _resetGame({bool notify = true}) {
    setState(() {
      board = [
        'r', 'n', 'b', 'q', 'k', 'b', 'n', 'r',
        'p', 'p', 'p', 'p', 'p', 'p', 'p', 'p',
        '', '', '', '', '', '', '', '',
        '', '', '', '', '', '', '', '',
        '', '', '', '', '', '', '', '',
        '', '', '', '', '', '', '', '',
        'P', 'P', 'P', 'P', 'P', 'P', 'P', 'P',
        'R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R',
      ];
      selectedIndex = null;
      currentTurn = 'WHITE';
      currentTurnUsername = widget.player1Username.isNotEmpty ? widget.player1Username : widget.myUsername;
      moveHistory = [];
      _updateStatusMessage();
    });

    if (notify) {
      _emitStateChange("Game reset to starting position");
    }
  }

  bool _isWhite(String piece) => piece.isNotEmpty && piece == piece.toUpperCase();
  bool _isBlack(String piece) => piece.isNotEmpty && piece == piece.toLowerCase();

  void _handleSquareTap(int index) {
    if (!isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "It's @${currentTurnUsername.isNotEmpty ? currentTurnUsername : widget.opponentName}'s turn! Please wait.",
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final clickedPiece = board[index];

    if (selectedIndex == null) {
      // First selection: pick up piece
      if (clickedPiece.isNotEmpty) {
        if ((currentTurn == 'WHITE' && _isWhite(clickedPiece)) ||
            (currentTurn == 'BLACK' && _isBlack(clickedPiece))) {
          setState(() {
            selectedIndex = index;
            statusMessage = "Selected ${clickedPiece.toUpperCase()} at ${_indexToCoord(index)}";
          });
        }
      }
    } else {
      // Destination square clicked
      if (selectedIndex == index) {
        setState(() => selectedIndex = null);
        return;
      }

      final piece = board[selectedIndex!];
      // Cannot capture own piece
      if ((currentTurn == 'WHITE' && _isWhite(clickedPiece)) ||
          (currentTurn == 'BLACK' && _isBlack(clickedPiece))) {
        setState(() {
          selectedIndex = index;
          statusMessage = "Selected ${clickedPiece.toUpperCase()} at ${_indexToCoord(index)}";
        });
        return;
      }

      // Execute move
      final fromCoord = _indexToCoord(selectedIndex!);
      final toCoord = _indexToCoord(index);
      final captured = clickedPiece.isNotEmpty ? "x" : "-";
      final moveDesc = "$piece $fromCoord$captured$toCoord";

      setState(() {
        moveHistory.insert(0, moveDesc);
        board[index] = piece;
        board[selectedIndex!] = '';
        selectedIndex = null;

        // Toggle turn
        currentTurn = currentTurn == 'WHITE' ? 'BLACK' : 'WHITE';
        currentTurnUsername = currentTurn == 'WHITE'
            ? widget.player1Username
            : widget.player2Username;
        _updateStatusMessage();
      });

      _emitStateChange(moveDesc);
    }
  }

  void _emitStateChange(String lastMoveDesc) {
    widget.onGameStateChanged?.call({
      'board': board,
      'currentTurn': currentTurn,
      'currentTurnUsername': currentTurnUsername,
      'player1Username': widget.player1Username,
      'player2Username': widget.player2Username,
      'moveHistory': moveHistory,
      'lastMove': lastMoveDesc,
      'statusMessage': statusMessage,
    });
  }

  String _indexToCoord(int index) {
    int row = 8 - (index ~/ 8);
    int col = index % 8;
    String file = String.fromCharCode('a'.codeUnitAt(0) + col);
    return "$file$row";
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
            color: const Color(0xFF8B5CF6).withOpacity(0.12),
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
                  const Icon(Icons.grid_4x4, color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Chess ♟️',
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
                    tooltip: 'Reset Board',
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

          // Chess Board Aspect Box
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF475569), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                      ),
                      itemCount: 64,
                      itemBuilder: (context, index) {
                        int row = index ~/ 8;
                        int col = index % 8;
                        bool isLight = (row + col) % 2 == 0;
                        bool isSelected = selectedIndex == index;

                        Color squareColor = isSelected
                            ? const Color(0xFFFBBF24).withOpacity(0.85) // Highlight gold
                            : (isLight ? const Color(0xFFE2E8F0) : const Color(0xFF334155));

                        final piece = board[index];
                        final symbol = pieceSymbols[piece] ?? '';
                        final isWhitePiece = _isWhite(piece);

                        return InkWell(
                          onTap: () => _handleSquareTap(index),
                          child: Container(
                            color: squareColor,
                            child: Center(
                              child: Text(
                                symbol,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isWhitePiece ? Colors.white : Colors.black87,
                                  shadows: [
                                    Shadow(
                                      color: isWhitePiece ? Colors.black54 : Colors.white54,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          // Move History Ribbon
          SizedBox(
            height: 24,
            child: moveHistory.isEmpty
                ? Center(
                    child: Text(
                      statusMessage,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: moveHistory.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      return Chip(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF1E293B),
                        label: Text(
                          moveHistory[i],
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
