package com.chatgen.backend.service;

import com.chatgen.backend.model.GameRoom;
import com.chatgen.backend.repository.GameRoomRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;

@Service
public class GameEngineService {

    private final GameRoomRepository gameRoomRepository;
    private final ObjectMapper objectMapper;

    // Snakes & Ladders Board mappings (Saanp-Seedi)
    private static final Map<Integer, Integer> SNAKES = Map.of(
            99, 12,
            92, 53,
            75, 32,
            55, 14,
            38, 9
    );

    private static final Map<Integer, Integer> LADDERS = Map.of(
            4, 25,
            13, 46,
            33, 70,
            42, 63,
            50, 89,
            62, 81
    );

    public GameEngineService(GameRoomRepository gameRoomRepository, ObjectMapper objectMapper) {
        this.gameRoomRepository = gameRoomRepository;
        this.objectMapper = objectMapper;
    }

    public GameRoom createGame(UUID conversationId, String gameType, UUID hostUserId, UUID opponentUserId) {
        GameRoom room = new GameRoom();
        room.setConversationId(conversationId);
        room.setGameType(gameType.toUpperCase());
        room.setStatus("ACTIVE");
        room.setPlayerWhiteId(hostUserId);
        room.setPlayerBlackId(opponentUserId);
        room.setTurnUserId(hostUserId);

        Map<String, Object> initialState = new HashMap<>();

        if ("CHESS".equalsIgnoreCase(gameType)) {
            initialState.put("board", getInitialChessBoard());
            initialState.put("turn", "WHITE");
            initialState.put("halfMoves", 0);
        } else if ("LUDO".equalsIgnoreCase(gameType)) {
            Map<String, Object> ludoState = new HashMap<>();
            ludoState.put("player1_positions", List.of(0, 0, 0, 0));
            ludoState.put("player2_positions", List.of(0, 0, 0, 0));
            ludoState.put("lastDice", 6);
            initialState.put("ludo", ludoState);
        } else if ("SNAKES_AND_LADDERS".equalsIgnoreCase(gameType)) {
            Map<String, Integer> positions = new HashMap<>();
            positions.put(hostUserId.toString(), 1);
            if (opponentUserId != null) {
                positions.put(opponentUserId.toString(), 1);
            }
            initialState.put("positions", positions);
            initialState.put("lastDice", 1);
        }

        try {
            room.setStateJson(objectMapper.writeValueAsString(initialState));
            room.setMoveHistoryJson("[]");
        } catch (Exception e) {
            room.setStateJson("{}");
            room.setMoveHistoryJson("[]");
        }

        return gameRoomRepository.save(room);
    }

    public GameRoom makeMove(UUID roomId, UUID userId, Map<String, Object> movePayload) {
        GameRoom room = gameRoomRepository.findById(roomId)
                .orElseThrow(() -> new IllegalArgumentException("Game room not found: " + roomId));

        try {
            Map<String, Object> state = objectMapper.readValue(room.getStateJson(), new TypeReference<>() {});
            List<Map<String, Object>> history = objectMapper.readValue(room.getMoveHistoryJson(), new TypeReference<>() {});

            if ("SNAKES_AND_LADDERS".equalsIgnoreCase(room.getGameType())) {
                @SuppressWarnings("unchecked")
                Map<String, Object> posMap = (Map<String, Object>) state.get("positions");
                int currentPos = Integer.parseInt(posMap.getOrDefault(userId.toString(), 1).toString());
                int dice = (int) (Math.random() * 6) + 1;
                int targetPos = currentPos + dice;

                if (targetPos > 100) {
                    targetPos = currentPos; // Bounce / wait rule
                } else {
                    if (SNAKES.containsKey(targetPos)) {
                        targetPos = SNAKES.get(targetPos);
                    } else if (LADDERS.containsKey(targetPos)) {
                        targetPos = LADDERS.get(targetPos);
                    }
                }

                posMap.put(userId.toString(), targetPos);
                state.put("lastDice", dice);

                Map<String, Object> moveRecord = new HashMap<>();
                moveRecord.put("userId", userId);
                moveRecord.put("dice", dice);
                moveRecord.put("finalPos", targetPos);
                moveRecord.put("timestamp", Instant.now().toString());
                history.add(moveRecord);

                if (targetPos == 100) {
                    room.setStatus("FINISHED");
                    room.setWinnerUserId(userId);
                } else {
                    // Switch turn
                    UUID nextTurn = userId.equals(room.getPlayerWhiteId()) ? room.getPlayerBlackId() : room.getPlayerWhiteId();
                    room.setTurnUserId(nextTurn != null ? nextTurn : userId);
                }

            } else if ("CHESS".equalsIgnoreCase(room.getGameType())) {
                String from = (String) movePayload.get("from");
                String to = (String) movePayload.get("to");
                String piece = (String) movePayload.get("piece");

                @SuppressWarnings("unchecked")
                List<String> board = (List<String>) state.get("board");
                int fromIdx = parseSquare(from);
                int toIdx = parseSquare(to);

                if (fromIdx >= 0 && fromIdx < 64 && toIdx >= 0 && toIdx < 64) {
                    board.set(toIdx, board.get(fromIdx));
                    board.set(fromIdx, "");
                }

                String currentTurn = (String) state.get("turn");
                state.put("turn", "WHITE".equals(currentTurn) ? "BLACK" : "WHITE");

                Map<String, Object> moveRecord = new HashMap<>();
                moveRecord.put("userId", userId);
                moveRecord.put("from", from);
                moveRecord.put("to", to);
                moveRecord.put("piece", piece);
                history.add(moveRecord);

                UUID nextTurn = userId.equals(room.getPlayerWhiteId()) ? room.getPlayerBlackId() : room.getPlayerWhiteId();
                room.setTurnUserId(nextTurn != null ? nextTurn : userId);
            }

            room.setStateJson(objectMapper.writeValueAsString(state));
            room.setMoveHistoryJson(objectMapper.writeValueAsString(history));
            room.setUpdatedAt(Instant.now());

        } catch (Exception e) {
            throw new RuntimeException("Error processing game move: " + e.getMessage(), e);
        }

        return gameRoomRepository.save(room);
    }

    private int parseSquare(String sq) {
        if (sq == null || sq.length() < 2) return 0;
        char file = sq.toLowerCase().charAt(0);
        char rank = sq.charAt(1);
        int col = file - 'a';
        int row = 8 - Character.getNumericValue(rank);
        return row * 8 + col;
    }

    private List<String> getInitialChessBoard() {
        return Arrays.asList(
                "r","n","b","q","k","b","n","r",
                "p","p","p","p","p","p","p","p",
                "","","","","","","","",
                "","","","","","","","",
                "","","","","","","","",
                "","","","","","","","",
                "P","P","P","P","P","P","P","P",
                "R","N","B","Q","K","B","N","R"
        );
    }
}
