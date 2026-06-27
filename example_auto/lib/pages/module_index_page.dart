import 'package:flutter/material.dart';

/// 功能模块列表（一级页）。由 tool/generate_example_lib.py 生成。
class ModuleIndexPage extends StatelessWidget {
  const ModuleIndexPage({Key? key}) : super(key: key);

  static const List<_ModuleEntry> _modules = <_ModuleEntry>[
    _ModuleEntry(
      id: 'F-01',
      title: '播放器创建与生命周期',
      subtitle: '创建、释放、销毁播放器实例 · P0 · 9个测试用例',
    ),
    _ModuleEntry(
      id: 'F-02',
      title: '视频源设置',
      subtitle: '设置 URL、VID+STS、VID+Auth、VID+MPS、LiveSts 等视频源 · P0 · 4个测试用例',
    ),
    _ModuleEntry(
      id: 'F-03',
      title: '播放控制',
      subtitle: 'play、pause、stop、seek、prepare、reload 等控制 · P0 · 16个测试用例',
    ),
    _ModuleEntry(
      id: 'F-04',
      title: '播放事件回调',
      subtitle: 'onPrepared、onRenderingStart、onStateChanged、onCompletion、onError 等 · P0 · 13个测试用例',
    ),
    _ModuleEntry(
      id: 'F-05',
      title: '显示控制',
      subtitle: '旋转、缩放、镜像、Alpha 渲染模式、背景色 · P0 · 18个测试用例',
    ),
    _ModuleEntry(
      id: 'F-06',
      title: '播放配置',
      subtitle: '循环播放、自动播放、静音、音量、倍速、硬件解码 · P0 · 16个测试用例',
    ),
    _ModuleEntry(
      id: 'F-07',
      title: '播放器通用配置',
      subtitle: 'setConfig、setPlayConfig、setOption 等通用配置 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-08',
      title: '日志与调试',
      subtitle: 'enableConsoleLog、setLogLevel、setLogInfoCallBack 等 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-09',
      title: 'PlatformView渲染视图',
      subtitle: 'PlatformView 嵌入原生播放器视图 · P0 · 4个测试用例',
    ),
    _ModuleEntry(
      id: 'F-10',
      title: '截图',
      subtitle: '视频截图保存到指定路径 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-11',
      title: '字幕',
      subtitle: '外挂字幕添加与选择 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-12',
      title: '缩略图',
      subtitle: '视频缩略图获取（指定位置） · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-13',
      title: '多码率切换',
      subtitle: '选择不同清晰度 Track、码率、语言 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-14',
      title: '直播流',
      subtitle: '直播源设置、清晰度切换 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-15',
      title: '直播时移',
      subtitle: '时移播放、时间获取、时移跳转 · P1 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-16',
      title: '短视频列表播放',
      subtitle: '列表播放、预加载、前后切换 · P1 · 4个测试用例',
    ),
    _ModuleEntry(
      id: 'F-17',
      title: '视频下载',
      subtitle: '离线下载视频 · P1 · 3个测试用例',
    ),
    _ModuleEntry(
      id: 'F-18',
      title: '媒体预加载V1/V2',
      subtitle: '媒体资源预加载 · P2 · 2个测试用例',
    ),
    _ModuleEntry(
      id: 'F-19',
      title: '本地缓存',
      subtitle: '开启/关闭本地缓存、缓存配置、缓存清理 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-20',
      title: '全局设置',
      subtitle: 'DNS、HttpDNS、网络策略、环境设置等 · P1 · 1个测试用例',
    ),
    _ModuleEntry(
      id: 'F-21',
      title: '滤镜处理',
      subtitle: '视频滤镜配置（锐化、超分） · P2 · 1个测试用例',
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