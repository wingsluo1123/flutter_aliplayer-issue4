import 'package:flutter/material.dart';
import 'package:flutter_aliplayer_example/pages/module_f_01_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_02_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_03_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_04_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_05_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_06_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_07_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_08_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_09_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_10_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_11_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_12_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_13_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_14_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_15_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_16_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_17_page.dart';
import 'package:flutter_aliplayer_example/pages/module_f_18_page.dart';
import 'package:flutter_aliplayer_example/pages/module_index_page.dart';
import 'package:flutter_aliplayer_example/pages/testcase_runner_page.dart';

class AppRoutes {
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
          return _build(settings, const ModuleF01Page());
        case 'F-02':
          return _build(settings, const ModuleF02Page());
        case 'F-03':
          return _build(settings, const ModuleF03Page());
        case 'F-04':
          return _build(settings, const ModuleF04Page());
        case 'F-05':
          return _build(settings, const ModuleF05Page());
        case 'F-06':
          return _build(settings, const ModuleF06Page());
        case 'F-07':
          return _build(settings, const ModuleF07Page());
        case 'F-08':
          return _build(settings, const ModuleF08Page());
        case 'F-09':
          return _build(settings, const ModuleF09Page());
        case 'F-10':
          return _build(settings, const ModuleF10Page());
        case 'F-11':
          return _build(settings, const ModuleF11Page());
        case 'F-12':
          return _build(settings, const ModuleF12Page());
        case 'F-13':
          return _build(settings, const ModuleF13Page());
        case 'F-14':
          return _build(settings, const ModuleF14Page());
        case 'F-15':
          return _build(settings, const ModuleF15Page());
        case 'F-16':
          return _build(settings, const ModuleF16Page());
        case 'F-17':
          return _build(settings, const ModuleF17Page());
        case 'F-18':
          return _build(settings, const ModuleF18Page());
      }
    }

    if (name.startsWith(testCasePrefix)) {
      final String testCaseId = name.substring(testCasePrefix.length);
      return _build(settings, TestCaseRunnerPage(caseId: testCaseId));
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(
        body: Center(child: Text('Unknown route')),
      ),
    );
  }

  static MaterialPageRoute<void> _build(
    RouteSettings settings,
    Widget child,
  ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => child,
    );
  }
}
