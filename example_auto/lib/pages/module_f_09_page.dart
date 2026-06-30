
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-09：渲染模式
class ModuleF09Page extends StatelessWidget {
  const ModuleF09Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F09-001',
      title: '能设置等比缩放模式并保持画面比例不变形',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F09-002',
      title: '能设置全屏缩放模式并填满渲染区域',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F09-003',
      title: '能设置 90 度旋转并使画面旋转',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F09-004',
      title: '能设置水平镜像并使画面水平翻转',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-09 渲染模式')),
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
