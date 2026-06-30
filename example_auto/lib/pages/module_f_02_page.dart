
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-02：视频源设置
class ModuleF02Page extends StatelessWidget {
  const ModuleF02Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F02-001',
      title: '能设置 HTTP URL 播放源并正常起播',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F02-002',
      title: '能设置 HTTPS URL 播放源并正常起播',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F02-003',
      title: '能切换播放流地址并平滑切换到新流',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-02 视频源设置')),
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
