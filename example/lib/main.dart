import 'package:flutter/material.dart';
import 'package:lecle_player/lecle_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Lecle Player Example',
      home: LecleExample(),
    );
  }
}

class LecleExample extends StatefulWidget {
  const LecleExample({super.key});

  @override
  State<LecleExample> createState() => _LecleExampleState();
}

class _LecleExampleState extends State<LecleExample> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecle Player Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              child: LeclePlayer.createPlayer(
                defaultSelectionOptions: LeclePlayerDefaultSelectionOptions(
                  defaultQualitySelectors: [DefaultSelectorLabel('1080p')],
                ),
                video: LeclePlayerVideo.youtubeWithUrl(
                  url: 'https://www.youtube.com/watch?v=rWbo_sJSZJ0',
                  fetchQualities: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
