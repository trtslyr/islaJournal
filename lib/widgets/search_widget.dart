import 'package:flutter/material.dart';

class SearchWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final String? hintText;
  final bool autofocus;

  const SearchWidget({
    super.key,
    required this.controller,
    required this.onSearch,
    this.hintText,
    this.autofocus = false,
  });

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: TextField(
        controller: widget.controller,
        autofocus: widget.autofocus,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'search entries...',
          hintStyle: TextStyle(
            fontFamily: 'JetBrainsMono',
            color: Theme.of(context).hintColor,
            fontSize: 14.0,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Theme.of(context).hintColor,
                    size: 18,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onSearch('');
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 12.0,
          ),
        ),
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
        onChanged: (value) {
          setState(() {});
          widget.onSearch(value);
        },
        onSubmitted: (value) {
          widget.onSearch(value);
        },
      ),
    );
  }
}

class SearchResultsWidget extends StatelessWidget {
  final List<SearchResult> results;
  final Function(SearchResult) onResultTap;
  final bool isLoading;

  const SearchResultsWidget({
    super.key,
    required this.results,
    required this.onResultTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'searching...',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'no results',
            style: TextStyle(
                  fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 1.0),
          color: Theme.of(context).cardColor, // Changed from AppTheme.darkerCream
          child: ListTile(
            leading: Text(
              '•',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 16.0,
              color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              result.title,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.snippet.isNotEmpty)
                  Text(
                    result.snippet,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  '${result.wordCount}w • ${result.folderPath}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10.0,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            trailing: Text(
              result.lastModified,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10.0,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            onTap: () => onResultTap(result),
          ),
        );
      },
    );
  }
}

class SearchResult {
  final String id;
  final String title;
  final String snippet;
  final String folderPath;
  final int wordCount;
  final String lastModified;

  SearchResult({
    required this.id,
    required this.title,
    required this.snippet,
    required this.folderPath,
    required this.wordCount,
    required this.lastModified,
  });
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback? onClear;
  final String? hintText;
  final bool autofocus;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    this.onClear,
    this.hintText,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        decoration: InputDecoration(
          hintText: hintText ?? 'search...',
          hintStyle: TextStyle(
            fontFamily: 'JetBrainsMono',
            color: Theme.of(context).hintColor,
            fontSize: 14.0,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Theme.of(context).hintColor,
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                    onSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 12.0,
          ),
        ),
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
        onChanged: (value) {
          onSearch(value);
        },
        onSubmitted: (value) {
          onSearch(value);
        },
      ),
    );
  }
}