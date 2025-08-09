import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class OwlPlaceholder extends StatefulWidget {
  const OwlPlaceholder({super.key});

  @override
  State<OwlPlaceholder> createState() => _OwlPlaceholderState();
}

class _OwlPlaceholderState extends State<OwlPlaceholder> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/animations/animate1.mp4')
      ..initialize().then((_) {
        setState(() {}); // Ensure the first frame is shown
      })
      ..setLooping(true)
      ..play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _controller.value.isInitialized
          ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          : Container(
              // You can add a loading indicator here if you want
              // or just keep it empty while video is loading
              color: Colors.black, // Placeholder background
              width: 250,
              height: 250,
            ),
    );
  }
}
