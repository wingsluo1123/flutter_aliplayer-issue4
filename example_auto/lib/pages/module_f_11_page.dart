
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-11：事件回调
class ModuleF11Page extends StatelessWidget {
  const ModuleF11Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F11-001',
      title: '能在 prepare 完成时触发准备完成事件',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F11-002',
      title: '能在首帧渲染时触发渲染开始事件',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F11-003',
      title: '能在视频结束时触发播放完成事件',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F11-004',
      title: '能在播放异常时触发播放错误事件',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F11-005',
      title: '能在画面尺寸变化时触发视频尺寸变化事件',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-11 事件回调')),
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
