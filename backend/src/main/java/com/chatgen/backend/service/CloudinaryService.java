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

    /**
     * Deletes an asset from Cloudinary using its public_id.
     * Tries "image", "video", and "raw" resource types to ensure clean deletion.
     */
    public boolean deleteFile(String publicId) {
        if (publicId == null || publicId.trim().isEmpty()) {
            return false;
        }
        String cleanId = publicId.trim();
        try {
            // Try image first (most common)
            Map<?, ?> result = cloudinary.uploader().destroy(cleanId, ObjectUtils.asMap("invalidate", true));
            String status = (String) result.get("result");
            if ("ok".equalsIgnoreCase(status)) {
                log.info("Deleted image from Cloudinary with public_id: {}", cleanId);
                return true;
            }

            // Try video / audio
            result = cloudinary.uploader().destroy(cleanId, ObjectUtils.asMap("resource_type", "video", "invalidate", true));
            status = (String) result.get("result");
            if ("ok".equalsIgnoreCase(status)) {
                log.info("Deleted video/audio from Cloudinary with public_id: {}", cleanId);
                return true;
            }

            // Try raw (documents, pdfs, zips)
            result = cloudinary.uploader().destroy(cleanId, ObjectUtils.asMap("resource_type", "raw", "invalidate", true));
            status = (String) result.get("result");
            if ("ok".equalsIgnoreCase(status)) {
                log.info("Deleted raw file from Cloudinary with public_id: {}", cleanId);
                return true;
            }

            log.warn("Cloudinary asset '{}' deletion reported status: {}", cleanId, status);
            return false;
        } catch (Exception ex) {
            log.error("Failed to delete asset '{}' from Cloudinary: {}", cleanId, ex.getMessage());
            return false;
        }
    }

    /**
     * Deletes an asset given a specific resourceType ("image", "video", "raw").
     */
    public boolean deleteFile(String publicId, String resourceType) {
        if (publicId == null || publicId.trim().isEmpty()) {
            return false;
        }
        try {
            Map<?, ?> result = cloudinary.uploader().destroy(publicId.trim(), ObjectUtils.asMap(
                    "resource_type", resourceType != null ? resourceType : "image",
                    "invalidate", true
            ));
            String status = (String) result.get("result");
            log.info("Cloudinary delete for '{}' (type: {}) result: {}", publicId, resourceType, status);
            return "ok".equalsIgnoreCase(status);
        } catch (Exception ex) {
            log.error("Failed to delete asset '{}' from Cloudinary: {}", publicId, ex.getMessage());
            return false;
        }
    }

    /**
     * Extracts Cloudinary publicId from a secure URL.
     * e.g. https://res.cloudinary.com/dltpal1gr/image/upload/v1729000000/chatgen/attachments/xyz.png -> chatgen/attachments/xyz
     */
    public String extractPublicIdFromUrl(String url) {
        if (url == null || !url.contains("cloudinary.com")) {
            return null;
        }
        try {
            int uploadIdx = url.indexOf("/upload/");
            if (uploadIdx == -1) return null;
            String path = url.substring(uploadIdx + 8);
            // Skip version parameter like v1234567890/
            if (path.startsWith("v") && path.indexOf('/') != -1) {
                int slash = path.indexOf('/');
                String ver = path.substring(1, slash);
                if (ver.chars().allMatch(Character::isDigit)) {
                    path = path.substring(slash + 1);
                }
            }
            // Strip file extension if any
            int dot = path.lastIndexOf('.');
            if (dot != -1) {
                path = path.substring(0, dot);
            }
            return path;
        } catch (Exception ignored) {
            return null;
        }
    }

    /**
     * Deletes a Cloudinary file given its CDN URL.
     */
    public boolean deleteFileByUrl(String url) {
        String publicId = extractPublicIdFromUrl(url);
        if (publicId != null) {
            return deleteFile(publicId);
        }
        return false;
    }
}
