import 'package:flutter/material.dart';
import '../../widgets/glass_container.dart';

class ChessGameView extends StatefulWidget {
  final VoidCallback onClose;
  const ChessGameView({super.key, required this.onClose});

  @override
  State<ChessGameView> createState() => _ChessGameViewState();
}

class _ChessGameViewState extends State<ChessGameView> {
  // 8x8 Board representation: lowercase = black, uppercase = white
  late List<String> board;
  int? selectedIndex;
  String currentTurn = 'WHITE'; // WHITE or BLACK
  List<String> moveHistory = [];
  String statusMessage = "White's turn to move";

  final Map<String, String> pieceSymbols = {
    'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
    'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
  };

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
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
      moveHistory = [];
      statusMessage = "White's turn to move";
    });
  }

  bool _isWhite(String piece) => piece.isNotEmpty && piece == piece.toUpperCase();
  bool _isBlack(String piece) => piece.isNotEmpty && piece == piece.toLowerCase();

  void _handleSquareTap(int index) {
    final clickedPiece = board[index];

    if (selectedIndex == null) {
      // First selection
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
      setState(() {
        final fromCoord = _indexToCoord(selectedIndex!);
        final toCoord = _indexToCoord(index);
        final captured = clickedPiece.isNotEmpty ? "x" : "-";
        moveHistory.insert(0, "$piece $fromCoord$captured$toCoord");

        board[index] = piece;
        board[selectedIndex!] = '';
        selectedIndex = null;

        // Toggle turn
        currentTurn = currentTurn == 'WHITE' ? 'BLACK' : 'WHITE';
        statusMessage = "$currentTurn's turn";
      });
    }
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
                  const Icon(Icons.grid_4x4, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  const Text(
                    'PlayTogether Chess ♟️',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: currentTurn == 'WHITE' ? Colors.white24 : Colors.purple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                    onPressed: _resetGame,
                    tooltip: 'Reset Board',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: widget.onClose,
                    tooltip: 'Close Game',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chess Board Aspect Box
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF475569), width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
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
                                  fontSize: 28,
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

          const SizedBox(height: 8),
          // History Preview
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: moveHistory.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return Chip(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF1E293B),
                  label: Text(
                    moveHistory[i],
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
