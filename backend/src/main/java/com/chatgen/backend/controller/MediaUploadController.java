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
}
