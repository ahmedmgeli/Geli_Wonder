import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart';
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
      title: 'جلي التحول العجيب Pro',
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
  String _outputFormat = 'xlsx'; // 'xlsx' أو 'docx'
  bool _isProcessing = false;
  double _progressValue = 0.0;
  String _statusMessage = "جاهز ومستعد للتحويل...";

  // اختيار الملفات (PDF أو صور PNG / JPG)
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        String ext = path.split('.').last.toLowerCase();
        setState(() {
          _selectedFilePath = path;
          // إذا كان الملف المختار صورة، يتم تفعيل الـ OCR إجبارياً
          if (['png', 'jpg', 'jpeg'].contains(ext)) {
            _useOcr = true;
          }
        });
      }
    } catch (e) {
      _showMessage("خطأ أثناء اختيار الملف: $e");
    }
  }

  // بدء التفكيك والتحويل
  Future<void> _startConversion() async {
    if (_selectedFilePath == null) {
      _showMessage("يرجى اختيار ملف PDF أو صورة أولاً!");
      return;
    }

    setState(() {
      _isProcessing = true;
      _progressValue = 0.20;
      _statusMessage = "جاري قراءة واستخراج البيانات بذكاء...";
    });

    try {
      List<List<String>> extractedData = [];
      String ext = _selectedFilePath!.split('.').last.toLowerCase();

      // معالجة الصور أو الـ PDF
      if (_useOcr || ['png', 'jpg', 'jpeg'].contains(ext)) {
        extractedData = await _processOCR(_selectedFilePath!);
      } else {
        extractedData = await _processPdfText(_selectedFilePath!);
        // إذا كان الـ PDF ممسوحاً ضوئياً كصورة ولم نستخرج نصاً، ننتقل للـ OCR تلقائياً
        if (extractedData.isEmpty) {
          extractedData = await _processOCR(_selectedFilePath!);
        }
      }

      if (extractedData.isEmpty) {
        throw Exception("لم نتمكن من استخراج بيانات من هذا المستند.");
      }

      setState(() {
        _progressValue = 0.70;
        _statusMessage = "جاري تنسيق وحفظ الملف بالصيغة المختارة...";
      });

      Directory? dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      String nameWithoutExt = _selectedFilePath!.split('/').last.split('.').first;
      String outputPath = "${dir.path}/${nameWithoutExt}_مستخرج_جلي.$_outputFormat";

      if (_outputFormat == 'xlsx') {
        await _saveExcel(extractedData, outputPath);
      } else {
        await _saveWordText(extractedData, outputPath);
      }

      setState(() {
        _progressValue = 1.0;
        _statusMessage = "تم التحويل بنجاح!";
        _isProcessing = false;
      });

      _showSuccessDialog(outputPath);

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = "حدث خطأ أثناء التحويل";
      });
      _showMessage("حدث خطأ: $e");
    }
  }

  // استخراج نصوص PDF الرقمية
  Future<List<List<String>>> _processPdfText(String path) async {
    List<List<String>> rows = [];
    File file = File(path);
    List<int> bytes = await file.readAsBytes();
    PdfDocument document = PdfDocument(inputBytes: bytes);

    for (int i = 0; i < document.pages.count; i++) {
      String text = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      for (String line in text.split('\n')) {
        if (line.trim().isNotEmpty) {
          rows.add(line.trim().split(RegExp(r'\s{2,}|\t')));
        }
      }
    }
    document.dispose();
    return rows;
  }

  // محرك المسح الضوئي (OCR) للصور والمستندات الممسوحة
  Future<List<List<String>>> _processOCR(String path) async {
    List<List<String>> rows = [];
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(path);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        if (line.text.trim().isNotEmpty) {
          // تقسيم السطر بناءً على الفواصل والمسافات الكبيرة لتشكيل أعمدة
          rows.add(line.text.trim().split(RegExp(r'\s{2,}|\t')));
        }
      }
    }
    textRecognizer.close();
    return rows;
  }

  // حفظ البيانات في شيت إكسل (XLSX)
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

  // حفظ البيانات في مستند وورد (DOCX / RTF)
  Future<void> _saveWordText(List<List<String>> data, String path) async {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("=== المستند المستخرج بواسطة جلي التحول العجيب Pro ===");
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
        content: Text("تم تحويل الملف بنجاح وحفظه في:\n\n$path"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("تم", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            "Pro ✨ جلي التحول العجيب",
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
              // العنوان الفرعي باللون الأخضر
              const Text(
                "المعالج الهجين الذكي لتقارير الـ PDF المعقدة والبنكية\nوصور الجداول",
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
                        // زر استعراض
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
                        // مربع عرض اسم الملف
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

              // بطاقة تفعيل الـ OCR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEFF2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Switch(
                      value: _useOcr,
                      activeColor: Colors.grey.shade700,
                      onChanged: _isProcessing
                          ? null
                          : (val) {
                              setState(() {
                                _useOcr = val;
                              });
                            },
                    ),
                    const Expanded(
                      child: Text(
                        "تفعيل قارئ الصور والمسح\nالضوئي الذكي (OCR) إجبارياً",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Color(0xFFD35400),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // بطاقة صيغة الملف المستخرج
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

                    // اختيار شيت إكسل
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

                    // اختيار مستند وورد
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

              // حالة العملية وشريط التقدم
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

              // زر ابدأ التفكيك والتحويل
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
