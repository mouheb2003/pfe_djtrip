import 'dart:async';

import 'package:flutter/material.dart';

class AutoImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double? height;
  final double? aspectRatio;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showIndicators;
  final Duration interval;

  const AutoImageCarousel({
    super.key,
    required this.imageUrls,
    this.height,
    this.aspectRatio,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showIndicators = true,
    this.interval = const Duration(seconds: 5),
  });

  @override
  State<AutoImageCarousel> createState() => _AutoImageCarouselState();
}

class _AutoImageCarouselState extends State<AutoImageCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant AutoImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.length != widget.imageUrls.length) {
      _index = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.imageUrls.length <= 1) return;

    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.imageUrls.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;

    Widget body;
    if (urls.isEmpty) {
      body = Container(
        color: const Color(0xFFE8E8F6),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Color(0xFF8C93BE), size: 38),
        ),
      );
    } else if (urls.length == 1) {
      body = Image.network(
        urls.first,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFE8E8F6),
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Color(0xFF8C93BE),
              size: 38,
            ),
          ),
        ),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, i) => Image.network(
              urls[i],
              fit: widget.fit,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE8E8F6),
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Color(0xFF8C93BE),
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
          if (widget.showIndicators)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  urls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == _index ? 14 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _index
                          ? Colors.white
                          : Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (widget.aspectRatio != null) {
      body = AspectRatio(aspectRatio: widget.aspectRatio!, child: body);
    }

    if (widget.height != null) {
      body = SizedBox(
        height: widget.height,
        width: double.infinity,
        child: body,
      );
    }

    if (widget.borderRadius != null) {
      body = ClipRRect(borderRadius: widget.borderRadius!, child: body);
    }

    return body;
  }
}
