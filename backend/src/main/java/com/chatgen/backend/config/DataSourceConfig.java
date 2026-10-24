package com.chatgen.backend.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.net.URI;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Configuration
public class DataSourceConfig {

    public static final String DEFAULT_PROJECT_REF = "vtxwvilrvtiklqmnbenh";
    public static final String DEFAULT_POOLER_HOST = "aws-0-ap-northeast-1.pooler.supabase.com";

    private static final Pattern DIRECT_SUPABASE_PATTERN =
            Pattern.compile("db\\.([a-zA-Z0-9_-]+)\\.supabase\\.co", Pattern.CASE_INSENSITIVE);

    @Value("${SUPABASE_DB_URL:${spring.datasource.url:}}")
    private String dbUrl;

    @Value("${spring.datasource.username:postgres.vtxwvilrvtiklqmnbenh}")
    private String dbUser;

    @Value("${spring.datasource.password:JtZfEtX4eX0c8vtJ}")
    private String dbPassword;

    @Value("${DB_HOST:aws-0-ap-northeast-1.pooler.supabase.com}")
    private String dbHost;

    @Value("${DB_PORT:5432}")
    private String dbPort;

    @Value("${DB_NAME:postgres}")
    private String dbName;

    @Value("${spring.datasource.driver-class-name:org.postgresql.Driver}")
    private String driverClassName;

    public static class ResolvedDataSourceConfig {
        public final String jdbcUrl;
        public final String username;
        public final String password;

        public ResolvedDataSourceConfig(String jdbcUrl, String username, String password) {
            this.jdbcUrl = jdbcUrl;
            this.username = username;
            this.password = password;
        }
    }

