import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms and Conditions (ข้อกำหนดและเงื่อนไข)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: May 2026\n\n'
              'Please read these terms and conditions carefully before using Our Service.\n\n'
              '1. Acceptance of Terms (การยอมรับข้อตกลง)\n'
              'By accessing or using the Service, You agree to be bound by these Terms. If You disagree with any part of these Terms, then You may not access the Service.\n\n'
              '2. User Accounts (บัญชีผู้ใช้)\n'
              'When You create an account with Us, You must provide information that is accurate, complete, and current at all times. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of Your account on Our Service.\n\n'
              '3. Use of the App (การใช้งานแอปพลิเคชัน)\n'
              'You agree not to use the application for any illegal or unauthorized purpose. Group sessions, votes, and matches should be used for personal planning and entertainment purposes only.\n\n'
              '4. Third-Party Services (บริการของบุคคลที่สาม)\n'
              'Our Service may contain links to third-party web sites or services that are not owned or controlled by Us (e.g., Google Maps). We assume no responsibility for the content, privacy policies, or practices of any third-party services.\n\n'
              '5. Limitation of Liability (ข้อจำกัดความรับผิด)\n'
              'To the maximum extent permitted by applicable law, in no event shall the Company or its suppliers be liable for any special, incidental, indirect, or consequential damages whatsoever arising out of or in any way related to the use of or inability to use the Service.\n\n'
              '6. Governing Law (กฎหมายที่ใช้บังคับ)\n'
              'These Terms shall be governed and construed in accordance with the laws of Thailand, without regard to its conflict of law provisions.\n\n'
              '7. Changes to Terms (การเปลี่ยนแปลงข้อตกลง)\n'
              'We reserve the right, at Our sole discretion, to modify or replace these Terms at any time. We will provide reasonable notice of any significant changes.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
