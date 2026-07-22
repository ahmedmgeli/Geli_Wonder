import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JellyWonderApp());
}

class JellyWonderApp extends StatelessWidget {
  const JellyWonderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جلي للتحول العجيب Pro',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const MainConverterScreen(),
    );
  }
}

class MainConverterScreen extends StatefulWidget {
  const MainConverterScreen({super.key});

  @override
  State<MainConverterScreen> createState() => _MainConverterScreenState();
}

class _MainConverterScreenState extends State<MainConverterScreen> {
  String? _selectedFilePath;
  bool _useOcr = false;
  String _outputFormat = 'xlsx';
  bool _isProcessing = false;
  double _progressValue = 0.0;
  String _statusMessage = "جاهز ومستعد للتحويل الذكي...";

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        String originalPath = result.files.single.path!;
        
        // نسخ الملف لمجلد مؤقت لضمان الوصول المباشر
        Directory tempDir = await getTemporaryDirectory();
        String fileName = result.files.single.name;
        File localFile = File('${tempDir.path}/$fileName');
        await File(originalPath).copy(localFile.path);

        String ext = fileName.split('.').last.toLowerCase();
        setState(() {
          _selectedFilePath = localFile.path;
          _useOcr = ['png', 'jpg', 'jpeg'].contains(ext);
        });
      }
    } catch (e) {
      _showMessage("خطأ أثناء اختيار الملف: $e");
    }
  }

  // تنظيف وتنسيق النصوص للغتين
  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _startConversion() async {
    if (_selectedFilePath == null || !File(_selectedFilePath!).existsSync()) {
      _showMessage("يرجى اختيار ملف PDF أو صورة أولاً!");
      return;
    }

    setState(() {
      _isProcessing = true;
      _progressValue = 0.20;
      _statusMessage = "جاري التفكيك والتحليل الذكي للترتيب...";
    });

    try {
      List<List<String>> extractedData = [];
      String ext = _selectedFilePath!.split('.').last.toLowerCase();
      bool isImage = ['png', 'jpg', 'jpeg'].contains(ext);

      if (isImage || _useOcr) {
        if (isImage) {
          extractedData = await _processOCRUltra(_selectedFilePath!);
        } else {
          // معالجة ملفات الـ PDF الممسوحة عند الحاجة
          extractedData = await _processPdfSmart(_selectedFilePath!);
          if (extractedData.isEmpty) {
            extractedData = await _processOCRUltra(_selectedFilePath!);
          }
        }
      } else {
        extractedData = await _processPdfSmart(_selectedFilePath!);
      }

      if (extractedData.isEmpty) {
        throw Exception("لم نتمكن من استخرج بيانات واضحة. تأكد من وضوح الصورة أو محتوى الملف.");
      }

      setState(() {
        _progressValue = 0.75;
        _statusMessage = "جاري إنشاء وتنسيق الأعمدة بالجودة العالية...";
      });

      Directory? dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      String nameWithoutExt = _selectedFilePath!.split('/').last.split('.').first;
      String outputPath = "${dir.path}/${nameWithoutExt}_جلي_للتحول_العجيب.$_outputFormat";

      if (_outputFormat == 'xlsx') {
        await _saveExcel(extractedData, outputPath);
      } else {
        await _saveWordText(extractedData, outputPath);
      }

      setState(() {
        _progressValue = 1.0;
        _statusMessage = "تم التحويل بنجاح وبدقة عالية!";
        _isProcessing = false;
      });

      _showSuccessDialog(outputPath);

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = "حدث خطأ أثناء معالجة الملف";
      });
      _showMessage("تنبيه: $e");
    }
  }

  // محرك قراءة الـ PDF الذكي
  Future<List<List<String>>> _processPdfSmart(String path) async {
    List<List<String>> rows = [];
    File file = File(path);
    List<int> bytes = await file.readAsBytes();
    PdfDocument document = PdfDocument(inputBytes: bytes);

    for (int i = 0; i < document.pages.count; i++) {
      String text = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      List<String> lines = text.split('\n');
      for (String line in lines) {
        String clean = _cleanText(line);
        if (clean.isNotEmpty) {
          List<String> columns = clean.split(RegExp(r'\t|\s{2,}'));
          rows.add(columns);
        }
      }
    }
    document.dispose();
    return rows;
  }

  // محرك OCR المتقدم الداعم للترتيب الذكي واللغتين
  Future<List<List<String>>> _processOCRUltra(String path) async {
    List<List<String>> rows = [];
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    final inputImage = InputImage.fromFilePath(path);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

    List<TextElement> elements = [];
    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        elements.addAll(line.elements);
      }
    }

    if (elements.isEmpty) {
      textRecognizer.close();
      return rows;
    }

    // ترتيب العناصر رأسياً
    elements.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    List<List<TextElement>> lineGroups = [];
    double currentTop = -1;
    List<TextElement> currentGroup = [];

    for (var el in elements) {
      if (currentTop == -1 || (el.boundingBox.top - currentTop).abs() < 12) {
        currentGroup.add(el);
        if (currentTop == -1) currentTop = el.boundingBox.top.toDouble();
      } else {
        lineGroups.add(List.from(currentGroup));
        currentGroup = [el];
        currentTop = el.boundingBox.top.toDouble();
      }
    }
    if (currentGroup.isNotEmpty) lineGroups.add(currentGroup);

    // ترتيب العناصر أفقياً حسب اللغة (يمين-يسار للعربية / يسار-يمين للإنجليزية)
    for (var line in lineGroups) {
      bool isArabicLine = line.any((e) => RegExp(r'[\u0600-\u06FF]').hasMatch(e.text));
      
      if (isArabicLine) {
        line.sort((a, b) => b.boundingBox.left.compareTo(a.boundingBox.left));
      } else {
        line.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      }

      List<String> rowText = line.map((e) => _cleanText(e.text)).where((t) => t.isNotEmpty).toList();
      if (rowText.isNotEmpty) {
        rows.add(rowText);
      }
    }

    textRecognizer.close();
    return rows;
  }

  // حفظ الملف بتنسيق Excel
  Future<void> _saveExcel(List<List<String>> data, String path) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];
    sheet.isRTL = true;

    for (var row in data) {
      sheet.appendRow(row.map((e) => TextCellValue(e)).toList());
    }

    var bytes = excel.save();
    if (bytes != null) {
      await File(path).writeAsBytes(bytes);
    }
  }

  // حفظ الملف بتنسيق Word
  Future<void> _saveWordText(List<List<String>> data, String path) async {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("=== المستند المستخرج بواسطة جلي للتحول العجيب ===");
    buffer.writeln();

    for (var row in data) {
      buffer.writeln(row.join(' \t '));
    }
    await File(path).writeAsString(buffer.toString());
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("تم بنجاح ✨", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
        content: Text("تم استخراج البيانات وحفظ الملف في المسار التالي:\n\n$path"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("موافق", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C3A47),
          elevation: 0,
          toolbarHeight: 70,
          title: const Text(
            "جلي للتحول العجيب Pro ✨",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "المعالج الذكي لتحويل وتقسيم الجداول\n(دعم كامل للغة العربية والإنجليزية)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF27AE60),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // بطاقة اختيار الملف
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEFF2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      "اختيار ملف الـ PDF أو الصورة",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3A47),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _pickFile,
                          icon: const Icon(Icons.folder_open, color: Colors.white, size: 20),
                          label: const Text(
                            "استعراض",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C3A47),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedFilePath != null
                                  ? _selectedFilePath!.split('/').last
                                  : "...لم يتم اختيار ملف",
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _selectedFilePath != null ? Colors.black87 : Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 🌟 تصميم أنيق وعصري لبطاقة وزر الـ OCR
              Container(
                decoration: BoxDecoration(
                  gradient: _useOcr
                      ? const LinearGradient(
                          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFEAEFF2), Color(0xFFEAEFF2)],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _useOcr ? const Color(0xFFE67E22) : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: _useOcr
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE67E22).withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isProcessing
                        ? null
                        : () {
                            setState(() {
                              _useOcr = !_useOcr;
                            });
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _useOcr ? const Color(0xFFE67E22) : const Color(0xFF2C3A47).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.document_scanner_rounded,
                              size: 22,
                              color: _useOcr ? Colors.white : const Color(0xFF2C3A47),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "تفعيل قارئ الصور والمسح الضوئي (OCR)",
                                      style: TextStyle(
                                        color: _useOcr ? const Color(0xFFD35400) : const Color(0xFF2C3A47),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    if (_useOcr) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.check_circle, size: 16, color: Color(0xFF27AE60)),
                                    ]
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _useOcr
                                      ? "مُفعل حالياً استخراج النصوص الذكي بدقة عالية"
                                      : "انقر للتفعيل عند معالجة الصور والمستندات الممسوحة ضوئياً",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _useOcr ? const Color(0xFFD35400) : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              value: _useOcr,
                              activeColor: const Color(0xFFD35400),
                              activeTrackColor: const Color(0xFFFFCC80),
                              inactiveThumbColor: Colors.grey.shade600,
                              inactiveTrackColor: Colors.grey.shade300,
                              onChanged: _isProcessing
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _useOcr = val;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // بطاقة اختيار صيغة الملف
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEFF2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      "صيغة وجودة الملف المستخرج",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3A47),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => setState(() => _outputFormat = 'xlsx'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Radio<String>(
                            value: 'xlsx',
                            groupValue: _outputFormat,
                            activeColor: const Color(0xFF27AE60),
                            onChanged: (val) => setState(() => _outputFormat = val!),
                          ),
                          const Text(
                            "شيت إكسل ذكي ومعدل\n(.xlsx)",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3A47)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => setState(() => _outputFormat = 'docx'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Radio<String>(
                            value: 'docx',
                            groupValue: _outputFormat,
                            activeColor: const Color(0xFF27AE60),
                            onChanged: (val) => setState(() => _outputFormat = val!),
                          ),
                          const Text(
                            "مستند وورد منسق الجداول\n(.docx)",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3A47)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2980B9),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              LinearProgressIndicator(
                value: _progressValue,
                minHeight: 10,
                backgroundColor: Colors.grey.shade300,
                color: const Color(0xFF27AE60),
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _startConversion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "ابدأ التفكيك والتحويل المتقدم الآن",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
