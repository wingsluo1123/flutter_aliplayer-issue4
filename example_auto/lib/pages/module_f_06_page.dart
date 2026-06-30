
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-06：轨道管理
class ModuleF06Page extends StatelessWidget {
  const ModuleF06Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F06-001',
      title: '能查询媒体轨道信息并返回轨道列表',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-002',
      title: '能切换视频轨道并改变清晰度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-003',
      title: '能切换音频轨道并改变音轨语言',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-06 轨道管理')),
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
