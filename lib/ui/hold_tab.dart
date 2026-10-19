import 'package:flutter/material.dart';

import '../theme.dart';

/// 보류함. 3단계에서 채운다.
class HoldTab extends StatelessWidget {
  const HoldTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '보류함',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '30일 동안 한 번도 안 열어본 사진은 정리할지 물어볼게요.',
              style: TextStyle(
                fontSize: 14,
                color: MehhColors.textMuted,
                height: 1.5,
              ),
            ),
            SizedBox(height: 40),
            Center(
              child: Text(
                '보류한 사진이 없어요',
                style: TextStyle(fontSize: 14, color: MehhColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
