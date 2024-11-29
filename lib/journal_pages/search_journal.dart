import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/journal_model.dart';
import 'journal_details.dart';
import 'package:intl/intl.dart';
import 'utils.dart'; // Import utils.dart for emotionToEmoji
import '../models/emotion.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterOption = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  String _emotionFilter = 'All';
  final ValueNotifier<Map<String, Size>> _cardSizeNotifier =
      ValueNotifier<Map<String, Size>>({});

  @override
  void dispose() {
    _searchController.dispose();
    _cardSizeNotifier.dispose();
    super.dispose();
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _updateFilterOption(String? option) {
    setState(() {
      _filterOption = option ?? 'All';
    });
  }

  void _updateEmotionFilter(String? emotion) {
    setState(() {
      _emotionFilter = emotion ?? 'All';
    });
  }

  void _selectStartDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _selectEndDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Stream<List<QueryDocumentSnapshot<Journal>>> _searchJournals() {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    return DatabaseService().getJournalsByUserId(userId).map((journalDocs) {
      return journalDocs.where((doc) {
        final journal = doc.data();
        final matchesQuery = journal.title.contains(_searchQuery) ||
            journal.content.contains(_searchQuery);
        final matchesFilter = _filterOption == 'All' ||
            (_filterOption == 'Super Positive' &&
                journal.sentiment?.label == 'Super Positive') ||
            (_filterOption == 'Positive' &&
                journal.sentiment?.label == 'Positive') ||
            (_filterOption == 'Neutral' &&
                journal.sentiment?.label == 'Neutral') ||
            (_filterOption == 'Negative' &&
                journal.sentiment?.label == 'Negative') ||
            (_filterOption == 'Super Negative' &&
                journal.sentiment?.label == 'Super Negative');
        final matchesEmotion = _emotionFilter == 'All' ||
            (journal.emotions != null &&
                journal.emotions!
                    .any((emotion) => emotion.emotion == _emotionFilter));
        final matchesDateRange = (_startDate == null ||
                journal.entryDate.toDate().isAfter(_startDate!)) &&
            (_endDate == null ||
                journal.entryDate.toDate().isBefore(_endDate!));
        return matchesQuery &&
            matchesFilter &&
            matchesEmotion &&
            matchesDateRange;
      }).toList();
    });
  }

  Map<String, Map<String, List<Journal>>> _groupJournalsByMonthYearAndDay(
      List<Journal> journals) {
    // Sort journals by date in descending order
    journals.sort((a, b) => b.entryDate.compareTo(a.entryDate));

    Map<String, Map<String, List<Journal>>> groupedJournals = {};
    for (var journal in journals) {
      String monthYear =
          DateFormat('MMMM yyyy').format(journal.entryDate.toDate());
      String day = DateFormat('dd').format(journal.entryDate.toDate());
      if (!groupedJournals.containsKey(monthYear)) {
        groupedJournals[monthYear] = {};
      }
      if (!groupedJournals[monthYear]!.containsKey(day)) {
        groupedJournals[monthYear]![day] = [];
      }
      groupedJournals[monthYear]![day]!.add(journal);
    }
    return groupedJournals;
  }

  String _formatDate(DateTime date) {
    String daySuffix(int day) {
      if (day >= 11 && day <= 13) {
        return 'th';
      }
      switch (day % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }

    String suffix = daySuffix(date.day);
    String formattedDate = DateFormat('EEEE, d').format(date) + suffix;
    return formattedDate;
  }

  Future<void> _exportToPdf(List<Journal> journals) async {
    try {
      // Split journals into batches (e.g., 3 months per PDF)
      final batchedJournals = _splitJournalsIntoBatches(journals);

      for (int batchIndex = 0;
          batchIndex < batchedJournals.length;
          batchIndex++) {
        final pdf = pw.Document();
        final googleFont = await PdfGoogleFonts.notoSerifRegular();
        final groupedJournals =
            _groupJournalsByMonthYearAndDay(batchedJournals[batchIndex]);

        final pageFormat = PdfPageFormat.a4.copyWith(
          marginLeft: 30,
          marginRight: 30,
          marginTop: 35,
          marginBottom: 35,
        );

        for (var monthYearEntry in groupedJournals.entries) {
          final monthYear = monthYearEntry.key;
          final dayJournals = monthYearEntry.value;

          pdf.addPage(
            pw.MultiPage(
              pageFormat: pageFormat,
              maxPages: 20, // Limit pages per month
              build: (pw.Context context) {
                return [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Header(
                        level: 0,
                        child: pw.Text(
                          monthYear,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      ...dayJournals.entries.map((dayEntry) {
                        String day = dayEntry.key;
                        List<Journal> dayJournals = dayEntry.value;

                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Header(
                              level: 1,
                              child: pw.Text(
                                _formatDate(DateTime.parse(
                                    '${dayEntry.value.first.entryDate.toDate().year}-${dayEntry.value.first.entryDate.toDate().month.toString().padLeft(2, '0')}-$day')),
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            ...dayJournals.map((journal) {
                              String emotionName = journal.emotions != null &&
                                      journal.emotions!.isNotEmpty
                                  ? journal.emotions!.first.emotion
                                  : 'Unknown';

                              String formattedTime =
                                  _formatTime(journal.entryDate.toDate());

                              return pw.Container(
                                width: double.infinity,
                                margin:
                                    const pw.EdgeInsets.symmetric(vertical: 2),
                                padding: const pw.EdgeInsets.all(6),
                                decoration: pw.BoxDecoration(
                                  border:
                                      pw.Border.all(color: PdfColors.grey300),
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Row(
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Expanded(
                                          child: pw.Text(
                                            journal.title,
                                            style: pw.TextStyle(
                                              fontSize: 12,
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        pw.Text(
                                          emotionName,
                                          style: pw.TextStyle(
                                            fontSize: 11,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      formattedTime,
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontStyle: pw.FontStyle.italic,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      journal.content,
                                      style: pw.TextStyle(
                                        font: googleFont,
                                        fontSize: 11,
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      'Sentiment: ${journal.sentiment?.label ?? 'Unknown'}',
                                      style: const pw.TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ];
              },
            ),
          );
        }

        // Save each batch with a different file name
        final String fileName = 'journal_export_${batchIndex + 1}.pdf';
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          format: pageFormat,
          name: fileName,
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      // Handle the error in your UI
      rethrow;
    }
  }

// Helper function to split journals into smaller batches
  List<List<Journal>> _splitJournalsIntoBatches(List<Journal> journals) {
    // Sort journals by date first
    journals
        .sort((a, b) => a.entryDate.toDate().compareTo(b.entryDate.toDate()));

    // Group by month and year
    Map<String, List<Journal>> monthGroups = {};
    for (var journal in journals) {
      final date = journal.entryDate.toDate();
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthGroups[key] = [...(monthGroups[key] ?? []), journal];
    }

    // Split into batches of 3 months
    List<List<Journal>> batches = [];
    List<Journal> currentBatch = [];
    int monthCount = 0;
    String? currentYear;

    for (var monthEntry in monthGroups.entries) {
      final yearMonth = monthEntry.key.split('-');
      final year = yearMonth[0];

      // Start new batch if:
      // 1. We've reached 3 months
      // 2. Or we're crossing into a new year
      if (monthCount >= 3 || (currentYear != null && currentYear != year)) {
        if (currentBatch.isNotEmpty) {
          batches.add(currentBatch);
          currentBatch = [];
          monthCount = 0;
        }
      }

      currentBatch.addAll(monthEntry.value);
      monthCount++;
      currentYear = year;
    }

    // Add the last batch if not empty
    if (currentBatch.isNotEmpty) {
      batches.add(currentBatch);
    }

    return batches;
  }

// Helper function to format time
  String _formatTime(DateTime dateTime) {
    return 'Time: ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Journals'),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () async {
              List<QueryDocumentSnapshot<Journal>> filteredJournalDocs =
                  await _searchJournals().first;
              List<Journal> filteredJournals =
                  filteredJournalDocs.map((doc) => doc.data()).toList();
              await _exportToPdf(filteredJournals);
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () {
                    _searchController.clear();
                    _updateSearchQuery('');
                  },
                ),
              ),
              onChanged: _updateSearchQuery,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<String>(
                  value: _filterOption,
                  items: <String>[
                    'All',
                    'Super Positive',
                    'Positive',
                    'Neutral',
                    'Negative',
                    'Super Negative'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: _updateFilterOption,
                ),
                DropdownButton<String>(
                  value: _emotionFilter,
                  items: <String>['All', ...emotionToEmoji.keys]
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: _updateEmotionFilter,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _selectStartDate(context),
                  child: Text(_startDate == null
                      ? 'Start Date'
                      : DateFormat('yyyy-MM-dd').format(_startDate!)),
                ),
                ElevatedButton(
                  onPressed: () => _selectEndDate(context),
                  child: Text(_endDate == null
                      ? 'End Date'
                      : DateFormat('yyyy-MM-dd').format(_endDate!)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<QueryDocumentSnapshot<Journal>>>(
                stream: _searchJournals(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No journal entries found'));
                  } else {
                    List<QueryDocumentSnapshot<Journal>> journalDocs =
                        snapshot.data!;
                    List<Journal> journals =
                        journalDocs.map((doc) => doc.data()).toList();
                    Map<String, Map<String, List<Journal>>> groupedJournals =
                        _groupJournalsByMonthYearAndDay(journals);

                    return ListView(
                      children: groupedJournals.entries.map((monthEntry) {
                        String monthYear = monthEntry.key;
                        Map<String, List<Journal>> dayJournals =
                            monthEntry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                monthYear,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown[900],
                                ),
                              ),
                            ),
                            ...dayJournals.entries.map((dayEntry) {
                              String day = dayEntry.key;
                              List<Journal> dayJournals = dayEntry.value;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Text(
                                      _formatDate(DateTime.parse(
                                          '${dayEntry.value.first.entryDate.toDate().year}-${dayEntry.value.first.entryDate.toDate().month.toString().padLeft(2, '0')}-$day')),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown[700],
                                      ),
                                    ),
                                  ),
                                  ...dayJournals.map((journal) {
                                    String documentId = journalDocs
                                        .firstWhere(
                                          (doc) =>
                                              doc.data().title ==
                                                  journal.title &&
                                              doc.data().content ==
                                                  journal.content,
                                          orElse: () =>
                                              throw StateError('No element'),
                                        )
                                        .id;

                                    // Get the highest probability emotion
                                    List<Emotion> emotions =
                                        journal.emotions ?? [];
                                    Emotion? highestEmotion =
                                        emotions.isNotEmpty
                                            ? emotions.first
                                            : null;
                                    String emoji = highestEmotion != null
                                        ? emotionToEmoji[
                                                highestEmotion.emotion] ??
                                            ''
                                        : '';
                                    String emotionName = highestEmotion != null
                                        ? highestEmotion.emotion
                                        : '';

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                JournalDetailsPage(
                                                    journalId: documentId),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  DateFormat('HH:mm').format(
                                                      journal.entryDate
                                                          .toDate()),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              ValueListenableBuilder<
                                                  Map<String, Size>>(
                                                valueListenable:
                                                    _cardSizeNotifier,
                                                builder:
                                                    (context, sizeMap, child) {
                                                  Size size =
                                                      sizeMap[documentId] ??
                                                          Size.zero;
                                                  return Container(
                                                    width: 2,
                                                    height: size.height + 15,
                                                    color: Colors.blue,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 20.0),
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  return Container(
                                                    padding: EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.grey
                                                              .withOpacity(0.1),
                                                          spreadRadius: 1,
                                                          blurRadius: 5,
                                                        ),
                                                      ],
                                                    ),
                                                    child: MeasureSize(
                                                      onChange: (size) {
                                                        _cardSizeNotifier
                                                            .value = {
                                                          ..._cardSizeNotifier
                                                              .value,
                                                          documentId: size,
                                                        };
                                                      },
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Text(
                                                                emoji,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        20),
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Expanded(
                                                                child: Text(
                                                                  journal.title,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                ),
                                                              ),
                                                              Text(
                                                                emotionName,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                            journal.content,
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey[600]),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}