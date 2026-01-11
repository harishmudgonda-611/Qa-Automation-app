import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const QAApp());
}

class QAApp extends StatelessWidget {
  const QAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QA Automation',
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? audioFile;
  String result = "";
  bool loading = false;

  // 🔴 IMPORTANT: Replace this with your OpenAI API key
  final String apiKey = "sk-xxxxxxxxxxxxxxxx";

  Future<void> pickAudio() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null) {
      setState(() {
        audioFile = File(res.files.single.path!);
      });
    }
  }

  Future<void> analyzeCall() async {
    if (audioFile == null) return;

    setState(() {
      loading = true;
      result = "Processing...";
    });

    try {
      // STEP 1: Transcription
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.openai.com/v1/audio/transcriptions"),
      );
      request.headers['Authorization'] = "Bearer $apiKey";
      request.fields['model'] = "whisper-1";
      request.files.add(await http.MultipartFile.fromPath('file', audioFile!.path));

      var response = await request.send();
      var transcriptResponse = await response.stream.bytesToString();
      var transcript = jsonDecode(transcriptResponse)['text'];

      // STEP 2: QA Analysis
      final qaResponse = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content": "You are a strict QA manager for Indian home loan BPO."
            },
            {
              "role": "user",
              "content": """
Analyze this transcript and give:
- Scores (Greeting, Need Discovery, Objection Handling, Closing, Empathy, Compliance)
- Gaps
- Expert suggestions
- Call observation
- Feedback email

Transcript:
$transcript
"""
            }
          ]
        }),
      );

      final data = jsonDecode(qaResponse.body);
      final output = data['choices'][0]['message']['content'];

      setState(() {
        result = output;
      });
    } catch (e) {
      setState(() {
        result = "Error: $e";
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QA Automation Tool")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickAudio,
              child: const Text("Upload Call Recording"),
            ),
            const SizedBox(height: 10),
            if (audioFile != null)
              Text("Selected: ${audioFile!.path.split('/').last}"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : analyzeCall,
              child: const Text("Analyze Call"),
            ),
            const SizedBox(height: 20),
            if (loading) const CircularProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                child: Text(result),
              ),
            )
          ],
        ),
      ),
    );
  }
}
