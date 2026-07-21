import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const UniversalJellyApp());
}

class UniversalJellyApp extends StatelessWidget {
  const UniversalJellyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jelly Wonder Converter Pro',
      debugShowCheckedModeBanner: false,
      // دعم جميع اللغات عالمياً
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''), // العربية
        Locale('en', ''), // الإنجليزية
        Locale('fr', ''), // الفرنسية
        Locale('es', ''), // الإسبانية
        Locale('zh', ''), // الصينية
        Locale('ur', ''), // الأوردو
        Locale('tr', ''), // التركية
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFF00B894),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const UniversalConverterScreen(),
    );
  }
}

class UniversalConverterScreen extends StatefulWidget {
  const UniversalConverterScreen({super.key});

  @override
  State<UniversalConverterScreen> createState() => _UniversalConverterScreenState();
}

class _UniversalConverterScreenState extends State<UniversalConverterScreen> {
  bool _isProcessing = false;
  String _statusText = "جاهز للتحويل الشامل لجميع اللغات 🌍";
  double _progress = 0.0;

  Future<void> _selectAndConvertPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isProcessing = true;
        _progress = 0.2;
        _statusText = "جاري قراءة واستخراج النصوص والأرقام بكافة اللغات...";
      });

      File pdfFile = File(result.files.single.path!);
      List<int> bytes = await pdfFile.readAsBytes();

      // محرك Syncfusion الفائق للتعرف على جميع اللغات والترميزات العالمية
      PdfDocument document = PdfDocument(inputBytes: bytes);
      PdfTextExtractor extractor = PdfTextExtractor(document);

      setState(() {
        _progress = 0.6;
        _statusText = "جاري تحويل البيانات وتنسيق شيت الإكسل...";
      });

      // إنشاء ملف إكسل يدعم ترميز UTF-8 العالمي
      var excel = Excel.createExcel();
      String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      Sheet sheet = excel[defaultSheet];

      int totalPages = document.pages.count;
      int currentRow = 0;

      for (int i = 0; i < totalPages; i++) {
        String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        List<String> lines = pageText.split('\n');

        for (String line in lines) {
          String cleanLine = line.trim();
          if (cleanLine.isNotEmpty) {
            // تفكيك السطور بذكاء بناءً على الفواصل والمسافات
            List<String> columns = cleanLine.split(RegExp(r'\s{2,}|\t'));
            for (int col = 0; col < columns.length; col++) {
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow))
                   .value = TextCellValue(columns[col].trim());
            }
            currentRow++;
          }
        }
      }

      document.dispose();

      setState(() {
        _progress = 0.85;
        _statusText = "حفظ المستند الناتجة بشكل آمن...";
      });

      var fileBytes = excel.save();
      Directory? storageDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      
      String originalName = result.files.single.name.replaceAll('.pdf', '');
      String outputPath = "${storageDir.path}/${originalName}_Universal_Excel.xlsx";

      File outputFile = File(outputPath);
      await outputFile.writeAsBytes(fileBytes!);

      setState(() {
        _progress = 1.0;
        _statusText = "تم التحويل بنجاح تام وبأعلى جودة! ✨";
        _isProcessing = false;
      });

      _showSuccessDialog(outputPath);

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = "حدث خطأ أثناء المعالجة: $e";
      });
    }
  }

  void _showSuccessDialog(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text("تم التحويل بنجاح", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("تم استخراج البيانات وجميع اللغات بنجاح وحفظها في:\n\n$path"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('جلي التحول العجيب 🌍 Universal Pro', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 4,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.language_rounded,
                  size: 80,
                  color: Color(0xFF6C5CE7),
                ),
              ),
              const SizedBox(height: 30),
              
              const Text(
                "محول الـ PDF العالمي الذكي",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              const SizedBox(height: 8),
              const Text(
                "يدعم العربية، الإنجليزية، الصينية، واللغات العالمية بضغطة زر وبسرعة فائقة",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              if (_isProcessing) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey.shade300,
                  color: const Color(0xFF00B894),
                  minHeight: 8,
                ),
                const SizedBox(height: 15),
              ],

              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0984E3)),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _selectAndConvertPdf,
                  icon: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                  label: Text(
                    _isProcessing ? "جاري التحويل..." : "اختر ملف PDF وابدأ التحويل",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
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
