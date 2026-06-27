
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-04：播放事件回调
class ModuleF04Page extends StatelessWidget {
  const ModuleF04Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F04-001',
      title: '准备完成事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-002',
      title: '首帧显示事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-003',
      title: '视频大小变化事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-004',
      title: 'seek完成事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-005',
      title: '播放错误事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-006',
      title: '缓冲开始事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-007',
      title: '缓冲进度事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-008',
      title: '缓冲结束事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-009',
      title: '播放完成事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-010',
      title: '播放状态变更事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-011',
      title: '播放器信息事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-012',
      title: 'SEI数据事件回调',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F04-013',
      title: '视频渲染事件回调',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-04 播放事件回调')),
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
