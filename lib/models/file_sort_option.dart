enum FileSortType {
  journalDateNewest,
  journalDateOldest,
  lastOpened,
  createdNewest,
  createdOldest,
  modifiedNewest,
  modifiedOldest,
  alphabetical,
  alphabeticalReverse,
}

enum FileFilterType {
  all,
  today,
  thisWeek,
  thisMonth,
  thisYear,
  hasJournalDate,
  noJournalDate,
}

class FileSortOption {
  final FileSortType sortType;
  final FileFilterType filterType;
  
  const FileSortOption({
    this.sortType = FileSortType.journalDateNewest,
    this.filterType = FileFilterType.all,
  });
  
  FileSortOption copyWith({
    FileSortType? sortType,
    FileFilterType? filterType,
  }) {
    return FileSortOption(
      sortType: sortType ?? this.sortType,
      filterType: filterType ?? this.filterType,
    );
  }
  
  String get sortDisplayName {
    switch (sortType) {
      case FileSortType.journalDateNewest:
        return 'Journal Date (Newest)';
      case FileSortType.journalDateOldest:
        return 'Journal Date (Oldest)';
      case FileSortType.lastOpened:
        return 'Last Opened';
      case FileSortType.createdNewest:
        return 'Created (Newest)';
      case FileSortType.createdOldest:
        return 'Created (Oldest)';
      case FileSortType.modifiedNewest:
        return 'Modified (Newest)';
      case FileSortType.modifiedOldest:
        return 'Modified (Oldest)';
      case FileSortType.alphabetical:
        return 'Alphabetical (A-Z)';
      case FileSortType.alphabeticalReverse:
        return 'Alphabetical (Z-A)';
    }
  }
  
  String get filterDisplayName {
    switch (filterType) {
      case FileFilterType.all:
        return 'All Files';
      case FileFilterType.today:
        return 'Today';
      case FileFilterType.thisWeek:
        return 'This Week';
      case FileFilterType.thisMonth:
        return 'This Month';
      case FileFilterType.thisYear:
        return 'This Year';
      case FileFilterType.hasJournalDate:
        return 'With Journal Date';
      case FileFilterType.noJournalDate:
        return 'No Journal Date';
    }
  }
  
  String get shortDisplayName {
    final sort = _shortSortName(sortType);
    final filter = _shortFilterName(filterType);
    return filter == 'All' ? sort : '$sort • $filter';
  }
  
  String _shortSortName(FileSortType type) {
    switch (type) {
      case FileSortType.journalDateNewest:
        return 'Journal Date ↓';
      case FileSortType.journalDateOldest:
        return 'Journal Date ↑';
      case FileSortType.lastOpened:
        return 'Last Opened';
      case FileSortType.createdNewest:
        return 'Created ↓';
      case FileSortType.createdOldest:
        return 'Created ↑';
      case FileSortType.modifiedNewest:
        return 'Modified ↓';
      case FileSortType.modifiedOldest:
        return 'Modified ↑';
      case FileSortType.alphabetical:
        return 'A → Z';
      case FileSortType.alphabeticalReverse:
        return 'Z → A';
    }
  }
  
  String _shortFilterName(FileFilterType type) {
    switch (type) {
      case FileFilterType.all:
        return 'All';
      case FileFilterType.today:
        return 'Today';
      case FileFilterType.thisWeek:
        return 'Week';
      case FileFilterType.thisMonth:
        return 'Month';
      case FileFilterType.thisYear:
        return 'Year';
      case FileFilterType.hasJournalDate:
        return 'Dated';
      case FileFilterType.noJournalDate:
        return 'Undated';
    }
  }
} 