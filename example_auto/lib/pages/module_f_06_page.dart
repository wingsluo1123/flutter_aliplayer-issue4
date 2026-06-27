
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-06：播放配置
class ModuleF06Page extends StatelessWidget {
  const ModuleF06Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F06-001',
      title: '开启循环播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-002',
      title: '关闭循环播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-003',
      title: '开启自动播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-004',
      title: '关闭自动播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-005',
      title: '开启静音播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-006',
      title: '关闭静音播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-007',
      title: '设置播放器音量',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-008',
      title: '查询当前音量值',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-009',
      title: '设置1倍速正常播放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-010',
      title: '设置2倍速快放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-011',
      title: '设置0.5倍速慢放',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-012',
      title: '开启硬件解码',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-013',
      title: '关闭硬件解码使用软件解码',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-014',
      title: '查询当前循环播放状态',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-015',
      title: '查询当前自动播放状态',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F06-016',
      title: '查询当前硬件解码状态',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-06 播放配置')),
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
