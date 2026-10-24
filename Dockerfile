# Multi-stage root build for Spring Boot Backend on Render / Cloud
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app

# Copy pom.xml and source code from backend directory
COPY backend/pom.xml .
COPY backend/src ./src

# Package executable JAR (skipping tests for fast container deployment)
RUN mvn clean package -DskipTests

# Runtime image using standard glibc for robust DNS resolution
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Copy packaged JAR from build stage
COPY --from=build /app/target/chat-backend-1.0.0.jar app.jar

# Expose port (Render dynamically sets $PORT)
ENV PORT=8085
EXPOSE 8085

# Launch Spring Boot with container-aware memory limits optimal for Render 512MB RAM free instances
ENTRYPOINT ["sh", "-c", "java -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Xms128m -Xmx384m -Djava.security.egd=file:/dev/./urandom -jar app.jar --server.port=${PORT}"]
