package com.chatgen.backend.controller;

import com.chatgen.backend.service.CloudinaryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api/media")
public class MediaUploadController {

    private final CloudinaryService cloudinaryService;

    public MediaUploadController(CloudinaryService cloudinaryService) {
        this.cloudinaryService = cloudinaryService;
    }

    @PostMapping("/upload")
    public ResponseEntity<?> uploadMedia(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "folder", defaultValue = "attachments") String folder
    ) {
        try {
            Map<String, Object> result = cloudinaryService.uploadFile(file, folder);
            return ResponseEntity.ok(result);
        } catch (IOException e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping
    public ResponseEntity<?> deleteMedia(
            @RequestParam(value = "publicId", required = false) String publicId,
            @RequestParam(value = "url", required = false) String url,
            @RequestParam(value = "resourceType", required = false) String resourceType
    ) {
        boolean deleted = false;
        if (publicId != null && !publicId.trim().isEmpty()) {
            deleted = resourceType != null 
                    ? cloudinaryService.deleteFile(publicId.trim(), resourceType.trim())
                    : cloudinaryService.deleteFile(publicId.trim());
        } else if (url != null && !url.trim().isEmpty()) {
            deleted = cloudinaryService.deleteFileByUrl(url.trim());
        } else {
            return ResponseEntity.badRequest().body(Map.of("error", "Either 'publicId' or 'url' must be provided."));
        }

        return ResponseEntity.ok(Map.of(
                "success", deleted,
                "message", deleted ? "Asset successfully removed from Cloudinary." : "Asset was already removed or not found."
        ));
    }
}
