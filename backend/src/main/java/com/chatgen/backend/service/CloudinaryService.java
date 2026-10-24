package com.chatgen.backend.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

@Service
public class CloudinaryService {

    private static final Logger log = LoggerFactory.getLogger(CloudinaryService.class);
    private final Cloudinary cloudinary;

    @Value("${cloudinary.cloud-name:demo}")
    private String cloudName;

    public CloudinaryService(Cloudinary cloudinary) {
        this.cloudinary = cloudinary;
    }

    public Map<String, Object> uploadFile(MultipartFile file, String folder) throws IOException {
        String originalFilename = file.getOriginalFilename() != null ? file.getOriginalFilename() : "file";
        String contentType = file.getContentType() != null ? file.getContentType() : "application/octet-stream";

        log.info("Uploading file '{}' (size: {} bytes, type: {}) to Cloudinary folder '{}'",
                originalFilename, file.getSize(), contentType, folder);

        // Detect Cloudinary resource type: image, video (audio/video), or raw (documents, pdf, zip, etc.)
        String resourceType = "auto";
        if (contentType.startsWith("image/")) {
            resourceType = "image";
        } else if (contentType.startsWith("video/") || contentType.startsWith("audio/")) {
            resourceType = "video";
        } else {
            resourceType = "raw";
        }

        try {
            // Upload to Cloudinary cloud storage
            Map<?, ?> uploadResult = cloudinary.uploader().upload(file.getBytes(), ObjectUtils.asMap(
                    "folder", "chatgen/" + folder,
                    "resource_type", resourceType,
                    "use_filename", true,
                    "unique_filename", true
            ));

            String secureUrl = (String) uploadResult.get("secure_url");
            if (secureUrl == null) {
                secureUrl = (String) uploadResult.get("url");
            }

            log.info("Successfully uploaded '{}' to Cloudinary: {}", originalFilename, secureUrl);

            Map<String, Object> response = new HashMap<>();
            response.put("url", secureUrl);
            response.put("public_id", uploadResult.get("public_id"));
            response.put("bytes", uploadResult.get("bytes"));
            response.put("format", uploadResult.get("format"));
            response.put("resource_type", uploadResult.get("resource_type"));
            return response;
        } catch (Exception ex) {
            log.error("Cloudinary upload failed for '{}': {}", originalFilename, ex.getMessage());
            throw new IOException("Failed to upload file to Cloudinary: " + ex.getMessage() +
                    ". Please ensure CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET (or CLOUDINARY_URL) are configured.", ex);
        }
    }
}
