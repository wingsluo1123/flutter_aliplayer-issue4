
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import premierlibrary from 'libpremierlibrary.so';

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    console.info('[EntryAbility] premierlibrary loaded: ' + (premierlibrary ? 'success' : 'failed'))
    GeneratedPluginRegistrant.registerWith(flutterEngine)
  }
}
