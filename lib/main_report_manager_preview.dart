import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/reports/native_report_manager_layout.dart';

/// Offline UI review only. This entry point never signs in or calls a server.
/// Report selections print the native R_TYPE; ReportView is the next phase.
void main() => runApp(const ReportManagerPreviewApp());

class ReportManagerPreviewApp extends StatelessWidget {
  const ReportManagerPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    const api = String.fromEnvironment(
      'REPORT_PREVIEW_API',
      defaultValue: 'https://preview.invalid/ords/example/',
    );
    return MaterialApp(
      title: 'DocDiary',
      debugShowCheckedModeBanner: false,
      theme: docDiaryTheme(),
      initialRoute: '/reports',
      routes: {
        '/':
            (context) => Scaffold(
              body: SafeArea(
                child: Center(
                  child: TextButton(
                    onPressed: () async {
                      await Navigator.pushNamed<void>(context, '/reports');
                    },
                    child: const Text('Open Report Manager'),
                  ),
                ),
              ),
            ),
        '/reports':
            (context) => NativeReportManagerLayout(
              centerApi: Uri.parse(api),
              onBack: () => Navigator.pop(context),
              onReport:
                  (report) => debugPrint(
                    'Report Manager UI preview: R_TYPE=${report.nativeType}; '
                    '${report.title}',
                  ),
            ),
      },
    );
  }
}
