
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-03：播放控制
class ModuleF03Page extends StatelessWidget {
  const ModuleF03Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F03-001',
      title: '能准备播放器进入可播放状态',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-002',
      title: '能开始播放并渲染视频画面',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-003',
      title: '能暂停播放并保留当前帧',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-004',
      title: '能停止播放并回到待播状态',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F03-005',
      title: '能精准跳转到指定位置',
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
