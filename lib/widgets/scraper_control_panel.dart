import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScraperControlPanel extends StatefulWidget {
  final bool isLoading;
  final bool isValidating;
  final bool isMultiSelectMode;
  final int selectedItems;
  final String progressText;
  final String sortBy;
  final int minMembers;
  final bool excludeChinese;
  final String selectedSeason;
  final int selectedYear;
  final Map<String, dynamic> savedLists;
  final String? selectedListName;
  final VoidCallback onFetchAnime;
  final Function(String) onSortChanged;
  final Function(double) onMinMembersChanged;
  final Function(bool) onExcludeChineseChanged;
  final Function(String) onSeasonChanged;
  final Function(int) onYearChanged;
  final VoidCallback onAddAnimeManually;
  final VoidCallback onDeleteSelected;
  final VoidCallback onValidateAllRss;
  final VoidCallback onCancelValidation;
  final Function(String) onLoadList;
  final Function(String) onDeleteList;
  final bool hasAnimeList;

  const ScraperControlPanel({
    super.key,
    required this.isLoading,
    required this.isValidating,
    required this.isMultiSelectMode,
    required this.selectedItems,
    required this.progressText,
    required this.sortBy,
    required this.minMembers,
    required this.excludeChinese,
    required this.selectedSeason,
    required this.selectedYear,
    required this.savedLists,
    required this.selectedListName,
    required this.onFetchAnime,
    required this.onSortChanged,
    required this.onMinMembersChanged,
    required this.onExcludeChineseChanged,
    required this.onSeasonChanged,
    required this.onYearChanged,
    required this.onDeleteSelected,
    required this.onValidateAllRss,
    required this.onCancelValidation,
    required this.onLoadList,
    required this.onDeleteList,
    required this.hasAnimeList,
    required this.onAddAnimeManually,
  });

  @override
  State<ScraperControlPanel> createState() => _ScraperControlPanelState();
}

