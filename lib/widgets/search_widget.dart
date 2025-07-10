import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

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
        color: AppTheme.darkerCream,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppTheme.warmBrown.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search your journal entries...',
          hintStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            color: AppTheme.mediumGray,
            fontSize: 16.0,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.warmBrown,
          ),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppTheme.mediumGray,
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
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          color: AppTheme.darkText,
          fontSize: 16.0,
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: AppTheme.mediumGray,
              ),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mediumGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try different keywords or check your spelling',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16.0,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.mediumGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: ListTile(
            leading: Icon(
              Icons.description,
              color: AppTheme.warmBrown,
            ),
            title: Text(
              result.title,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.snippet.isNotEmpty)
                  Text(
                    result.snippet,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.darkText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  '${result.wordCount} words • ${result.folderPath}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.8,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
            trailing: Text(
              result.lastModified,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.8,
                fontWeight: FontWeight.w400,
                color: AppTheme.mediumGray,
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
        color: AppTheme.darkerCream,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppTheme.warmBrown.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        decoration: InputDecoration(
          hintText: hintText ?? 'Search...',
          hintStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            color: AppTheme.mediumGray,
            fontSize: 16.0,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.warmBrown,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppTheme.mediumGray,
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
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          color: AppTheme.darkText,
          fontSize: 16.0,
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