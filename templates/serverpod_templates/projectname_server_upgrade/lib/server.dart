import 'dart:io';
import 'package:serverpod/serverpod.dart';

import 'package:projectname_server/src/web/routes/root.dart';

import 'src/generated/protocol.dart';
import 'src/generated/endpoints.dart';

// This is the starting point of your Serverpod server. In most cases, you will
// only need to make additions to this file if you add future calls,  are
// configuring Relic (Serverpod's web-server), or need custom setup work.

void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.

  // You can set the serverId using either:
  // 1. A command-line flag: --server-id=<value>
  // 2. The 'SERVER_ID' environment variable
  //
  // If both are set, the command-line flag takes precedence.
  // If neither is set, the default value 'default' will be used.
  final serverId = Platform.environment['SERVER_ID'] ?? 'default';
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    serverId: serverId,
  );

  // If you are using any future calls, they need to be registered here.
  // pod.registerFutureCall(ExampleFutureCall(), 'exampleFutureCall');

  // Setup a default page at the web root.
  pod.webServer.addRoute(RouteRoot(), '/');
  pod.webServer.addRoute(RouteRoot(), '/index.html');
  // Serve all files in the /static directory.
  pod.webServer.addRoute(
    RouteStaticDirectory(serverDirectory: 'static', basePath: '/'),
    '/*',
  );

  // Start the server.
  await pod.start();
}
