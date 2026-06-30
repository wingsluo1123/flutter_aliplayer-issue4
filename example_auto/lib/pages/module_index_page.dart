import 'package:flutter/material.dart';

/// 功能模块列表（一级页）。由 tool/generate_example_lib.py 生成。
class ModuleIndexPage extends StatelessWidget {
  const ModuleIndexPage({Key? key}) : super(key: key);

  static const List<_ModuleEntry> _modules = <_ModuleEntry>[
    _ModuleEntry(
      id: 'F-01',
      title: '播放器实例与生命周期管理',
      subtitle: '创建并持有播放器实例，按 playerId 多实例管理；释放时回收资源并从实例 Map 中移除 · P0 · 3个测试用例',
    ),
    _ModuleEntry(
      id: 'F-02',
      title: '视频源设置',
      subtitle: '设置 URL 或 Vid 类播放源；URL 方式直接可播；支持流切换 · P0 · 3个测试用例',
    ),
    _ModuleEntry(
      id: 'F-03',
      title: '播放控制',
      subtitle: 'prepare/play/pause/stop/seek 等播控操作；驱动 AVPlayer 状态机迁移 · P0 · 5个测试用例',
    ),
    _ModuleEntry(
      id: 'F-04',
      title: '视频渲染面',
      subtitle: 'AliPlayerView 作为 PlatformView 嵌入 Flutter 视图树；setPlayerView 绑定渲染面 · P0 · 3个测试用例',
    ),
    _ModuleEntry(
      id: 'F-05',
      title: '播放配置 AVPConfig',
      subtitle: '配置缓冲水位、网络超时、HTTP 头、userAgent 等播放参数 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-06',
      title: '轨道管理',
      subtitle: '查询/切换音视频/字幕轨；设置默认码率/清晰度/音频语言 · P1 · 3个测试用例',
    ),
    _ModuleEntry(
      id: 'F-07',
      title: '字幕',
      subtitle: '添加外挂字幕 URL；选择/关闭外挂字幕；字幕回调 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-08',
      title: '截图与缩略图',
      subtitle: '截取当前帧保存为图片；从远端缩略图获取指定位置位图 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-09',
      title: '渲染模式',
      subtitle: '设置缩放/旋转/镜像/背景色等渲染参数 · P0 · 4个测试用例',
    ),
    _ModuleEntry(
      id: 'F-10',
      title: '音量/倍速/静音/循环/快启',
      subtitle: 'volume/speed/muted/loop/autoPlay 等播放属性 · P0 · 4个测试用例',
    ),
    _ModuleEntry(
      id: 'F-11',
      title: '事件回调',
      subtitle: '播放器各类事件透传至 Dart；EventChannel 广播后按 playerId 分发 · P0 · 5个测试用例',
    ),
    _ModuleEntry(
      id: 'F-12',
      title: '列表播放器',
      subtitle: '短视频列表顺序播放与预加载 · P1 · 3个测试用例',
    ),
    _ModuleEntry(
      id: 'F-13',
      title: '直播时移播放器',
      subtitle: '直播回看/时移到指定时间 · P2 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-14',
      title: '视频下载',
      subtitle: 'FlutterAliDownloader 普通明文下载 · P2 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-15',
      title: '媒体预加载',
      subtitle: 'MediaLoader v1/v2 播放前预取媒体数据 · P2 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-16',
      title: '全局设置',
      subtitle: 'FlutterAliPlayerGlobalSettings 全局网络/亮度策略 · P2 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-17',
      title: '全局播放器设置',
      subtitle: 'FlutterAliplayer 静态方法：版本/日志/缓存等 · P2 · 2个测试用例',
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