
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-09：PlatformView渲染视图
class ModuleF09Page extends StatelessWidget {
  const ModuleF09Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F09-001',
      title: '创建渲染视图并绑定播放器',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F09-002',
      title: '渲染视图跟随Widget位置移动',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F09-003',
      title: '渲染视图跟随Widget大小变化',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F09-004',
      title: '多个渲染视图分别播放不同视频',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-09 PlatformView渲染视图')),
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
