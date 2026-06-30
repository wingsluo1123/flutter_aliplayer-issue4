import 'package:flutter/material.dart';
import 'package:flutter_aliplayer_example/pages/module_index_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_01_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f01_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f01_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f01_003_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_02_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f02_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f02_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f02_003_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_03_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f03_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f03_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f03_003_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f03_004_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f03_005_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_04_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f04_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f04_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f04_003_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_05_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f05_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f05_002_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_06_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f06_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f06_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f06_003_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_07_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f07_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f07_002_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_08_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f08_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f08_002_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_09_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f09_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f09_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f09_003_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f09_004_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_10_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f10_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f10_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f10_003_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f10_004_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_11_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f11_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f11_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f11_003_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f11_004_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f11_005_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_12_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f12_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f12_002_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f12_003_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_13_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f13_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f13_002_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_14_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f14_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f14_002_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_15_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f15_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f15_002_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_16_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f16_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f16_002_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_17_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f17_001_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_f17_002_page.dart';
class AppRoutes {
  // Use '/' as the entry route. If initialRoute is not '/',
  // Flutter will still create '/' then push initialRoute, which makes the
  // back button return to an unintended "unknown route" page.
  static const String moduleIndex = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String name = settings.name ?? moduleIndex;

    if (name == moduleIndex || name == '/') {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const ModuleIndexPage(),
      );
    }

    const String modulePrefix = '/module/';
    const String testCasePrefix = '/testcase/';
    
    if (name.startsWith(modulePrefix)) {
      final String moduleId = name.substring(modulePrefix.length);
      switch (moduleId) {
        case 'F-01':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF01Page(),
          );
        case 'F-02':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF02Page(),
          );
        case 'F-03':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF03Page(),
          );
        case 'F-04':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF04Page(),
          );
        case 'F-05':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF05Page(),
          );
        case 'F-06':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF06Page(),
          );
        case 'F-07':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF07Page(),
          );
        case 'F-08':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF08Page(),
          );
        case 'F-09':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF09Page(),
          );
        case 'F-10':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF10Page(),
          );
        case 'F-11':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF11Page(),
          );
        case 'F-12':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF12Page(),
          );
        case 'F-13':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF13Page(),
          );
        case 'F-14':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF14Page(),
          );
        case 'F-15':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF15Page(),
          );
        case 'F-16':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF16Page(),
          );
        case 'F-17':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const ModuleF17Page(),
          );      }
    }
    
    if (name.startsWith(testCasePrefix)) {
      final String testCaseId = name.substring(testCasePrefix.length);
      switch (testCaseId) {
        case 'F01-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF01001Page(),
          );
        case 'F01-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF01002Page(),
          );
        case 'F01-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF01003Page(),
          );
        case 'F02-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF02001Page(),
          );
        case 'F02-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF02002Page(),
          );
        case 'F02-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF02003Page(),
          );
        case 'F03-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF03001Page(),
          );
        case 'F03-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF03002Page(),
          );
        case 'F03-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF03003Page(),
          );
        case 'F03-004':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF03004Page(),
          );
        case 'F03-005':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF03005Page(),
          );
        case 'F04-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF04001Page(),
          );
        case 'F04-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF04002Page(),
          );
        case 'F04-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF04003Page(),
          );
        case 'F05-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF05001Page(),
          );
        case 'F05-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF05002Page(),
          );
        case 'F06-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF06001Page(),
          );
        case 'F06-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF06002Page(),
          );
        case 'F06-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF06003Page(),
          );
        case 'F07-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF07001Page(),
          );
        case 'F07-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF07002Page(),
          );
        case 'F08-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF08001Page(),
          );
        case 'F08-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF08002Page(),
          );
        case 'F09-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF09001Page(),
          );
        case 'F09-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF09002Page(),
          );
        case 'F09-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF09003Page(),
          );
        case 'F09-004':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF09004Page(),
          );
        case 'F10-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF10001Page(),
          );
        case 'F10-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF10002Page(),
          );
        case 'F10-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF10003Page(),
          );
        case 'F10-004':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF10004Page(),
          );
        case 'F11-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF11001Page(),
          );
        case 'F11-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF11002Page(),
          );
        case 'F11-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF11003Page(),
          );
        case 'F11-004':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF11004Page(),
          );
        case 'F11-005':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF11005Page(),
          );
        case 'F12-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF12001Page(),
          );
        case 'F12-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF12002Page(),
          );
        case 'F12-003':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF12003Page(),
          );
        case 'F13-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF13001Page(),
          );
        case 'F13-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF13002Page(),
          );
        case 'F14-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF14001Page(),
          );
        case 'F14-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF14002Page(),
          );
        case 'F15-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF15001Page(),
          );
        case 'F15-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF15002Page(),
          );
        case 'F16-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF16001Page(),
          );
        case 'F16-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF16002Page(),
          );
        case 'F17-001':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF17001Page(),
          );
        case 'F17-002':
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TestCaseF17002Page(),
          );      }
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(
        body: Center(child: Text('Unknown route')),
      ),
    );
  }
}
