import 'package:flutter/material.dart';
import 'package:device_ip/device_ip.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Home());
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String text = 'Press a button';

  Future<void> run(NetworkType type) async {
    final res = await DeviceIp.getIp(type: type);
    setState(() {
      text =
          'ok: ${res.ok}\n'
          'message: ${res.message}\n'
          'connection: ${res.connection}\n'
          'ipv4: ${res.ipv4}\n'
          'ipv6: ${res.ipv6}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device IP Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(onPressed: () => run(NetworkType.any), child: const Text("Any")),
                ElevatedButton(onPressed: () => run(NetworkType.wifi), child: const Text("Wi-Fi")),
                ElevatedButton(onPressed: () => run(NetworkType.mobile), child: const Text("Mobile")),
              ],
            ),
            const SizedBox(height: 16),
            Text(text),
          ],
        ),
      ),
    );
  }
}
