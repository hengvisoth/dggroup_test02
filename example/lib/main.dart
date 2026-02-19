import 'package:device_ip/model/result_model.dart';
import 'package:flutter/material.dart';
import 'package:device_ip/device_ip.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: Home());
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String text = 'Press a button';
  IpResult? result;

  Future<void> run(NetworkType type) async {
    final res = await DeviceIp.getIp(type: type);
    final ipLines = <String>[];
    if (res.ipv4.isNotEmpty) ipLines.add('ipv4: ${res.ipv4}');
    if (res.ipv6.isNotEmpty) ipLines.add('ipv6: ${res.ipv6}');

    setState(() {
      text = ' ${res.message}';
      if (ipLines.isNotEmpty) {
        text = '$text\n${ipLines.join('\n')}';
      }
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
