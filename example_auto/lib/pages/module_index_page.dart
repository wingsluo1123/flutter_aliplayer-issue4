import 'package:flutter/material.dart';

/// 功能模块列表（一级页）。由 tool/generate_example_lib.py 生成。
class ModuleIndexPage extends StatelessWidget {
  const ModuleIndexPage({Key? key}) : super(key: key);

  static const List<_ModuleEntry> _modules = <_ModuleEntry>[
    _ModuleEntry(
      id: 'F-01',
      title: '播放器创建与管理',
      subtitle: '创建单播放器、列表播放器、直播时移播放器，并支持销毁与释放。 · P0 · 3个测试用例',
    ),
    _ModuleEntry(
      id: 'F-02',
      title: '播放控制',
      subtitle: '支持播放、暂停、停止、拖动进度、倍速与直播时移控制。 · P0 · 4个测试用例',
    ),
    _ModuleEntry(
      id: 'F-03',
      title: '播放源设置',
      subtitle: '支持 URL、播放列表和直播数据源等不同播放源输入方式。 · P0 · 3个测试用例',
    ),
    _ModuleEntry(
      id: 'F-04',
      title: '视频渲染',
      subtitle: '支持播放器视图嵌入、缩放、旋转、镜像和背景色显示。 · P0 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-05',
      title: '音量控制',
      subtitle: '支持音量调节、静音切换等基础声音控制。 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-06',
      title: '媒体信息获取',
      subtitle: '支持查看视频尺寸、时长、当前位置和缓冲进度等媒体信息。 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-07',
      title: '事件回调',
      subtitle: '支持准备完成、首帧、状态变化、缓冲和完成等事件回调。 · P0 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-08',
      title: '清晰度切换',
      subtitle: '支持默认带宽、默认分辨率以及多轨视频的清晰度选择。 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-09',
      title: '字幕支持',
      subtitle: '支持添加外挂字幕、启用字幕和关闭字幕显示。 · P2 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-10',
      title: '截图与缩略图',
      subtitle: '支持播放截图，以及缩略图能力的状态提示。 · P2 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-11',
      title: '画中画',
      subtitle: '支持在具备小窗播放能力的设备上进入画中画并持续播放。 · P2 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-12',
      title: '悬浮窗播放',
      subtitle: '针对不支持悬浮窗的设备提供明确提示或安全降级处理。 · P2 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-13',
      title: '视频下载',
      subtitle: '支持基于 STS 凭证准备下载、开始下载并查看进度。 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-14',
      title: '媒体预加载',
      subtitle: '在当前演示版本中展示预加载入口及其平台可用性状态。 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-15',
      title: '全局设置',
      subtitle: '支持日志级别、网络能力和本地缓存等全局配置项的统一保存。 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-16',
      title: '播放器配置',
      subtitle: '支持缓冲时长、超时时间、重试次数和代理地址等播放配置。 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-17',
      title: '滤镜特效',
      subtitle: '支持在演示界面中切换滤镜样式并即时预览效果。 · P2 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-18',
      title: 'DRM 支持',
      subtitle: '支持录入 DRM 鉴权信息并完成受保护内容的起播校验。 · P2 · 1个测试用例',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('功能模块')),
      body: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _modules.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final _ModuleEntry e = _modules[index];
          return ListTile(
            key: Key('item_module_' + e.id),
            title: Text(e.id + ' ' + e.title),
            subtitle: Text(e.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/module/' + e.id),
          );
        },
      ),
    );
  }
}

class _ModuleEntry {
  const _ModuleEntry({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}