package com.chatgen.backend.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.io.File;
import java.net.URI;
import java.sql.Connection;

@Configuration
public class DataSourceConfig {

    @Value("${spring.datasource.url}")
    private String dbUrl;

    @Value("${spring.datasource.username:}")
    private String dbUser;

    @Value("${spring.datasource.password:}")
    private String dbPassword;

    @Value("${spring.datasource.driver-class-name:org.postgresql.Driver}")
    private String driverClassName;

    @Bean
    @Primary
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();

        if (dbUrl != null && (dbUrl.startsWith("postgres://") || (dbUrl.startsWith("postgresql://") && !dbUrl.startsWith("jdbc:")))) {
            try {
                // Normalize scheme for URI parsing
                String uriString = dbUrl.startsWith("postgres://") ? dbUrl.replaceFirst("postgres://", "http://") : dbUrl.replaceFirst("postgresql://", "http://");
                URI uri = new URI(uriString);
                String host = uri.getHost();
                int port = uri.getPort() == -1 ? 5432 : uri.getPort();
                String path = uri.getPath(); // e.g. /neondb
                String query = uri.getQuery(); // e.g. sslmode=require&channel_binding=require

                String jdbcUrl = "jdbc:postgresql://" + host + ":" + port + path;
                if (query != null && !query.isEmpty()) {
                    jdbcUrl += "?" + query;
                }
                config.setJdbcUrl(jdbcUrl);

                if (uri.getUserInfo() != null) {
                    String[] userParts = uri.getUserInfo().split(":", 2);
                    config.setUsername(userParts[0]);
                    if (userParts.length > 1) {
                        config.setPassword(userParts[1]);
                    }
                } else {
                    config.setUsername(dbUser);
                    config.setPassword(dbPassword);
                }
                config.setDriverClassName("org.postgresql.Driver");
            } catch (Exception e) {
                config.setJdbcUrl(dbUrl);
                config.setUsername(dbUser);
                config.setPassword(dbPassword);
                config.setDriverClassName(driverClassName);
            }
        } else {
            config.setJdbcUrl(dbUrl);
            config.setUsername(dbUser);
            config.setPassword(dbPassword);
            config.setDriverClassName(driverClassName);
        }

        // Hikari pool tuning optimal for Neon serverless / pooler connections
        config.setMaximumPoolSize(10);
        config.setMinimumIdle(1);
        config.setIdleTimeout(30000);
        config.setMaxLifetime(600000);
        config.setConnectionTimeout(6000);
        config.setInitializationFailTimeout(1);

        try {
            HikariDataSource ds = new HikariDataSource(config);
            try (Connection conn = ds.getConnection()) {
                System.out.println(">>> [DATABASE] Successfully connected to Neon Cloud PostgreSQL: " + config.getJdbcUrl());
                return ds;
            }
        } catch (Exception e) {
            System.err.println(">>> [DATABASE NOTICE] Neon Cloud DB unavailable or quota exceeded (" + e.getMessage() + ").");
            System.err.println(">>> [DATABASE NOTICE] Seamlessly falling back to persistent local database (H2 in PostgreSQL mode)...");

            try {
                File dir = new File("./data");
                if (!dir.exists()) {
                    dir.mkdirs();
                }
            } catch (Exception ignored) {}

            HikariConfig localConfig = new HikariConfig();
            localConfig.setJdbcUrl("jdbc:h2:file:./data/chatdb;DB_CLOSE_DELAY=-1;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE");
            localConfig.setDriverClassName("org.h2.Driver");
            localConfig.setUsername("sa");
            localConfig.setPassword("");
            localConfig.setMaximumPoolSize(10);
            localConfig.setMinimumIdle(2);
            localConfig.setIdleTimeout(30000);
            return new HikariDataSource(localConfig);
        }
    }
}
