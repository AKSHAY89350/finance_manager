import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/bank_statement_parser_service.dart';
import '../../services/statement_deduplication_service.dart';
import 'statement_review_screen.dart';

class StatementImportScreen extends StatefulWidget {
  const StatementImportScreen({super.key});

  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _StatementImportScreenState extends State<StatementImportScreen> {
  String _selectedBank = 'Auto-Detect';
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isProcessing = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _banks = [
    {'name': 'Auto-Detect', 'icon': Icons.auto_awesome_rounded},
    {'name': 'HDFC Bank', 'icon': Icons.account_balance_rounded},
    {'name': 'SBI Bank', 'icon': Icons.account_balance_rounded},
    {'name': 'ICICI Bank', 'icon': Icons.account_balance_rounded},
    {'name': 'Axis Bank', 'icon': Icons.account_balance_rounded},
    {'name': 'Kotak Bank', 'icon': Icons.account_balance_rounded},
    {'name': 'Credit Card', 'icon': Icons.credit_card_rounded},
  ];

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    _fileBytes = null;
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Defensive guard: Prevent Out-Of-Memory (OOM) / heating from oversized non-statement PDFs
        if (file.size > 20 * 1024 * 1024) {
          setState(() {
            _errorMessage = 'Selected PDF is too large (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB). Bank statements are usually under 10 MB. Please upload a standard statement.';
          });
          return;
        }

        Uint8List? bytes = file.bytes;

        // On mobile, if bytes is null, read from path
        if (bytes == null && file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        }

        if (bytes != null) {
          setState(() {
            _selectedFile = file;
            _fileBytes = bytes;
          });
        } else {
          setState(() {
            _errorMessage = 'Could not load PDF bytes. Please try another file.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _processStatement() async {
    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Bank Statement PDF file first.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 1. Extract transactions from PDF
      final rawTransactions = await BankStatementParserService.extractTransactions(
        pdfBytes: _fileBytes!,
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
        bankName: _selectedBank,
      );

      if (rawTransactions.isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'No tabular transactions were detected in this PDF. Please ensure the document is a readable bank/card statement.';
        });
        return;
      }

      // 2. Perform Smart Deduplication against existing database entries
      final dedupResult = await StatementDeduplicationService().process(rawTransactions);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      _passwordController.clear(); // Security: Zero out sensitive password from memory

      // 3. Navigate to Review Screen
      final resolvedBank = (_selectedBank == 'Auto-Detect' && rawTransactions.isNotEmpty)
          ? rawTransactions.first.bankName
          : _selectedBank;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StatementReviewScreen(
            result: dedupResult,
            selectedBank: resolvedBank,
            fileName: _selectedFile?.name ?? 'Statement.pdf',
          ),
        ),
      );
    } on StatementPasswordException catch (e) {
      setState(() => _isProcessing = false);
      _showPasswordModal(e.message);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to parse statement: $e';
      });
    }
  }

  void _showPasswordModal(String prompt) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  const Text('PDF Password Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prompt, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Statement Password',
                      hintText: 'e.g. DOB (DDMM) + last 4 mobile digits',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setModalState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 Hint for HDFC: First 4 chars of name + DDMM or CustID.\n💡 SBI: Date of Birth (DDMM) + last 4 digits of registered phone.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _processStatement();
                  },
                  child: const Text('Unlock & Scan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Bank Statement'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade400, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, size: 14, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                  '100% Offline',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Description
            Text(
              'Select Bank & PDF File',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload your monthly account or card statement. Financial data is parsed completely on-device without any cloud dependencies.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            // 1. Bank Selector Section
            const Text(
              '1. SELECT BANK OR CARD',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _banks.map((b) {
                final isSelected = _selectedBank == b['name'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(b['icon'] as IconData, size: 16, color: isSelected ? Colors.white : theme.primaryColor),
                      const SizedBox(width: 6),
                      Text(b['name'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: theme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedBank = b['name'] as String);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 2. File Upload Dropzone
            const Text(
              '2. UPLOAD STATEMENT PDF',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedFile != null ? theme.primaryColor : Colors.grey.shade400,
                    width: _selectedFile != null ? 2 : 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _selectedFile != null ? Colors.red.shade50 : Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedFile != null ? Icons.picture_as_pdf_rounded : Icons.cloud_upload_outlined,
                        size: 36,
                        color: _selectedFile != null ? Colors.red.shade600 : theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedFile != null) ...[
                      Text(
                        _selectedFile!.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB • Ready to scan',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.change_circle_outlined, size: 16),
                        label: const Text('Change File', style: TextStyle(fontSize: 12)),
                      ),
                    ] else ...[
                      const Text(
                        'Tap to Choose Bank Statement PDF',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports HDFC, SBI, ICICI, Axis, Kotak & Credit Cards',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. Password Field
            const Text(
              '3. STATEMENT PASSWORD (IF ENCRYPTED)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'PDF Password (Optional)',
                hintText: 'Leave empty if unencrypted',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error Display
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _isProcessing ? null : _processStatement,
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Decrypting & Extracting PDF...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.document_scanner_rounded),
                          SizedBox(width: 8),
                          Text('Decrypt & Scan Statement ➔', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.blue.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Smart Ingestion Features',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Automatic table extraction separates Debits vs Credits.\n'
                    '• Smart Deduplication: Cross-checks Amount + Date with SMS records.\n'
                    '• Staging review panel lets you verify & select items before adding.\n'
                    '• Mandatory categorization ensures proper 50-30-20 budget classification.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
