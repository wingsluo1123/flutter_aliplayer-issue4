
import 'package:flutter/material.dart';

/// 测试用例列表（二级页）- F-05：显示控制
class ModuleF05Page extends StatelessWidget {
  const ModuleF05Page({Key? key}) : super(key: key);

  static const List<_TestCaseEntry> _testCases = <_TestCaseEntry>[
    _TestCaseEntry(
      caseId: 'F05-001',
      title: '设置视频保持比例黑边填充模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-002',
      title: '设置视频保持比例裁剪填充模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-003',
      title: '设置视频不保持比例平铺模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-004',
      title: '设置视频旋转0度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-005',
      title: '设置视频旋转90度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-006',
      title: '设置视频旋转180度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-007',
      title: '设置视频旋转270度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-008',
      title: '设置视频无镜像模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-009',
      title: '设置视频水平镜像模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-010',
      title: '设置视频垂直镜像模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-011',
      title: '查询当前缩放模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-012',
      title: '查询当前旋转模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-013',
      title: '查询当前镜像模式',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-014',
      title: '获取视频宽度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-015',
      title: '获取视频高度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-016',
      title: '获取视频旋转角度',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-017',
      title: '设置视频背景色',
      level: 'L0',
    ),
    _TestCaseEntry(
      caseId: 'F05-018',
      title: '清空视频画面',
      level: 'L0',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('F-05 显示控制')),
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
