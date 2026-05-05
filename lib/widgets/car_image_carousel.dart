import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CarImageCarousel extends StatefulWidget {
  final List<String> images;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final Function(int)? onTap;

  const CarImageCarousel({
    super.key,
    required this.images,
    this.height,
    this.width,
    this.borderRadius,
    this.onTap,
  });

  @override
  State<CarImageCarousel> createState() => _CarImageCarouselState();
}

class _CarImageCarouselState extends State<CarImageCarousel> {
  int _currentIndex = 0;
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: widget.borderRadius,
        ),
        child: const Icon(Icons.directions_car, size: 50, color: Colors.grey),
      );
    }

    Widget content = Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: widget.borderRadius ?? BorderRadius.zero,
                child: GestureDetector(
                  onTap: widget.onTap != null ? () => widget.onTap!(index) : null,
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.error_outline, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

    if (widget.height != null || widget.width != null) {
      return SizedBox(
        height: widget.height,
        width: widget.width ?? double.infinity,
        child: content,
      );
    }

    return content;
  }
}
