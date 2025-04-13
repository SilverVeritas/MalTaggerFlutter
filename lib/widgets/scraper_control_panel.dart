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
  bool _showFilterOptions = false;

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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row with fetch button, sort dropdown, and toggle
        _buildTopControlRow(theme),

        // Filter section (collapsible)
        if (_showFilterOptions) _buildFilterSection(context, theme),

        // Multi-select action bar (when in selection mode)
        if (widget.isMultiSelectMode && widget.selectedItems > 0)
          _buildSelectionActionBar(theme),

        // Action buttons row (validation or add manually)
        if (widget.hasAnimeList && !widget.isMultiSelectMode)
          widget.isValidating
              ? _buildCancelValidationButton()
              : _buildActionButtonsRow(),

        // Status message
        if (widget.progressText.isNotEmpty) _buildStatusMessage(theme),

        // Saved lists selector
        if (widget.savedLists.isNotEmpty) _buildSavedListsSelector(theme),
      ],
    );
  }

  Widget _buildTopControlRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            onPressed: widget.isLoading ? null : widget.onFetchAnime,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
            label: Text(
              widget.isLoading ? 'Fetching...' : 'Fetch Anime',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildSortDropdown(theme),
        IconButton(
          icon: Icon(
            _showFilterOptions ? Icons.expand_less : Icons.expand_more,
            size: 20,
          ),
          tooltip: _showFilterOptions ? 'Hide Filters' : 'Show Filters',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            setState(() {
              _showFilterOptions = !_showFilterOptions;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFilterSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Filter options heading
        Row(
          children: [
            Icon(Icons.filter_list, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'Filter Options',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Filter controls in compact form
        _buildCompactFilterControls(context, theme),
        const SizedBox(height: 8),

        // Season and year selection row
        _buildCompactSeasonYearSelector(theme),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildCompactFilterControls(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        // Min Members control
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showMinMembersInput = true;
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _minMembersFocusNode.requestFocus();
                    });
                  });
                },
                child:
                    _showMinMembersInput
                        ? Container(
                          width: 100,
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
                                horizontal: 6,
                                vertical: 2,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 12),
                            onSubmitted: (value) {
                              setState(() {
                                _showMinMembersInput = false;
                              });
                              if (value.isNotEmpty) {
                                final newValue =
                                    int.tryParse(value) ?? widget.minMembers;
                                final clampedValue = newValue.clamp(0, 200000);
                                widget.onMinMembersChanged(
                                  clampedValue.toDouble(),
                                );
                              }
                            },
                          ),
                        )
                        : Text(
                          'Min: ${_formatNumber(widget.minMembers)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                            fontSize: 12,
                          ),
                        ),
              ),
              SizedBox(
                height: 18,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    thumbColor: theme.colorScheme.primary,
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: widget.minMembers.toDouble(),
                    min: 0,
                    max: 200000,
                    divisions: 40,
                    onChanged: widget.onMinMembersChanged,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Exclude Chinese switch
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Exclude CN',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: widget.excludeChinese,
                activeColor: theme.colorScheme.primary,
                onChanged: widget.onExcludeChineseChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactSeasonYearSelector(ThemeData theme) {
    return Row(
      children: [
        // Season dropdown
        Expanded(
          child: Row(
            children: [
              Text(
                'Season:',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: DropdownMenu<String>(
                  initialSelection: widget.selectedSeason,
                  width: 100,
                  textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  menuHeight: 160,
                  inputDecorationTheme: InputDecorationTheme(
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  onSelected: (value) {
                    if (value != null) {
                      widget.onSeasonChanged(value);
                    }
                  },
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'winter', label: 'Winter'),
                    DropdownMenuEntry(value: 'spring', label: 'Spring'),
                    DropdownMenuEntry(value: 'summer', label: 'Summer'),
                    DropdownMenuEntry(value: 'fall', label: 'Fall'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Year dropdown
        Expanded(
          child: Row(
            children: [
              Text(
                'Year:',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: DropdownMenu<int>(
                  initialSelection: widget.selectedYear,
                  menuHeight: 200,
                  width: 100,
                  textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  inputDecorationTheme: InputDecorationTheme(
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  onSelected: (value) {
                    if (value != null) {
                      widget.onYearChanged(value);
                    }
                  },
                  dropdownMenuEntries: List.generate(
                    DateTime.now().year - 1959,
                    (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuEntry(
                        value: year,
                        label: year.toString(),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: widget.isLoading ? null : widget.onValidateAllRss,
              icon: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 16,
              ),
              label: const Text(
                'Validate RSS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed: widget.isLoading ? null : widget.onAddAnimeManually,
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            label: const Text(
              'Add Anime',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelValidationButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: widget.onCancelValidation,
        icon: const Icon(Icons.stop, color: Colors.white, size: 16),
        label: const Text(
          'Stop Validation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  Widget _buildSortDropdown(ThemeData theme) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sort,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          DropdownMenu<String>(
            initialSelection: widget.sortBy,
            width: 120,
            menuHeight: 220,
            textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            inputDecorationTheme: const InputDecorationTheme(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 4),
            ),
            onSelected: (value) {
              if (value != null) {
                widget.onSortChanged(value);
              }
            },
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'alpha', label: 'A-Z'),
              DropdownMenuEntry(value: 'alpha_reverse', label: 'Z-A'),
              DropdownMenuEntry(value: 'members_high', label: 'Mem. ↓'),
              DropdownMenuEntry(value: 'members_low', label: 'Mem. ↑'),
              DropdownMenuEntry(value: 'date_newest', label: 'Newest First'),
              DropdownMenuEntry(value: 'date_oldest', label: 'Oldest First'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionActionBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: Row(
        children: [
          Text(
            '${widget.selectedItems} selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onPressed: widget.onDeleteSelected,
            icon: const Icon(Icons.delete, color: Colors.white, size: 16),
            label: const Text(
              'Delete Selected',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.progressText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onBackground,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSavedListsSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
      child: Row(
        children: [
          Icon(Icons.folder_open, color: theme.colorScheme.primary, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownMenu<String>(
              initialSelection: widget.selectedListName,
              width: double.infinity,
              hintText: 'Load saved list',
              textStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              menuHeight: 240,
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              onSelected: (value) {
                if (value != null) {
                  widget.onLoadList(value);
                }
              },
              dropdownMenuEntries:
                  widget.savedLists.keys.map((name) {
                    return DropdownMenuEntry<String>(
                      value: name,
                      label: name,
                      trailingIcon: IconButton(
                        icon: Icon(
                          Icons.delete,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => widget.onDeleteList(name),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
