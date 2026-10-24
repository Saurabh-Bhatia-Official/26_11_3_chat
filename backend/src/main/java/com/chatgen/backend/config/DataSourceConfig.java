package com.chatgen.backend.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.net.URI;
import java.sql.Connection;

@Configuration
public class DataSourceConfig {

    @Value("${spring.datasource.url:}")
    private String dbUrl;

    @Value("${spring.datasource.username:postgres}")
    private String dbUser;

    @Value("${spring.datasource.password:}")
    private String dbPassword;

    @Value("${DB_HOST:db.vtxwvilrvtiklqmnbenh.supabase.co}")
    private String dbHost;

    @Value("${DB_PORT:5432}")
    private String dbPort;

    @Value("${DB_NAME:postgres}")
    private String dbName;

    @Value("${spring.datasource.driver-class-name:org.postgresql.Driver}")
    private String driverClassName;

    @Bean
    @Primary
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();

        String finalJdbcUrl = dbUrl;
        String finalUser = dbUser;
        String finalPassword = dbPassword;

        // If dbUrl is empty, assemble from discrete Supabase environment variables
        if (finalJdbcUrl == null || finalJdbcUrl.isBlank()) {
            finalJdbcUrl = "jdbc:postgresql://" + dbHost + ":" + dbPort + "/" + dbName + "?sslmode=require";
        }

        if (finalJdbcUrl.startsWith("postgres://") || (finalJdbcUrl.startsWith("postgresql://") && !finalJdbcUrl.startsWith("jdbc:"))) {
            try {
                // Normalize scheme for URI parsing
                String uriString = finalJdbcUrl.startsWith("postgres://")
                        ? finalJdbcUrl.replaceFirst("postgres://", "http://")
                        : finalJdbcUrl.replaceFirst("postgresql://", "http://");
                URI uri = new URI(uriString);
                String host = uri.getHost();
                int port = uri.getPort() == -1 ? 5432 : uri.getPort();
                String path = uri.getPath();
                String query = uri.getQuery();

                finalJdbcUrl = "jdbc:postgresql://" + host + ":" + port + path;
                if (query != null && !query.isEmpty()) {
                    finalJdbcUrl += "?" + query;
                } else {
                    finalJdbcUrl += "?sslmode=require";
                }

                if (uri.getUserInfo() != null) {
                    String[] userParts = uri.getUserInfo().split(":", 2);
                    finalUser = userParts[0];
                    if (userParts.length > 1) {
                        finalPassword = userParts[1];
                    }
                }
            } catch (Exception ignored) {}
        }

        // Ensure sslmode=require for cloud PostgreSQL
        if (!finalJdbcUrl.contains("sslmode=")) {
            finalJdbcUrl += (finalJdbcUrl.contains("?") ? "&" : "?") + "sslmode=require";
        }

        config.setJdbcUrl(finalJdbcUrl);
        config.setUsername(finalUser);
        config.setPassword(finalPassword);
        config.setDriverClassName(driverClassName != null && !driverClassName.isBlank() ? driverClassName : "org.postgresql.Driver");

        // Hikari pool tuning optimal for Supabase PostgreSQL (Session or Pooler connections)
        config.setMaximumPoolSize(15);
        config.setMinimumIdle(3);
        config.setIdleTimeout(300000);
        config.setMaxLifetime(1200000);
        config.setConnectionTimeout(20000);

        String safeUrl = finalJdbcUrl.replaceAll(":[^/@]+@", ":***@");
        System.out.println(">>> [DATABASE] Connecting to Supabase Cloud PostgreSQL: " + safeUrl + " (User: " + finalUser + ")");

        return new HikariDataSource(config);
    }
}
