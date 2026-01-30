import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class KeywordsView extends StatelessWidget {
  const KeywordsView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.visibility, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  "Watched Keywords (${appState.keywords.length})",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: appState.keywords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "No keywords defined",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              "Tap the ", 
                              style: TextStyle(fontSize: 12, color: Colors.grey)
                            ),
                            Icon(Icons.add_circle, size: 16, color: Colors.grey),
                            Text(
                              " button below to add one", 
                              style: TextStyle(fontSize: 12, color: Colors.grey)
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_downward, color: Colors.grey, size: 16),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 8, right: 8, bottom: 80), // Padding for FAB
                    itemCount: appState.keywords.length,
                    itemBuilder: (context, index) {
                      final word = appState.keywords[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blueGrey[100],
                            child: Text(
                              word[0].toUpperCase(), 
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey[800], fontWeight: FontWeight.bold)
                            ),
                          ),
                          title: Text(word, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                            tooltip: "Remove keyword",
                            onPressed: () => context.read<AppState>().removeKeyword(word),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}