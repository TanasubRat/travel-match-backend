import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy (นโยบายความเป็นส่วนตัว)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: May 2026\n\n'
              'This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You, particularly under the Personal Data Protection Act (PDPA) of Thailand (พระราชบัญญัติคุ้มครองข้อมูลส่วนบุคคล พ.ศ. 2562).\n\n'
              '1. Data We Collect (ข้อมูลที่เราเก็บรวบรวม)\n'
              'We may collect the following personal data to provide and improve our service:\n'
              '• Profile Information: Name, Email Address, and authentication data.\n'
              '• Location Data: Used for finding nearby travel destinations and matches.\n'
              '• Usage Data: Swipes, likes, group interactions, and preferences within the app.\n\n'
              '2. How We Use Your Data (วัตถุประสงค์ในการใช้ข้อมูล)\n'
              'We use your data strictly to:\n'
              '• Provide and maintain our Service (e.g., matching you with travel spots).\n'
              '• Manage Your Account and personalize the experience.\n'
              '• Communicate with you regarding updates or support.\n'
              '• Analyze usage to improve our algorithm.\n\n'
              '3. Data Disclosure (การเปิดเผยข้อมูล)\n'
              'We do not sell your personal data. We may share information with:\n'
              '• Other users in your "Group/Room" (only necessary info like your votes or matches).\n'
              '• Service Providers (e.g., Google Maps API) purely for providing core functionalities.\n\n'
              '4. Your Rights Under PDPA (สิทธิของท่านตามกฎหมาย PDPA)\n'
              'Under the Thai PDPA, you have the right to:\n'
              '• Request access to your personal data.\n'
              '• Request correction of inaccurate data.\n'
              '• Request deletion of your data (Right to be forgotten).\n'
              '• Withdraw your consent at any time.\n\n'
              '5. Contact Us (ติดต่อเรา)\n'
              'If you have any questions about this Privacy Policy or wish to exercise your rights, please contact our support team.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
