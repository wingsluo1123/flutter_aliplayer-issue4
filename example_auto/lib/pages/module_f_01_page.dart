
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-01：播放器创建与管理
class ModuleF01Page extends StatelessWidget {
  const ModuleF01Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F01-001',
      title: '单播放器创建后可完成视图绑定',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-002',
      title: '列表播放器创建后可进入可操作状态',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-003',
      title: '直播时移播放器销毁后可回到初始状态',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-01 播放器创建与管理')),
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
