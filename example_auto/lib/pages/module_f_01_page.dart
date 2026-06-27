
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-01：播放器创建与生命周期
class ModuleF01Page extends StatelessWidget {
  const ModuleF01Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F01-001',
      title: '创建播放器实例并指定唯一标识',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-002',
      title: '创建播放器实例不指定标识',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-003',
      title: '在原生端创建播放器实例',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-004',
      title: '同步释放播放器资源',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-005',
      title: '异步释放播放器资源',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-006',
      title: '通过工厂类创建单播放器',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-007',
      title: '通过工厂类创建列表播放器',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-008',
      title: '通过工厂类创建时移播放器',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F01-009',
      title: '创建多个播放器实例并行运行',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-01 播放器创建与生命周期')),
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
