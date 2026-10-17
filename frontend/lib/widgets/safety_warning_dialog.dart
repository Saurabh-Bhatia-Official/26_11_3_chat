import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SafetyWarningDialog extends StatelessWidget {
  final String url;
  final int riskScore;
  final List<String> warnings;
  final VoidCallback onProceedAnyway;

  const SafetyWarningDialog({
    super.key,
    required this.url,
    required this.riskScore,
    required this.warnings,
    required this.onProceedAnyway,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security, color: Color(0xFFEF4444), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Smart Safety Guardian Alert',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    'Risk Score: $riskScore/100',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SUSPICIOUS',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Target URL:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  color: Color(0xFF60A5FA),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Identified Threats:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel & Stay Safe', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onProceedAnyway();
          },
          child: const Text('Proceed with Caution'),
        ),
      ],
    );
  }
}
