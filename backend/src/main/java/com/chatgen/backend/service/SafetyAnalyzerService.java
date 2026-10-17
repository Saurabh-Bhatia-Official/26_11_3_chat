package com.chatgen.backend.service;

import com.chatgen.backend.model.SafetyEvent;
import com.chatgen.backend.repository.SafetyEventRepository;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class SafetyAnalyzerService {

    private final SafetyEventRepository safetyEventRepository;

    private static final Pattern URL_PATTERN = Pattern.compile(
            "\\b((https?|ftp)://|www\\.)[-a-zA-Z0-9+&@#/%?=~_|!:,.;]*[-a-zA-Z0-9+&@#/%=~_|]",
            Pattern.CASE_INSENSITIVE
    );

    private static final Set<String> HIGH_RISK_TLDS = Set.of(
            ".fake", ".phish", ".top", ".xyz", ".cc", ".tk", ".ml", ".ga", ".cf", ".gq"
    );

    public SafetyAnalyzerService(SafetyEventRepository safetyEventRepository) {
        this.safetyEventRepository = safetyEventRepository;
    }

    public Map<String, Object> analyzeContentSafety(UUID userId, String content) {
        Map<String, Object> result = new HashMap<>();
        List<Map<String, Object>> detectedUrls = new ArrayList<>();
        boolean hasThreat = false;
        int overallRiskScore = 0;

        Matcher matcher = URL_PATTERN.matcher(content);
        while (matcher.find()) {
            String urlStr = matcher.group();
            Map<String, Object> scanResult = scanUrl(urlStr);
            detectedUrls.add(scanResult);

            int risk = (int) scanResult.get("riskScore");
            if (risk > overallRiskScore) {
                overallRiskScore = risk;
            }
            if ((boolean) scanResult.get("isSuspicious")) {
                hasThreat = true;
            }
        }

        result.put("scannedUrls", detectedUrls);
        result.put("hasThreat", hasThreat);
        result.put("riskScore", overallRiskScore);

        if (hasThreat && userId != null) {
            SafetyEvent event = new SafetyEvent();
            event.setUserId(userId);
            event.setEventType("MALICIOUS_LINK");
            event.setSeverity(overallRiskScore > 75 ? "HIGH" : "MEDIUM");
            event.setDescription("Intercepted potential phishing/scam link in conversation. Risk score: " + overallRiskScore);
            event.setIpAddress("127.0.0.1");
            safetyEventRepository.save(event);
        }

        return result;
    }

    public Map<String, Object> scanUrl(String urlStr) {
        Map<String, Object> scan = new HashMap<>();
        scan.put("url", urlStr);

        int riskScore = 0;
        List<String> warnings = new ArrayList<>();

        try {
            String normalizedUrl = urlStr.startsWith("http") ? urlStr : "http://" + urlStr;
            URI uri = new URI(normalizedUrl);
            String host = uri.getHost() != null ? uri.getHost().toLowerCase() : "";

            // 1. IP address in hostname (e.g. http://192.168.1.1/login)
            if (host.matches("\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}")) {
                riskScore += 50;
                warnings.add("Direct numeric IP address in URL instead of trusted domain");
            }

            // 2. Punycode / Homograph spoofing detection
            if (host.startsWith("xn--")) {
                riskScore += 65;
                warnings.add("Internationalized domain name (Punycode) detected (potential homograph attack)");
            }

            // 3. Brand impersonation / spoofing heuristics (e.g., paypa1, micros0ft, secure-bank-login)
            if (host.contains("paypa1") || host.contains("g00gle") || host.contains("app1e") ||
                host.contains("security-verify") || host.contains("login-confirm")) {
                riskScore += 75;
                warnings.add("Suspicious brand impersonation pattern detected in domain name");
            }

            // 4. Risky TLD check
            for (String tld : HIGH_RISK_TLDS) {
                if (host.endsWith(tld)) {
                    riskScore += 40;
                    warnings.add("Domain uses high-abuse top level domain (" + tld + ")");
                    break;
                }
            }

            // 5. Excessive subdomains
            if (host.chars().filter(ch -> ch == '.').count() > 3) {
                riskScore += 20;
                warnings.add("Abnormally high subdomain count detected");
            }

        } catch (Exception e) {
            riskScore += 30;
            warnings.add("Malformed or irregular URL structure");
        }

        riskScore = Math.min(100, riskScore);
        scan.put("riskScore", riskScore);
        scan.put("isSuspicious", riskScore >= 40);
        scan.put("warnings", warnings);
        return scan;
    }
}
