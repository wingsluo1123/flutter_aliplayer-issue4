
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-12：列表播放器
class ModuleF12Page extends StatelessWidget {
  const ModuleF12Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F12-001',
      title: '能添加 URL 播放源到列表并成功加入',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F12-002',
      title: '能切换到下一个播放源并播放下一项内容',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F12-003',
      title: '能切换到上一个播放源并播放上一项内容',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-12 列表播放器')),
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
