
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-10：音量/倍速/静音/循环/快启
class ModuleF10Page extends StatelessWidget {
  const ModuleF10Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F10-001',
      title: '能调节音量并改变播放音量大小',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F10-002',
      title: '能调节播放倍速并改变播放速度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F10-003',
      title: '能静音播放并关闭声音输出',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F10-004',
      title: '能开启循环播放并在结束后自动重播',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-10 音量/倍速/静音/循环/快启')),
      body: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _testCases.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final _TestCaseEntry e = _testCases[index];
          return ListTile(
            key: Key('item_testcase_' + e.caseId),
            title: Text(e.caseId + ' ' + e.title),
            subtitle: Text('优先级: ' + e.level),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/testcase/' + e.caseId),
          );
        },
      ),
    );
  }
}

class _TestCaseEntry {
  const _TestCaseEntry({
    required this.caseId,
    required this.title,
    required this.level,
  });

  final String caseId;
  final String title;
  final String level;
}
