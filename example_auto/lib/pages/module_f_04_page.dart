
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-04：视频渲染面
class ModuleF04Page extends StatelessWidget {
  const ModuleF04Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F04-001',
      title: '能嵌入视频渲染面并显示视频画面',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-002',
      title: '能绑定渲染面与播放器渲染画面到指定区域',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-003',
      title: '能切换渲染面类型并正常显示画面',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-04 视频渲染面')),
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