    public ResolvedDataSourceConfig resolveConfig() {
        String finalJdbcUrl = (dbUrl != null && !dbUrl.isBlank()) ? dbUrl.trim() : null;
        String finalUser = (dbUser != null && !dbUser.isBlank()) ? dbUser.trim() : "postgres." + DEFAULT_PROJECT_REF;
        String finalPassword = dbPassword;
        String detectedProjectRef = DEFAULT_PROJECT_REF;

        // 1. Extract credentials if embedded in a raw postgres:// or postgresql:// URI
        if (finalJdbcUrl != null && (finalJdbcUrl.startsWith("postgres://") || (finalJdbcUrl.startsWith("postgresql://") && !finalJdbcUrl.startsWith("jdbc:")))) {
            try {
                String uriString = finalJdbcUrl.startsWith("postgres://")
                        ? finalJdbcUrl.replaceFirst("postgres://", "http://")
                        : finalJdbcUrl.replaceFirst("postgresql://", "http://");
                URI uri = new URI(uriString);
                String host = uri.getHost();
                int port = uri.getPort() == -1 ? 5432 : uri.getPort();
                String path = (uri.getPath() != null && !uri.getPath().isEmpty()) ? uri.getPath() : "/postgres";
                String query = uri.getQuery();

                finalJdbcUrl = "jdbc:postgresql://" + host + ":" + port + path;
                if (query != null && !query.isEmpty()) {
                    finalJdbcUrl += "?" + query;
                }

                if (uri.getUserInfo() != null) {
                    String[] userParts = uri.getUserInfo().split(":", 2);
                    if (userParts.length > 0 && !userParts[0].isBlank()) {
                        finalUser = userParts[0];
                    }
                    if (userParts.length > 1) {
                        finalPassword = userParts[1];
                    }
                }
            } catch (Exception ignored) {}
        }

        // 2. Extract credentials if someone passed them embedded inside jdbc:postgresql://user:pass@host:port/db
        if (finalJdbcUrl != null && finalJdbcUrl.startsWith("jdbc:postgresql://") && finalJdbcUrl.contains("@")) {
            try {
                String withoutPrefix = finalJdbcUrl.substring("jdbc:postgresql://".length());
                int atIndex = withoutPrefix.indexOf('@');
                if (atIndex > 0) {
                    String userPass = withoutPrefix.substring(0, atIndex);
                    String rest = withoutPrefix.substring(atIndex + 1);
                    String[] userParts = userPass.split(":", 2);
                    if (userParts.length > 0 && !userParts[0].isBlank()) {
                        finalUser = userParts[0];
                    }
                    if (userParts.length > 1) {
                        finalPassword = userParts[1];
                    }
                    finalJdbcUrl = "jdbc:postgresql://" + rest;
                }
            } catch (Exception ignored) {}
        }

        // 3. Detect project reference from direct Supabase host and translate IPv6 host to IPv4 pooler
        if (finalJdbcUrl != null) {
            Matcher matcher = DIRECT_SUPABASE_PATTERN.matcher(finalJdbcUrl);
            if (matcher.find()) {
                detectedProjectRef = matcher.group(1);
                System.out.println(">>> [SUPABASE IPV4 ADAPTER] Translating IPv6-only direct host to IPv4-compatible pooler: " + DEFAULT_POOLER_HOST);
                finalJdbcUrl = matcher.replaceAll(DEFAULT_POOLER_HOST);
            }
        }

        // 4. If URL is empty or points to an unrelated/invalid host, fall back to configured parameters
        if (finalJdbcUrl == null || finalJdbcUrl.isBlank() || (!finalJdbcUrl.contains("supabase.co") && !finalJdbcUrl.contains("supabase.com") && !finalJdbcUrl.contains("localhost"))) {
            if (finalJdbcUrl != null && !finalJdbcUrl.isBlank()) {
                System.out.println(">>> [DATABASE SAFEGUARD] Non-Supabase URL detected: " + finalJdbcUrl.replaceAll(":[^/@]+@", ":***@"));
                System.out.println(">>> Automatically routing to active Supabase Cloud PostgreSQL: " + dbHost);
            }
            finalJdbcUrl = "jdbc:postgresql://" + dbHost + ":" + dbPort + "/" + dbName + "?sslmode=require";
            finalUser = dbUser;
            finalPassword = dbPassword;
        }

        // 5. CRITICAL FIX FOR: FATAL: (ENOIDENTIFIER) no tenant identifier provided (external_id or sni_hostname required)
        // When connecting to any Supabase connection pooler (*.pooler.supabase.com), Supavisor requires the username
        // to contain the tenant identifier suffix (e.g. 'postgres.<project-ref>').
        // If the user passed just 'postgres' (from URL or DB_USER), automatically append the project tenant identifier.
        if (finalJdbcUrl != null && finalJdbcUrl.contains("pooler.supabase.com")) {
            String projectRef = (detectedProjectRef != null && !detectedProjectRef.isBlank()) ? detectedProjectRef : DEFAULT_PROJECT_REF;
            if (finalUser == null || finalUser.isBlank() || finalUser.equalsIgnoreCase("postgres")) {
                System.out.println(">>> [SUPABASE TENANT IDENTIFIER ENFORCED] Updated username from '" + finalUser + "' to 'postgres." + projectRef + "' for pooler routing");
                finalUser = "postgres." + projectRef;
            } else if (!finalUser.contains(".")) {
                System.out.println(">>> [SUPABASE TENANT IDENTIFIER ENFORCED] Appended project reference to username: '" + finalUser + "." + projectRef + "'");
                finalUser = finalUser + "." + projectRef;
            }
        }

        // 6. Ensure sslmode=require for cloud PostgreSQL
        if (!finalJdbcUrl.contains("sslmode=")) {
            finalJdbcUrl += (finalJdbcUrl.contains("?") ? "&" : "?") + "sslmode=require";
        }

        return new ResolvedDataSourceConfig(finalJdbcUrl, finalUser, finalPassword);
    }

    @Bean
    @Primary
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();

        ResolvedDataSourceConfig resolved = resolveConfig();

        config.setJdbcUrl(resolved.jdbcUrl);
        config.setUsername(resolved.username);
        config.setPassword(resolved.password);
        config.setDriverClassName(driverClassName != null && !driverClassName.isBlank() ? driverClassName : "org.postgresql.Driver");

        // Hikari pool tuning optimal for Supabase PostgreSQL (Session or Pooler connections)
        config.setMaximumPoolSize(15);
        config.setMinimumIdle(3);
        config.setIdleTimeout(300000);
        config.setMaxLifetime(1200000);
        config.setConnectionTimeout(20000);

        String safeUrl = resolved.jdbcUrl.replaceAll(":[^/@]+@", ":***@");
        System.out.println(">>> [DATABASE] Connecting to Supabase Cloud PostgreSQL: " + safeUrl + " (User: " + resolved.username + ")");

        return new HikariDataSource(config);
    }
}
