package com.chatgen.backend.service;

import com.chatgen.backend.config.AppProperties;
import com.chatgen.backend.model.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtService {

    private final SecretKey key;
    private final long expirationMs;

    public JwtService(AppProperties appProperties) {
        String secret = appProperties.getJwt() != null && appProperties.getJwt().getSecret() != null && !appProperties.getJwt().getSecret().isBlank()
                ? appProperties.getJwt().getSecret()
                : "NextGenChatSuperSecretKey2026SecureTokenGeneratorForProductionDeployment98765";

        // Secret key must be at least 256 bits (32 bytes) for HS256
        byte[] secretBytes = secret.getBytes(StandardCharsets.UTF_8);
        if (secretBytes.length < 32) {
            byte[] padded = new byte[32];
            System.arraycopy(secretBytes, 0, padded, 0, secretBytes.length);
            this.key = Keys.hmacShaKeyFor(padded);
        } else {
            this.key = Keys.hmacShaKeyFor(secretBytes);
        }

        Long exp = appProperties.getJwt() != null ? appProperties.getJwt().getExpirationMs() : null;
        this.expirationMs = (exp != null && exp > 0) ? exp : 86400000L; // 24 hours
    }

    /**
     * Generates a signed JWT token containing user identity claims.
     */
    public String generateToken(User user) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + expirationMs);

        return Jwts.builder()
                .subject(user.getId().toString())
                .claim("username", user.getUsername())
                .claim("displayName", user.getDisplayName())
                .claim("email", user.getEmail() != null ? user.getEmail() : "")
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(key)
                .compact();
    }

    /**
     * Validates whether a token is authentic and not expired.
     */
    public boolean validateToken(String token) {
        if (token == null || token.isBlank()) return false;
        try {
            Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token.trim());
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Extracts user UUID from signed JWT claims.
     */
    public UUID getUserIdFromToken(String token) {
        if (token == null || token.isBlank()) return null;
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token.trim())
                    .getPayload();
            return UUID.fromString(claims.getSubject());
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Extracts username from signed JWT claims.
     */
    public String getUsernameFromToken(String token) {
        if (token == null || token.isBlank()) return null;
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token.trim())
                    .getPayload();
            Object username = claims.get("username");
            return username != null ? username.toString() : null;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Strips 'Bearer ' prefix if present.
     */
    public String extractToken(String bearerOrToken) {
        if (bearerOrToken == null || bearerOrToken.isBlank()) return null;
        String trimmed = bearerOrToken.trim();
        if (trimmed.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return trimmed.substring(7).trim();
        }
        return trimmed;
    }
}
