# Multi-stage build for Spring Boot Backend
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app

# Copy pom.xml and source code
COPY pom.xml .
COPY src ./src

# Package executable JAR (skipping tests for fast container deployment)
RUN mvn clean package -DskipTests

# Runtime image
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Copy packaged JAR from build stage
COPY --from=build /app/target/chat-backend-1.0.0.jar app.jar

# Expose port (Render/Railway dynamically pass $PORT)
ENV PORT=8085
EXPOSE 8085

# Launch Spring Boot with dynamic PORT
ENTRYPOINT ["sh", "-c", "java -jar app.jar --server.port=${PORT}"]
