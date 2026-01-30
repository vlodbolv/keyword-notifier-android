import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'keywords_view.dart';
import 'history_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Keyword"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "e.g., OTP, Urgent, Bank",
            helperText: "Notifications containing this word will trigger an alert.",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<AppState>().addKeyword(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Keyword Notifier"),
        elevation: 2,
        actions: [
          // Service Toggle Switch
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Text(
                  appState.isListening ? "ACTIVE" : "INACTIVE", 
                  style: TextStyle(
                    fontSize: 12,
                    color: appState.isListening ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold
                  )
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: appState.isListening,
                    onChanged: (val) => appState.toggleListening(context),
                    activeColor: Colors.green,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
        tooltip: "Add Keyword",
      ),
      body: appState.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: const [
                // 1. TOP: History (Flex 3 - takes more space)
                Expanded(
                  flex: 3,
                  child: HistoryView(),
                ),

                // Divider to separate sections
                Divider(thickness: 4, height: 4),

                // 2. BOTTOM: Keywords (Flex 2 - closer to FAB)
                Expanded(
                  flex: 2,
                  child: KeywordsView(),
                ),
              ],
            ),
    );
  }
}