package com.chatgen.backend.controller;

import com.chatgen.backend.model.GameRoom;
import com.chatgen.backend.repository.GameRoomRepository;
import com.chatgen.backend.service.GameEngineService;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/games")
public class GameController {

    private final GameEngineService gameEngineService;
    private final GameRoomRepository gameRoomRepository;
    private final SimpMessagingTemplate messagingTemplate;

    public GameController(GameEngineService gameEngineService,
                          GameRoomRepository gameRoomRepository,
                          SimpMessagingTemplate messagingTemplate) {
        this.gameEngineService = gameEngineService;
        this.gameRoomRepository = gameRoomRepository;
        this.messagingTemplate = messagingTemplate;
    }

    @GetMapping("/active/{conversationId}")
    public ResponseEntity<?> getActiveGame(@PathVariable UUID conversationId) {
        return gameRoomRepository.findTopByConversationIdAndStatusOrderByCreatedAtDesc(conversationId, "ACTIVE")
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.noContent().build());
    }

    @PostMapping("/create")
    public ResponseEntity<GameRoom> createGame(@RequestBody Map<String, String> payload) {
        UUID conversationId = UUID.fromString(payload.get("conversationId"));
        String gameType = payload.get("gameType");
        UUID hostId = UUID.fromString(payload.get("hostUserId"));
        UUID opponentId = payload.containsKey("opponentUserId") && payload.get("opponentUserId") != null
                ? UUID.fromString(payload.get("opponentUserId")) : null;

        GameRoom room = gameEngineService.createGame(conversationId, gameType, hostId, opponentId);
        messagingTemplate.convertAndSend("/topic/conversation." + conversationId + ".game", room);
        return ResponseEntity.ok(room);
    }

    @PostMapping("/{roomId}/move")
    public ResponseEntity<GameRoom> makeMoveRest(@PathVariable UUID roomId, @RequestBody Map<String, Object> payload) {
        UUID userId = UUID.fromString((String) payload.get("userId"));
        GameRoom updatedRoom = gameEngineService.makeMove(roomId, userId, payload);
        messagingTemplate.convertAndSend("/topic/game." + roomId, updatedRoom);
        return ResponseEntity.ok(updatedRoom);
    }

    @MessageMapping("/game.move")
    public void makeMoveWebSocket(@Payload Map<String, Object> payload) {
        UUID roomId = UUID.fromString((String) payload.get("roomId"));
        UUID userId = UUID.fromString((String) payload.get("userId"));
        GameRoom updatedRoom = gameEngineService.makeMove(roomId, userId, payload);
        messagingTemplate.convertAndSend("/topic/game." + roomId, updatedRoom);
    }
}