class _ScraperControlPanelState extends State<ScraperControlPanel> {
  bool _showMinMembersInput = false;
  final TextEditingController _minMembersController = TextEditingController();
  final FocusNode _minMembersFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _minMembersController.text = widget.minMembers.toString();
    _minMembersFocusNode.addListener(() {
      if (!_minMembersFocusNode.hasFocus) {
        setState(() {
          _showMinMembersInput = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(ScraperControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minMembers != widget.minMembers) {
      _minMembersController.text = widget.minMembers.toString();
    }
  }

  @override
  void dispose() {
    _minMembersController.dispose();
    _minMembersFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fetch and Sort row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: widget.isLoading ? null : widget.onFetchAnime,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  widget.isLoading ? 'Fetching...' : 'Fetch Anime',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildSortDropdown(theme),
          ],
        ),
        const SizedBox(height: 16),

        // Filter options with improved styling
        Text(
          'Filter Options',
          style: theme.textTheme.titleMedium?.copyWith(
            color:
                theme.brightness == Brightness.dark
                    ? Colors.white
                    : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Filter controls
        _buildFilterControls(context, theme),
        const SizedBox(height: 16),

        // Season and year selection
        _buildSeasonYearSelector(theme),
        const SizedBox(height: 16),

        // Multi-select action bar
        if (widget.isMultiSelectMode && widget.selectedItems > 0)
          _buildSelectionActionBar(theme),

        // Validation button (when not in multi-select mode)
        if (widget.hasAnimeList && !widget.isMultiSelectMode)
          _buildValidationButton(),

        // Status message
        if (widget.progressText.isNotEmpty) _buildStatusMessage(theme),

        // Saved lists selector
        if (widget.savedLists.isNotEmpty) _buildSavedListsSelector(theme),
      ],
    );
  }

  Widget _buildFilterControls(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Min Members text/input field
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showMinMembersInput = true;
                    // Focus the field after state is updated
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _minMembersFocusNode.requestFocus();
                    });
                  });
                },
                child:
                    _showMinMembersInput
                        ? Container(
                          width: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.primary,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: TextField(
                            controller: _minMembersController,
                            focusNode: _minMembersFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            onSubmitted: (value) {
                              setState(() {
                                _showMinMembersInput = false;
                              });
                              if (value.isNotEmpty) {
                                final newValue =
                                    int.tryParse(value) ?? widget.minMembers;
                                // Clamp value between 0 and 200,000
                                final clampedValue = newValue.clamp(0, 200000);
                                widget.onMinMembersChanged(
                                  clampedValue.toDouble(),
                                );
                              }
                            },
                          ),
                        )
                        : Text(
                          'Min Members: ${_formatNumber(widget.minMembers)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.primaryContainer
                      .withOpacity(0.3),
                  thumbColor: theme.colorScheme.primary,
                ),
                child: Slider(
                  value: widget.minMembers.toDouble(),
                  min: 0,
                  max: 200000,
                  divisions: 40, // 5,000 increments
                  onChanged: widget.onMinMembersChanged,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exclude Chinese', style: theme.textTheme.bodyMedium),
            Switch(
              value: widget.excludeChinese,
              activeColor: theme.colorScheme.primary,
              onChanged: widget.onExcludeChineseChanged,
            ),
          ],
        ),
      ],
    );
  }

  // Helper method to format numbers with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  // Rest of the methods remain the same
  Widget _buildSortDropdown(ThemeData theme) {
    // Implementation unchanged
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButton<String>(
        value: widget.sortBy,
        underline: const SizedBox(),
        icon: const Icon(Icons.sort),
        dropdownColor: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        items: const [
          DropdownMenuItem(value: 'alpha', child: Text('A-Z')),
          DropdownMenuItem(value: 'alpha_reverse', child: Text('Z-A')),
          DropdownMenuItem(value: 'members_high', child: Text('Members ↓')),
          DropdownMenuItem(value: 'members_low', child: Text('Members ↑')),
          DropdownMenuItem(value: 'date_newest', child: Text('Newest First')),
          DropdownMenuItem(value: 'date_oldest', child: Text('Oldest First')),
        ],
        onChanged: (value) {
          if (value != null) {
            widget.onSortChanged(value);
          }
        },
      ),
    );
  }

  Widget _buildSeasonYearSelector(ThemeData theme) {
    final currentYear = DateTime.now().year;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Season:',
                style: TextStyle(
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.9)
                          : theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surface,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButton<String>(
                  value: widget.selectedSeason,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: theme.cardColor,
                  items: const [
                    DropdownMenuItem(value: 'winter', child: Text('Winter')),
                    DropdownMenuItem(value: 'spring', child: Text('Spring')),
                    DropdownMenuItem(value: 'summer', child: Text('Summer')),
                    DropdownMenuItem(value: 'fall', child: Text('Fall')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      widget.onSeasonChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Year:',
                style: TextStyle(
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.9)
                          : theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surface,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButton<int>(
                  value: widget.selectedYear,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: theme.cardColor,
                  items: List.generate(
                    currentYear - 1959, // From current year to 1960
                    (index) {
                      final year = currentYear - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    },
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      widget.onYearChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionActionBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            '${widget.selectedItems} items selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: widget.onDeleteSelected,
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('Delete Selected'),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    widget.isValidating ? Colors.red[700] : Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              onPressed:
                  widget.isLoading
                      ? null
                      : (widget.isValidating
                          ? widget.onCancelValidation
                          : widget.onValidateAllRss),
              icon: Icon(
                widget.isValidating ? Icons.stop : Icons.check_circle,
                color: Colors.white,
              ),
              label: Text(
                widget.isValidating ? 'Stop Validation' : 'Validate All RSS',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onPressed: widget.isLoading ? null : widget.onAddAnimeManually,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Anime',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.progressText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onBackground,
          ),
        ),
      ),
    );
  }

  Widget _buildSavedListsSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Icon(Icons.folder_open, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                underline: const SizedBox(),
                isExpanded: true,
                value: widget.selectedListName,
                hint: Text(
                  'Load saved list',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                dropdownColor: theme.cardColor,
                items:
                    widget.savedLists.keys.map((name) {
                      return DropdownMenuItem(
                        value: name,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                size: 20,
                                color: theme.colorScheme.error,
                              ),
                              onPressed: () => widget.onDeleteList(name),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.onLoadList(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
