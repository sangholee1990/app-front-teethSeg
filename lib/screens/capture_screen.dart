import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_icon_snackbar/flutter_icon_snackbar.dart';
import 'package:teeth_seg/theme/app_colors.dart';
import 'package:teeth_seg/models/history_item.dart';
import 'package:teeth_seg/utils/logger.dart';

enum CaptureState { upload, loading, result }

class CaptureScreen extends StatefulWidget {
  final VoidCallback onSave;

  const CaptureScreen({super.key, required this.onSave});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CaptureState _state = CaptureState.upload;
  Uint8List? _imageBytes;
  Size? _originalImageSize;
  DetectionResult? _result;
  bool _isImageZoomed = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final decoded = await decodeImageFromList(bytes);

    setState(() {
      _originalImageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
      _imageBytes = bytes;
      _state = CaptureState.loading;
    });

    try {
      final response = await _sendToApi(pickedFile.name, bytes);
      setState(() {
        _result = response;
        _state = CaptureState.result;
      });
    } catch (e) {
      logger.e("API 에러: $e");
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        } else {
          errorMsg = '분석 중 오류가 발생했습니다:\n$errorMsg';
        }
        IconSnackBar.show(
          context,
          snackBarType: SnackBarType.fail,
          label: errorMsg,
          behavior: SnackBarBehavior.floating,
        );
      }
      setState(() {
        _state = CaptureState.upload;
      });
    }
  }

  Future<DetectionResult> _sendToApi(String filename, Uint8List bytes) async {
    final String apiUrl = dotenv.get('API_URL', fallback: 'http://49.247.41.71:9920');
    final String fullUrl = apiUrl.endsWith('/api/detectTeeth') ? apiUrl : '$apiUrl/api/detectTeeth';
    final url = Uri.parse(fullUrl);
    final request = http.MultipartRequest('POST', url);
    request.headers['accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: MediaType('image', 'png')),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      final data = jsonDecode(responseBody);
      logger.i('data : $data');
      final dataPayload = data['data'];

      List<List<Offset>> parsedPolygons = [];

      List<BoundingBox> parsedBoxes = [];
      if (dataPayload != null && dataPayload is List) {
        parsedBoxes = dataPayload.map<BoundingBox>((det) {
          return BoundingBox(
            xmin: det['x1']?.toDouble() ?? 0.0,
            ymin: det['y1']?.toDouble() ?? 0.0,
            xmax: det['x2']?.toDouble() ?? 0.0,
            ymax: det['y2']?.toDouble() ?? 0.0,
            className: det['class_name'] ?? '',
            confidence: det['probability']?.toDouble() ?? 0.0,
          );
        }).toList();
      }

      if (parsedPolygons.isEmpty && parsedBoxes.isEmpty) {
        throw Exception('치아를 인식할 수 없습니다.\n올바른 구강 사진인지 다시 확인해 주세요.');
      }

      return DetectionResult(polygons: parsedPolygons, boundingBoxes: parsedBoxes);
    } else {
      throw Exception('API Error: $responseBody');
    }
  }

  Future<void> _saveToHistory() async {
    if (_result == null) return;
    
    int normal = 0;
    int cavity = 0;
    int prosthesis = 0;

    for (var box in _result!.boundingBoxes) {
      if (box.confidence < 0.25) continue;
      final cls = box.className.toLowerCase();
      if (cls == 'cavity' || cls == 'caries') {
        cavity++;
      } else if (cls == 'crack') {
        prosthesis++;
      } else if (cls == 'tooth') {
        normal++;
      }
    }

    final item = HistoryItem(
      date: DateTime.now().millisecondsSinceEpoch,
      total: normal + cavity + prosthesis,
      normal: normal,
      cavity: cavity,
      prosthesis: prosthesis,
    );

    await HistoryManager.saveHistory(item);
    widget.onSave();
  }

  void _reset() {
    setState(() {
      _state = CaptureState.upload;
      _imageBytes = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case CaptureState.upload:
        return _buildUploadState();
      case CaptureState.loading:
        return _buildLoadingState();
      case CaptureState.result:
        return _buildResultState();
    }
  }

  Widget _buildUploadState() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('구강 사진 촬영/업로드', style: TextStyle(color: AppColors.slate800, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('AI가 사진을 분석하여 치아 상태를 판별합니다.', style: TextStyle(color: AppColors.slate500, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showPickerOptions(context),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.sky50,
                          border: Border.all(color: AppColors.sky300, width: 2, style: BorderStyle.none),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: CustomPaint(
                          painter: DashedBorderPainter(color: AppColors.sky300, radius: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4))]),
                                child: const Icon(Icons.add_a_photo_rounded, size: 40, color: AppColors.sky500),
                              ),
                              const SizedBox(height: 24),
                              const Text('터치하여 사진 등록', style: TextStyle(color: AppColors.sky700, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text('스마트폰 카메라로 직접 촬영하거나\n갤러리에서 이미지를 선택해 주세요.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.sky600, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.slate400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('촬영 팁', style: TextStyle(color: AppColors.slate700, fontSize: 14, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('• 밝은 곳에서 흔들리지 않게 촬영하세요.\n• 입을 벌려 치아가 최대한 많이 보이게 하세요.', style: TextStyle(color: AppColors.slate600, fontSize: 12, height: 1.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('갤러리 선택'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('카메라 촬영'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 4),
          SizedBox(height: 24),
          Text('AI 구강 분석 중', style: TextStyle(color: AppColors.slate800, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('첨단 인공지능 모델이 충치 및\n보철 여부를 판별하고 있습니다.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.slate500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    int normal = 0;
    int cavity = 0;
    int prosthesis = 0;

    if (_result != null) {
      for (var box in _result!.boundingBoxes) {
        if (box.confidence < 0.25) continue;
        final cls = box.className.toLowerCase();
        if (cls == 'cavity' || cls == 'caries') {
          cavity++;
        } else if (cls == 'prosthesis' || cls == 'crown' || cls == 'implant') {
          prosthesis++;
        } else {
          normal++;
        }
      }
    }
    int total = normal + cavity + prosthesis;

    Color opinionColor;
    Color opinionGradientStart;
    Color opinionGradientEnd;
    String opinionText;
    String opinionSubtext;

    if (cavity > 0) {
      opinionColor = AppColors.red500;
      opinionGradientStart = AppColors.red500;
      opinionGradientEnd = AppColors.red600;
      opinionText = '충치가 의심되는 치아가 $cavity개 발견되었습니다.';
      opinionSubtext = '빠른 시일 내에 치과 방문을 권장합니다.';
    } else if (prosthesis > 0) {
      opinionColor = AppColors.amber500;
      opinionGradientStart = AppColors.amber500;
      opinionGradientEnd = AppColors.amber600;
      opinionText = '기존 보철물이 $prosthesis개 확인됩니다.';
      opinionSubtext = '파손 방지를 위해 꾸준히 관리해주세요.';
    } else {
      opinionColor = AppColors.green500;
      opinionGradientStart = AppColors.green500;
      opinionGradientEnd = const Color(0xFF14b8a6); // teal-500
      opinionText = '충치 의심 소견이 없습니다.';
      opinionSubtext = '매우 건강한 구강 상태를 유지 중입니다!';
    }

    return Container(
      color: AppColors.slate50,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _reset,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: AppColors.slate600),
                  ),
                ),
                const Text('판별 결과', style: TextStyle(color: AppColors.slate800, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: _isImageZoomed ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 90),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0f172a),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 8))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ImageWithPolygons(
                        imageBytes: _imageBytes!,
                        originalSize: _originalImageSize!,
                        result: _result,
                        maxWidth: constraints.maxWidth,
                        onZoomChanged: (isZoomed) {
                          if (_isImageZoomed != isZoomed) {
                            setState(() => _isImageZoomed = isZoomed);
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('인식된 총 치아', style: TextStyle(color: AppColors.slate500, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          Text('${total}개', style: const TextStyle(color: AppColors.sky600, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: AppColors.slate100, height: 1),
                      ),
                      Row(
                        children: [
                          _buildStatCard('정상', normal, AppColors.green50, AppColors.green100, AppColors.green600, AppColors.green700),
                          const SizedBox(width: 12),
                          _buildStatCard('충치', cavity, AppColors.red50, AppColors.red100, AppColors.red600, AppColors.red700),
                          const SizedBox(width: 12),
                          _buildStatCard('크랙', prosthesis, AppColors.amber50, AppColors.amber100, AppColors.amber600, AppColors.amber700),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [opinionGradientStart, opinionGradientEnd]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: opinionColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.medical_information_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('AI 종합 소견', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(opinionText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(opinionSubtext, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveToHistory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slate800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 5,
                  ),
                  child: const Text('기기에 저장 및 이력 보기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, Color bg, Color border, Color titleColor, Color valColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$value', style: TextStyle(color: valColor, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class ImageWithPolygons extends StatefulWidget {
  final Uint8List imageBytes;
  final Size originalSize;
  final DetectionResult? result;
  final double maxWidth;
  final ValueChanged<bool>? onZoomChanged;

  const ImageWithPolygons({
    super.key,
    required this.imageBytes,
    required this.originalSize,
    required this.result,
    required this.maxWidth,
    this.onZoomChanged,
  });

  @override
  State<ImageWithPolygons> createState() => _ImageWithPolygonsState();
}

class _ImageWithPolygonsState extends State<ImageWithPolygons> {
  final TransformationController _transformationController = TransformationController();
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onZoomChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final zoom = _transformationController.value.getMaxScaleOnAxis();
    if (zoom != _currentZoom) {
      setState(() {
        _currentZoom = zoom;
      });
      widget.onZoomChanged?.call(zoom > 1.0);
    }
  }

  void _zoom(double factor) {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    double newScale = (currentScale * factor).clamp(1.0, 10.0);
    
    if (newScale <= 1.0) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    
    final realFactor = newScale / currentScale;
    final scaledHeight = widget.originalSize.height * (widget.maxWidth / widget.originalSize.width);
    final center = Offset(widget.maxWidth / 2, scaledHeight / 2);
    
    final scaleMatrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(realFactor, realFactor, 1.0)
      ..translate(-center.dx, -center.dy);
      
    final newMatrix = scaleMatrix * currentMatrix;
    
    final double minDx = widget.maxWidth - (widget.maxWidth * newScale);
    final double minDy = scaledHeight - (scaledHeight * newScale);
    
    double dx = newMatrix.getTranslation().x.clamp(minDx, 0.0);
    double dy = newMatrix.getTranslation().y.clamp(minDy, 0.0);
    
    newMatrix.setTranslationRaw(dx, dy, 0.0);
    
    _transformationController.value = newMatrix;
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(icon, color: AppColors.slate700, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.maxWidth / widget.originalSize.width;
    final scaledHeight = widget.originalSize.height * scale;

    final scaledPolygons = widget.result?.polygons.map((poly) => poly.map((p) => Offset(p.dx * scale, p.dy * scale)).toList()).toList() ?? [];
    final scaledBoxes = widget.result?.boundingBoxes.map((box) {
      return BoundingBox(
        xmin: box.xmin * scale,
        ymin: box.ymin * scale,
        xmax: box.xmax * scale,
        ymax: box.ymax * scale,
        className: box.className,
        confidence: box.confidence,
      );
    }).toList() ?? [];

    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformationController,
          panEnabled: true,
          scaleEnabled: true,
          minScale: 1.0,
          maxScale: 10.0,
          child: SizedBox(
            width: widget.maxWidth,
            height: scaledHeight,
            child: Stack(
              children: [
                Image.memory(
                  widget.imageBytes,
                  width: widget.maxWidth,
                  height: scaledHeight,
                  fit: BoxFit.cover,
                ),
                CustomPaint(
                  painter: TeethPainter(polygons: scaledPolygons, boundingBoxes: scaledBoxes, currentZoom: _currentZoom),
                  size: Size(widget.maxWidth, scaledHeight),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomButton(Icons.add, () => _zoom(2.0)),
              const SizedBox(height: 8),
              _buildZoomButton(Icons.remove, () => _zoom(0.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class TeethPainter extends CustomPainter {
  final List<List<Offset>> polygons;
  final List<BoundingBox> boundingBoxes;
  final double currentZoom;

  TeethPainter({required this.polygons, required this.boundingBoxes, this.currentZoom = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final polyPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5 / currentZoom..color = Colors.green;

    for (final poly in polygons) {
      if (poly.isNotEmpty) {
        final path = Path()..moveTo(poly.first.dx, poly.first.dy);
        for (final point in poly.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        path.close();
        canvas.drawPath(path, polyPaint);
      }
    }

    // 1. Draw all boxes first
    for (final box in boundingBoxes) {
      if (box.confidence < 0.25) continue;
      
      final cls = box.className.toLowerCase();
      Color color = AppColors.green400; // default normal
      if (cls == 'cavity' || cls == 'caries') {
        color = AppColors.red400;
      } else if (cls == 'crack') {
        color = AppColors.amber400;
      }

      final boxPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / currentZoom
        ..color = color;
      
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withOpacity(0.15);

      final rect = Rect.fromLTRB(box.xmin, box.ymin, box.xmax, box.ymax);
      canvas.drawRect(rect, boxPaint);
      canvas.drawRect(rect, fillPaint);
    }

    // 2. Draw text labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final box in boundingBoxes) {
      if (box.confidence < 0.25) continue;
      
      final cls = box.className.toLowerCase();
      Color color = AppColors.green400; // default normal
      String label = '정상';
      if (cls == 'cavity' || cls == 'caries') {
        color = AppColors.red400;
        label = '충치';
      } else if (cls == 'crack') {
        color = AppColors.amber400;
        label = '크랙';
      }
      
      label += ' ${(box.confidence * 100).toInt()}%';

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'PretendardGOV',
          color: Colors.white,
          fontSize: 14 / currentZoom,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      
      double x = box.xmin - (1.5 / currentZoom);
      double y = box.ymin - (20 / currentZoom);

      final bgPaint = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(x, y, textPainter.width + (8 / currentZoom), (20 / currentZoom)), bgPaint);
      textPainter.paint(canvas, Offset(x + (4 / currentZoom), y + (2 / currentZoom)));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class DetectionResult {
  final List<List<Offset>> polygons;
  final List<BoundingBox> boundingBoxes;

  DetectionResult({required this.polygons, required this.boundingBoxes});
}

class BoundingBox {
  final double xmin, ymin, xmax, ymax;
  final String className;
  final double confidence;

  BoundingBox({
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
    required this.className,
    required this.confidence,
  });
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
      
    // A simple dashed path approach
    double dashWidth = 8, dashSpace = 6, startX = 0;
    for (PathMetric measurePath in path.computeMetrics()) {
      while (startX < measurePath.length) {
        final extractPath = measurePath.extractPath(startX, startX + dashWidth);
        canvas.drawPath(extractPath, paint);
        startX += dashWidth + dashSpace;
      }
      startX = 0;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
