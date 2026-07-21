import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync_pdf;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:archive/archive.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF27AE60),
          primary: const Color(0xFF27AE60),
          secondary: const Color(0xFF2980B9),
          surface: const Color(0xFFF8F9FA),
        ),
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
  String? _selectedPdfPath;
  bool _useOcr = false;
  String _outputFormat = 'xlsx'; // 'xlsx' أو 'docx'
  bool _isProcessing = false;
  double _progressValue = 0.0;
  String _statusMessage = "جاهز ومستعد للتحويل...";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedPdfPath = result.files.single.path;
        });
      }
    } catch (e) {
      _showErrorDialog("حدث خطأ أثناء اختيار الملف: $e");
    }
  }

  void _updateProgress(double progress, String message) {
    setState(() {
      _progressValue = progress;
      _statusMessage = message;
    });
  }

  Future<void> _startConversion() async {
    if (_selectedPdfPath == null || !File(_selectedPdfPath!).existsSync()) {
      _showErrorDialog("يرجى تحديد ملف PDF صحيح للمتابعة!");
      return;
    }

    setState(() {
      _isProcessing = true;
      _progressValue = 0.05;
      _statusMessage = "بدء معالجة المستند...";
    });

    try {
      List<List<String>> extractedRows = [];

      if (_useOcr) {
        extractedRows = await _processWithOCR(_selectedPdfPath!);
      } else {
        extractedRows = await _processWithTextExtraction(_selectedPdfPath!);
        if (extractedRows.isEmpty) {
          _updateProgress(0.3, "لم يُعثر على نص مكتوب، جارِ التحويل التلقائي لـ OCR...");
          extractedRows = await _processWithOCR(_selectedPdfPath!);
        }
      }

      if (extractedRows.isEmpty) {
        throw Exception("لم يتم العثور على أية بيانات قابلة للاستخراج بالملف.");
      }

      _updateProgress(0.85, "جارِ إنشاء وتنسيق الملف المستخرج...");

      final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final fileNameWithoutExt = _selectedPdfPath!.split('/').last.replaceAll('.pdf', '');
      final outputPath = "${directory.path}/${fileNameWithoutExt}_المستخرج_العجيب.$_outputFormat";

      if (_outputFormat == 'xlsx') {
        await _writeToExcel(extractedRows, outputPath);
      } else {
        await _writeToWordDocx(extractedRows, outputPath);
      }

      _updateProgress(1.0, "اكتمل التفكيك والتحويل بنجاح 100%!");
      _showSuccessDialog("تم حفظ الملف بنجاح في المسار:\n$outputPath");

    } catch (e) {
      _showErrorDialog("حدث خطأ أثناء المعالجة: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // استخراج النصوص المباشرة باستخدام Syncfusion PDF
  Future<List<List<String>>> _processWithTextExtraction(String pdfPath) async {
    List<List<String>> rows = [];
    final File file = File(pdfPath);
    final List<int> bytes = await file.readAsBytes();
    final sync_pdf.PdfDocument document = sync_pdf.PdfDocument(inputBytes: bytes);

    int totalPages = document.pages.count;
    for (int i = 0; i < totalPages; i++) {
      _updateProgress(0.1 + (i / totalPages) * 0.4, "استخراج النصوص: صفحة ${i + 1} من $totalPages...");
      
      String pageText = sync_pdf.PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      List<String> lines = pageText.split('\n');

      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        List<String> parts = line.trim().split(RegExp(r'\s{2,}|\t'));
        List<String> cleanParts = parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        if (cleanParts.isNotEmpty) {
          rows.add(cleanParts);
        }
      }
    }
    document.dispose();
    return rows;
  }

  // المعالجة بالمسح الضوئي الذكي (Arabic OCR)
  Future<List<List<String>>> _processWithOCR(String pdfPath) async {
    List<List<String>> rows = [];
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final pdfDocument = await pdfx.PdfDocument.openFile(pdfPath);

    int totalPages = pdfDocument.pagesCount;

    for (int i = 1; i <= totalPages; i++) {
      _updateProgress(0.2 + (i / totalPages) * 0.6, "المسح الضوئي OCR: صفحة $i من $totalPages...");

      final page = await pdfDocument.getPage(i);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      await page.close();

      if (pageImage != null) {
        final tempDir = await getTemporaryDirectory();
        final imagePath = '${tempDir.path}/temp_page_$i.jpg';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(pageImage.bytes);

        final inputImage = InputImage.fromFilePath(imagePath);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

        List<TextBlock> sortedBlocks = recognizedText.blocks;
        sortedBlocks.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

        for (var block in sortedBlocks) {
          for (var line in block.lines) {
            String cleanText = line.text.trim();
            if (cleanText.isNotEmpty) {
              rows.add([cleanText]);
            }
          }
        }
        await imageFile.delete();
      }
    }

    await pdfDocument.close();
    textRecognizer.close();
    return rows;
  }

  // التصدير إلى إكسل (.xlsx) مع دعم الاتجاه من اليمين إلى اليسار
  Future<void> _writeToExcel(List<List<String>> rows, String outputPath) async {
    var excel = excel_lib.Excel.createExcel();
    String sheetName = "جلي_التحول_العجيب";
    excel.rename("Sheet1", sheetName);
    excel_lib.Sheet sheet = excel[sheetName];

    sheet.isRTL = true;

    for (var row in rows) {
      List<excel_lib.CellValue> cellValues = row.map((cell) => excel_lib.TextCellValue(cell)).toList();
      sheet.appendRow(cellValues);
    }

    List<int>? fileBytes = excel.save();
    if (fileBytes != null) {
      File(outputPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }
  }

  // التصدير المباشر بأسلوب OpenXML لتكوين مستند Word (.docx) الأصلي
  Future<void> _writeToWordDocx(List<List<String>> rows, String outputPath) async {
    int maxCols = 1;
    for (var r in rows) {
      if (r.length > maxCols) maxCols = r.length;
    }

    StringBuffer tableXml = StringBuffer();
    tableXml.write('<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:bdr w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/></w:tblPr>');

    for (var row in rows) {
      tableXml.write('<w:tr>');
      for (int i = 0; i < maxCols; i++) {
        String cellContent = i < row.length ? row[i] : "";
        tableXml.write(
          '<w:tc><w:tcPr><w:tcW w:w="2400" w:type="dxa"/></w:tcPr>'
          '<w:p><w:pPr><w:jc w:val="right"/><w:bdr/></w:pPr>'
          '<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="22"/></w:rPr>'
          '<w:t>$cellContent</w:t></w:r></w:p></w:tc>'
        );
      }
      tableXml.write('</w:tr>');
    }
    tableXml.write('</w:tbl>');

    String documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${tableXml.toString()}
  </w:body>
</w:document>''';

    String contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    String relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final archive = Archive();
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, contentTypesXml.codeUnits));
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, relsXml.codeUnits));
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, documentXml.codeUnits));

    final encoder = ZipEncoder();
    final outputBytes = encoder.encode(archive);

    if (outputBytes != null) {
      final outputFile = File(outputPath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsBytes(outputBytes);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تنبيه", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("حسناً"),
          )
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تم بنجاح ✨", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("رائع"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("جلي التحول العجيب ✨ Pro", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "المعالج الهجين الذكي لتقارير الـ PDF المعقدة والبنكية وصور الجداول",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF27AE60), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("اختيار ملف الـ PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF34495E))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              _selectedPdfPath != null ? _selectedPdfPath!.split('/').last : "لم يتم اختيار ملف...",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _pickPdfFile,
                          icon: const Icon(Icons.folder_open, color: Colors.white),
                          label: const Text("استعراض", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF34495E),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                title: const Text(
                  "تفعيل قارئ الصور والمسح الضوئي الذكي (OCR) إجباريًا",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE67E22)),
                ),
                value: _useOcr,
                activeColor: const Color(0xFFE67E22),
                onChanged: _isProcessing
                    ? null
                    : (val) {
                        setState(() {
                          _useOcr = val;
                        });
                      },
              ),
            ),
            const SizedBox(height: 15),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("صيغة وجودة الملف المستخرج", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF34495E))),
                    const SizedBox(height: 10),
                    RadioListTile<String>(
                      title: const Text("شيت إكسل ذكي ومعدل (.xlsx)"),
                      value: 'xlsx',
                      groupValue: _outputFormat,
                      activeColor: const Color(0xFF27AE60),
                      onChanged: _isProcessing ? null : (val) => setState(() => _outputFormat = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text("مستند وورد منسق الجداول (.docx)"),
                      value: 'docx',
                      groupValue: _outputFormat,
                      activeColor: const Color(0xFF27AE60),
                      onChanged: _isProcessing ? null : (val) => setState(() => _outputFormat = val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              _statusMessage,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2980B9)),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _progressValue,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: const Color(0xFF27AE60),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 30),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _startConversion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "ابدأ التفكيك والتحويل المتقدم الآن",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
