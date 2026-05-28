
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-03：播放源设置
class ModuleF03Page extends StatelessWidget {
  const ModuleF03Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F03-001',
      title: '输入 URL 后可直接完成单视频起播',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-002',
      title: '自定义资源可加入列表并被点选播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-003',
      title: '直播流地址提交后可进入直播播放状态',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-03 播放源设置')),
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
