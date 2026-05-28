
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

// 尝试预先导入 native 模块
import premierlibrary from 'libpremierlibrary.so';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    // 检查 native 模块是否加载
    console.info('[EntryAbility] premierlibrary loaded: ' + (premierlibrary ? 'success' : 'failed'));
    
    GeneratedPluginRegistrant.registerWith(flutterEngine)
  }
}
