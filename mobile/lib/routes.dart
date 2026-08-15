import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/project_detail_screen.dart';
import 'screens/expense_screen.dart';
import 'screens/expense_form_screen.dart';
import 'screens/time_log_edit_screen.dart';
import 'models/expense_log.dart';
import 'models/time_log.dart';
import 'screens/monthly_report_screen.dart';
import 'screens/annual_report_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/settings_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String timer = '/timer';
  static const String projects = '/projects';
  static const String projectDetail = '/project-detail';
  static const String expenses = '/expenses';
  static const String expenseForm = '/expense-form';
  static const String timeLogEdit = '/time-log-edit';
  static const String monthlyReport = '/monthly-report';
  static const String annualReport = '/annual-report';
  static const String premium = '/premium';
  static const String settings = '/settings';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case timer:
        return MaterialPageRoute(builder: (_) => const TimerScreen());
      case projects:
        return MaterialPageRoute(builder: (_) => const ProjectsScreen());
      case projectDetail:
        final projectId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(projectId: projectId),
        );
      case expenses:
        return MaterialPageRoute(builder: (_) => const ExpenseScreen());
      case expenseForm:
        return MaterialPageRoute(
          builder: (_) => ExpenseFormScreen(expense: routeSettings.arguments as ExpenseLog?),
        );
      case timeLogEdit:
        return MaterialPageRoute(
          builder: (_) => TimeLogEditScreen(timeLog: routeSettings.arguments as TimeLog),
        );
      case monthlyReport:
        return MaterialPageRoute(builder: (_) => const MonthlyReportScreen());
      case annualReport:
        return MaterialPageRoute(builder: (_) => const AnnualReportScreen());
      case premium:
        return MaterialPageRoute(builder: (_) => const PremiumScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${routeSettings.name}')),
          ),
        );
    }
  }
}
