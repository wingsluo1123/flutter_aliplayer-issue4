
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-14：媒体预加载
class ModuleF14Page extends StatelessWidget {
  const ModuleF14Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F14-001',
      title: '预加载设置区域会清晰提示当前平台能力状态',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-14 媒体预加载')),
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
