package com.chatgen.backend.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "game_rooms")
public class GameRoom {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private UUID conversationId;

    @Column(nullable = false, length = 30)
    private String gameType; // CHESS, LUDO, SNAKES_AND_LADDERS

    @Column(length = 20)
    private String status = "ACTIVE"; // WAITING, ACTIVE, FINISHED, ABANDONED

    private UUID playerWhiteId;
    private UUID playerBlackId;
    private UUID turnUserId;
    private UUID winnerUserId;

    @Column(columnDefinition = "TEXT")
    private String stateJson;

    @Column(columnDefinition = "TEXT")
    private String moveHistoryJson;

    private Instant createdAt = Instant.now();
    private Instant updatedAt = Instant.now();

    public GameRoom() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getConversationId() { return conversationId; }
    public void setConversationId(UUID conversationId) { this.conversationId = conversationId; }

    public String getGameType() { return gameType; }
    public void setGameType(String gameType) { this.gameType = gameType; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public UUID getPlayerWhiteId() { return playerWhiteId; }
    public void setPlayerWhiteId(UUID playerWhiteId) { this.playerWhiteId = playerWhiteId; }

    public UUID getPlayerBlackId() { return playerBlackId; }
    public void setPlayerBlackId(UUID playerBlackId) { this.playerBlackId = playerBlackId; }

    public UUID getTurnUserId() { return turnUserId; }
    public void setTurnUserId(UUID turnUserId) { this.turnUserId = turnUserId; }

    public UUID getWinnerUserId() { return winnerUserId; }
    public void setWinnerUserId(UUID winnerUserId) { this.winnerUserId = winnerUserId; }

    public String getStateJson() { return stateJson; }
    public void setStateJson(String stateJson) { this.stateJson = stateJson; }

    public String getMoveHistoryJson() { return moveHistoryJson; }
    public void setMoveHistoryJson(String moveHistoryJson) { this.moveHistoryJson = moveHistoryJson; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
