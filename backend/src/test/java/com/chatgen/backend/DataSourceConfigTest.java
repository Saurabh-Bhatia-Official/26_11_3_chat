package com.chatgen.backend;

import com.chatgen.backend.config.DataSourceConfig;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

public class DataSourceConfigTest {

    @Test
    @DisplayName("1. User 'postgres' in pooler URL is automatically appended with tenant reference")
    void testPoolerUrlWithBarePostgresUser() {
        DataSourceConfig config = new DataSourceConfig();
        ReflectionTestUtils.setField(config, "dbUrl", "postgresql://postgres:JtZfEtX4eX0c8vtJ@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres");
        ReflectionTestUtils.setField(config, "dbUser", "postgres");
        ReflectionTestUtils.setField(config, "dbPassword", "JtZfEtX4eX0c8vtJ");

        DataSourceConfig.ResolvedDataSourceConfig resolved = config.resolveConfig();

        assertEquals("postgres.vtxwvilrvtiklqmnbenh", resolved.username);
        assertTrue(resolved.jdbcUrl.contains("aws-0-ap-northeast-1.pooler.supabase.com"));
        assertTrue(resolved.jdbcUrl.contains("sslmode=require"));
        assertFalse(resolved.jdbcUrl.contains("postgres:JtZfEtX4eX0c8vtJ@")); // Embedded credentials stripped
    }

    @Test
    @DisplayName("2. Direct IPv6 Supabase URL is translated to IPv4 pooler and gets tenant reference")
    void testDirectSupabaseUrlWithBarePostgresUser() {
        DataSourceConfig config = new DataSourceConfig();
        ReflectionTestUtils.setField(config, "dbUrl", "postgresql://postgres:JtZfEtX4eX0c8vtJ@db.vtxwvilrvtiklqmnbenh.supabase.co:5432/postgres?sslmode=require");
        ReflectionTestUtils.setField(config, "dbUser", "postgres");

        DataSourceConfig.ResolvedDataSourceConfig resolved = config.resolveConfig();

        assertEquals("postgres.vtxwvilrvtiklqmnbenh", resolved.username);
        assertTrue(resolved.jdbcUrl.contains("aws-0-ap-northeast-1.pooler.supabase.com"));
        assertFalse(resolved.jdbcUrl.contains("db.vtxwvilrvtiklqmnbenh.supabase.co"));
    }

    @Test
    @DisplayName("3. When no URL is given and DB_USER is bare 'postgres', tenant reference is added")
    void testIndividualPropertiesWithBarePostgresUser() {
        DataSourceConfig config = new DataSourceConfig();
        ReflectionTestUtils.setField(config, "dbUrl", "");
        ReflectionTestUtils.setField(config, "dbHost", "aws-0-ap-northeast-1.pooler.supabase.com");
        ReflectionTestUtils.setField(config, "dbPort", "5432");
        ReflectionTestUtils.setField(config, "dbName", "postgres");
        ReflectionTestUtils.setField(config, "dbUser", "postgres");

        DataSourceConfig.ResolvedDataSourceConfig resolved = config.resolveConfig();

        assertEquals("postgres.vtxwvilrvtiklqmnbenh", resolved.username);
        assertTrue(resolved.jdbcUrl.contains("aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres"));
    }

    @Test
    @DisplayName("4. When username already has tenant reference, it is preserved without duplication")
    void testPreserveExistingTenantReference() {
        DataSourceConfig config = new DataSourceConfig();
        ReflectionTestUtils.setField(config, "dbUrl", "postgresql://postgres.vtxwvilrvtiklqmnbenh:JtZfEtX4eX0c8vtJ@aws-0-ap-northeast-1.pooler.supabase.com:5432/postgres");
        ReflectionTestUtils.setField(config, "dbUser", "postgres.vtxwvilrvtiklqmnbenh");

        DataSourceConfig.ResolvedDataSourceConfig resolved = config.resolveConfig();

        assertEquals("postgres.vtxwvilrvtiklqmnbenh", resolved.username);
    }
}
