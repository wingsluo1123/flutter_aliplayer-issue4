
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-03：播放控制
class ModuleF03Page extends StatelessWidget {
  const ModuleF03Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F03-001',
      title: '准备播放器开始播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-002',
      title: '开始或恢复视频播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-003',
      title: '暂停正在播放的视频',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-004',
      title: '暂停后恢复播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-005',
      title: '停止视频播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-006',
      title: '跳转到指定播放位置（精确模式）',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-007',
      title: '跳转到指定播放位置（非精确模式）',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-008',
      title: '重新加载播放器',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-009',
      title: '以指定位置起播',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-010',
      title: '设置精准seek的最大间隔',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-011',
      title: '获取视频总时长',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-012',
      title: '获取当前播放位置',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-013',
      title: '获取已播放时长',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-014',
      title: '获取当前UTC时间',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-015',
      title: '获取已缓存位置',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-016',
      title: '获取当前下载速度',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-03 播放控制')),
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
