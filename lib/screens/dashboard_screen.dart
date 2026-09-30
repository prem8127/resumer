import 'dart:async';
import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/india_locations.dart';
import '../data/influencer_catalog.dart';
import '../models/influencer.dart';
import '../models/models.dart';
import '../services/job_search_service.dart';
import '../services/cloud_data_service.dart';
import 'job_site_browser_screen.dart';
import '../widgets/route_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/influencer_widgets.dart';
import 'ai_interview_setup_screen.dart';
import 'influencer_details_screen.dart';
import 'resumes_screen.dart' show TailorFlow;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final JobSearchService _jobSearch = JobSearchService();
  final CloudDataService _cloud = CloudDataService();
  String _query = '';
  String _submittedQuery = '';
  String _filter = 'All';
  bool _coreFitOnly = false;
  String? _selectedCompany;
  bool _loadingJobs = false;
  bool _loadingMore = false;
  bool _canLoadMore = false;
  int _currentPage = 1;
  String _datePosted = 'all';
  String? _feedNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.of(context);
      if (state.preferredLocation == null) {
        _promptForLocation();
      } else {
        _refreshJobs();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _jobSearch.dispose();
    super.dispose();
  }

  /// Asks for the preferred location, then loads the feed. Shown automatically
  /// on first visit when no location has been chosen yet.
  Future<void> _promptForLocation() async {
    final AppState state = AppScope.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LocationPickerSheet(),
    );
    if (!mounted) return;
    if (selected != null) {
      state.setPreferredLocation(selected);
      // Reset filters so the nearby feed isn't hidden behind stale ones.
      setState(() {
        _filter = 'All';
        _selectedCompany = null;
        _coreFitOnly = false;
        _query = '';
        _searchController.clear();
      });
    }
    await _refreshJobs();
  }

  Future<void> _changeLocation() => _promptForLocation();

  Future<void> _refreshJobs({bool loadMore = false}) async {
    if (_loadingJobs || _loadingMore) return;
    final AppState state = AppScope.of(context);
    final location = state.preferredLocation;
    final locationRequestsRemote =
        location?.toLowerCase().startsWith('remote') ?? false;
    final nextPage = loadMore ? _currentPage + 1 : 1;
    setState(() {
      if (loadMore) {
        _loadingMore = true;
      } else {
        _loadingJobs = true;
      }
      _feedNotice = null;
    });

    final jobs = await _jobSearch.searchJobs(
      query: _effectiveSearchQuery,
      location: locationRequestsRemote ? null : location,
      country: _countryCodeFor(location),
      page: nextPage,
      numPages: 1,
      datePosted: _datePosted,
      remoteJobsOnly:
          _filter == 'Remote' || locationRequestsRemote ? true : null,
      employmentTypes: switch (_filter) {
        'Internships' => 'INTERN',
        'Full-time' => 'FULLTIME',
        'Part-time' => 'PARTTIME',
        'Contract' => 'CONTRACTOR',
        _ => null,
      },
      careerItems: state.careerItems,
    );
    if (!mounted) return;

    if (_jobSearch.lastSearchSucceeded) {
      if (loadMore) {
        state.appendJobOpenings(jobs, live: true);
      } else {
        state.replaceJobOpenings(jobs, live: true);
      }
      setState(() {
        _loadingJobs = false;
        _loadingMore = false;
        if (!loadMore) _submittedQuery = _searchController.text.trim();
        _currentPage = nextPage;
        _canLoadMore = _jobSearch.hasMore;
        _feedNotice = jobs.isEmpty
            ? (loadMore
                ? 'No more matching jobs are available.'
                : location != null
                    ? 'No open roles discovered near $location. Try another city or explore remote jobs.'
                    : 'No matching jobs were returned. Try another search.')
            : null;
      });
    } else {
      // Preserve the current page, falling back to the non-sensitive cache.
      if (!loadMore && state.jobOpenings.isEmpty) {
        final cached = await _jobSearch.getStoredJobs();
        if (cached.isNotEmpty && mounted) {
          state.replaceJobOpenings(cached, live: false);
        }
      }
      setState(() {
        _loadingJobs = false;
        _loadingMore = false;
        _feedNotice = _jobSearch.lastError ??
            'Job search is temporarily unavailable. Try again shortly.';
      });
    }
  }

  String get _effectiveSearchQuery {
    final typed = _searchController.text.trim();
    if (typed.isNotEmpty) return typed;
    return switch (_filter) {
      'Internships' => 'internships',
      'Remote' => 'remote jobs',
      'Full-time' => 'full-time jobs',
      'Part-time' => 'part-time jobs',
      'Contract' => 'contract jobs',
      _ => 'software jobs',
    };
  }

  String? _countryCodeFor(String? location) {
    if (location?.toLowerCase().contains('india') ?? false) return 'in';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final coreSkills = _extractCoreSkills(state);

    final jobs = state.jobOpenings.where((job) {
      final typedQuery = _query.trim().toLowerCase();
      final query =
          typedQuery == _submittedQuery.toLowerCase() ? '' : typedQuery;
      final matchesQuery = query.isEmpty ||
          job.title.toLowerCase().contains(query) ||
          job.companyName.toLowerCase().contains(query) ||
          job.skills.any((skill) => skill.toLowerCase().contains(query));

      final matchesFilter = switch (_filter) {
        'Remote' => job.workMode.toLowerCase() == 'remote',
        'Internships' => job.employmentType.toLowerCase().contains('intern'),
        'Full-time' => job.employmentType.toLowerCase().contains('full'),
        'Part-time' => job.employmentType.toLowerCase().contains('part'),
        'Contract' => job.employmentType.toLowerCase().contains('contract'),
        _ => true,
      };

      final matchesCompany = _selectedCompany == null ||
          job.companyName.toLowerCase() == _selectedCompany!.toLowerCase();

      final matchesCore = !_coreFitOnly ||
          job.matchScore >= 75 ||
          _jobMatchesCoreSkills(job, coreSkills);

      return matchesQuery && matchesFilter && matchesCompany && matchesCore;
    }).toList();

    final featured = state.jobOpenings.isEmpty ? null : state.jobOpenings.first;

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 132),
        children: [
          _HomeHeader(
            state: state,
            loading: _loadingJobs,
            onRefresh: _refreshJobs,
          ),
          if (_feedNotice != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 15, color: AppColors.warning),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _feedNotice!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Find work\nthat fits.',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            state.preferredLocation != null
                ? 'Live roles near ${state.preferredLocation}, scored against your skills.'
                : state.jobsAreLive
                    ? 'Fresh roles fetched live from the web feed, scored against your skills.'
                    : 'Top company internships and roles scored against your master resume.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.stone),
          ),
          const SizedBox(height: 16),
          _LocationBanner(
            location: state.preferredLocation,
            jobCount: state.jobOpenings.length,
            loading: _loadingJobs,
            onSelect: _changeLocation,
            onClear: state.preferredLocation == null
                ? null
                : () async {
                    AppScope.of(context).setPreferredLocation(null);
                    await _refreshJobs();
                  },
          ),
          const SizedBox(height: 18),

          // -----------------------------------------------------------------
          // Influencers status strip links to published Supabase profiles.
          // -----------------------------------------------------------------
          StreamBuilder<List<Influencer>>(
            stream: _cloud.watchApprovedInfluencers(),
            builder: (context, snapshot) {
              final influencers = snapshot.data ?? kInfluencerCatalog;
              if (influencers.isEmpty) return const SizedBox.shrink();
              return Column(children: [
                SectionHeader(
                  title: 'Influencers',
                  action: 'See all',
                  onAction: () => widget.onNavigate(6),
                ),
                const SizedBox(height: 10),
                _InfluencerStatusRow(influencers: influencers),
                const SizedBox(height: 18),
              ]);
            },
          ),

          // -----------------------------------------------------------------
          // The 3 Small Interactive Circles
          // -----------------------------------------------------------------
          _InsightCirclesRow(
            state: state,
            coreFitActive: _coreFitOnly,
            selectedCompany: _selectedCompany,
            onTapCompanies: () => _showCompaniesModal(context, state),
            onTapOpenings: () => _showOpeningsModal(context, state),
            onTapCoreMatches: () => _toggleCoreFit(context, state),
          ),
          const SizedBox(height: 18),

          // -----------------------------------------------------------------
          // AI Interview promo
          // -----------------------------------------------------------------
          _AiInterviewBanner(
            onTap: () => pushRouteOnce(
              context,
              (_) => const AiInterviewSetupScreen(),
            ),
          ),
          const SizedBox(height: 18),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (_) => _refreshJobs(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search role, company, or skill',
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              suffixIcon: _query.isEmpty
                  ? IconButton(
                      tooltip: 'Date posted',
                      onPressed: _showDateFilter,
                      icon: const Icon(Icons.tune_rounded, size: 19),
                    )
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
            ),
          ),

          if (_selectedCompany != null || _coreFitOnly) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_selectedCompany != null)
                  Chip(
                    avatar: const Icon(Icons.business_rounded, size: 14),
                    label: Text('Company: $_selectedCompany'),
                    onDeleted: () => setState(() => _selectedCompany = null),
                  ),
                if (_coreFitOnly)
                  Chip(
                    avatar: const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: AppColors.sage),
                    label: const Text('Filtered: Core Resume Fit'),
                    onDeleted: () => setState(() => _coreFitOnly = false),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 18),
          if (featured != null &&
              _selectedCompany == null &&
              !_coreFitOnly &&
              _query.isEmpty &&
              _filter == 'All') ...[
            _FeaturedProductBanner(
              job: featured,
              onTap: () => _showJob(context, state, featured),
            ),
            const SizedBox(height: 24),
          ],

          SectionHeader(
            title: 'Open roles',
            subtitle: '${jobs.length} opportunities for your profile',
            action: 'Tracker',
            onAction: () => widget.onNavigate(3),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final label in const [
                  'All',
                  'Remote',
                  'Internships',
                  'Full-time',
                  'Part-time',
                  'Contract',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == label,
                      onSelected: (_) {
                        setState(() => _filter = label);
                        _refreshJobs();
                      },
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_rounded, size: 14),
                  label: Text(_datePosted == 'all'
                      ? 'Any date'
                      : switch (_datePosted) {
                          'today' => 'Today',
                          '3days' => 'Past 3 days',
                          'week' => 'Past week',
                          'month' => 'Past month',
                          _ => 'Any date',
                        }),
                  onPressed: _showDateFilter,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (jobs.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching roles found',
              subtitle: _coreFitOnly
                  ? 'No roles matched the core filter. Tap "Openings" circle to view all.'
                  : state.preferredLocation != null
                      ? 'No live roles were found near ${state.preferredLocation} right now. Try a nearby city or check back later.'
                      : 'Try searching another company, skill, or keyword.',
              actionLabel:
                  _coreFitOnly || _selectedCompany != null || _query.isNotEmpty
                      ? 'Reset filters'
                      : state.preferredLocation != null
                          ? 'Change location'
                          : null,
              onAction: () {
                if (_coreFitOnly ||
                    _selectedCompany != null ||
                    _query.isNotEmpty) {
                  setState(() {
                    _coreFitOnly = false;
                    _selectedCompany = null;
                    _filter = 'All';
                    _query = '';
                    _searchController.clear();
                  });
                  _refreshJobs();
                  return;
                }
                if (state.preferredLocation != null) {
                  _changeLocation();
                }
              },
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.51,
              ),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return _JobProductCard(
                  job: job,
                  onTap: () => _showJob(context, state, job),
                  onSave: () => state.toggleJobSaved(job.id),
                  onTailor: () {
                    pushRouteOnce(
                      context,
                      (_) => TailorFlow(
                        initialResume: _sourceResume(state),
                        initialJobDescription:
                            '${job.title} — ${job.companyName}\n\n${job.description}\n\nSkills: ${job.skills.join(', ')}',
                        job: job,
                      ),
                    );
                  },
                );
              },
            ),
            if (_canLoadMore) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton.icon(
                  onPressed:
                      _loadingMore ? null : () => _refreshJobs(loadMore: true),
                  icon: _loadingMore
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(_loadingMore ? 'Loading…' : 'Load more jobs'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showDateFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const {
              'all': 'Any date',
              'today': 'Today',
              '3days': 'Past 3 days',
              'week': 'Past week',
              'month': 'Past month',
            }.entries)
              ListTile(
                leading: Icon(
                  option.key == _datePosted
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(option.value),
                onTap: () => Navigator.of(sheetContext).pop(option.key),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == _datePosted) return;
    setState(() => _datePosted = selected);
    await _refreshJobs();
  }

  Set<String> _extractCoreSkills(AppState state) {
    return {
      for (final item in state.careerItems)
        if (item.type == CareerItemType.skill && item.title.trim().isNotEmpty)
          item.title.trim().toLowerCase(),
      for (final item in state.careerItems)
        if (item.type == CareerItemType.experience ||
            item.type == CareerItemType.project)
          ...item.bullets
              .expand((b) => b.split(RegExp(r'[\s,;]+')))
              .where((w) => w.length > 3)
              .map((w) => w.toLowerCase()),
    };
  }

  bool _jobMatchesCoreSkills(JobOpening job, Set<String> coreSkills) {
    if (coreSkills.isEmpty) return job.matchScore >= 70;
    final haystack =
        '${job.title} ${job.skills.join(' ')} ${job.description}'.toLowerCase();
    return coreSkills.any((skill) => haystack.contains(skill));
  }

  void _toggleCoreFit(BuildContext context, AppState state) {
    final nextState = !_coreFitOnly;
    setState(() {
      _coreFitOnly = nextState;
      if (nextState) _selectedCompany = null;
    });

    _showCoreFitModal(context, state);
  }

  void _showCompaniesModal(BuildContext context, AppState state) {
    final jobs = state.jobOpenings;
    final companyCounts = <String, int>{};
    for (final job in jobs) {
      companyCounts[job.companyName] =
          (companyCounts[job.companyName] ?? 0) + 1;
    }

    final sortedCompanies = companyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (context, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurfaceSubtle
                          : AppColors.sageSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business_rounded,
                        size: 20, color: AppColors.sage),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hiring Companies (${sortedCompanies.length})',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text('Companies with active job & internship openings',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _selectedCompany = null);
                  Navigator.of(sheetContext).pop();
                },
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Show all companies'),
              ),
              const SizedBox(height: 14),
              for (final entry in sortedCompanies)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    borderRadius: 14,
                    onTap: () {
                      setState(() {
                        _selectedCompany = entry.key;
                        _coreFitOnly = false;
                      });
                      Navigator.of(sheetContext).pop();
                    },
                    child: Row(
                      children: [
                        CompanyAvatar(name: entry.key, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.value} ${entry.value == 1 ? 'opening' : 'openings'} available',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkSurfaceSubtle
                                    : AppColors.sageSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('View',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(width: 3),
                              Icon(Icons.chevron_right_rounded, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showOpeningsModal(BuildContext context, AppState state) {
    final jobs = state.jobOpenings;
    final internships = jobs
        .where((j) => j.employmentType.toLowerCase().contains('intern'))
        .length;
    final fullTime = jobs
        .where((j) => j.employmentType.toLowerCase().contains('full'))
        .length;
    final remote =
        jobs.where((j) => j.workMode.toLowerCase().contains('remote')).length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.58,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurfaceSubtle
                          : AppColors.sageSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.work_outline_rounded,
                        size: 20, color: AppColors.sage),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Openings (${jobs.length})',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          state.jobsAreLive
                              ? 'Live feed active from public remote board'
                              : 'Curated top company internships & graduate roles',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      value: '$internships',
                      label: 'Internships',
                      icon: Icons.school_outlined,
                      note: 'Top tech companies',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricTile(
                      value: '$fullTime',
                      label: 'Full-time',
                      icon: Icons.work_outline_rounded,
                      note: 'Grad & junior roles',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricTile(
                      value: '$remote',
                      label: 'Remote',
                      icon: Icons.public_rounded,
                      note: 'Work from anywhere',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _filter = 'All';
                    _selectedCompany = null;
                    _coreFitOnly = false;
                  });
                  Navigator.of(sheetContext).pop();
                  _refreshJobs();
                },
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text('View all openings in feed'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCoreFitModal(BuildContext context, AppState state) {
    final master = _sourceResume(state);
    final coreSkills = _extractCoreSkills(state);
    final jobs = state.jobOpenings;
    final matchedJobs = jobs
        .where(
            (j) => j.matchScore >= 75 || _jobMatchesCoreSkills(j, coreSkills))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (context, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurfaceSubtle
                          : AppColors.sageSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 20, color: AppColors.sage),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Core Resume Matches (${matchedJobs.length})',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          master != null
                              ? 'Matched to ${master.name}'
                              : 'Roles tailored to your evidence vault skills',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurfaceSubtle
                      : AppColors.sageSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Skills detected from your profile:',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in state.careerItems.where((c) =>
                            c.type == CareerItemType.skill ||
                            c.type == CareerItemType.experience))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkSurface
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.darkBorder
                                    : AppColors.line,
                              ),
                            ),
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.violetSoft
                                    : AppColors.sage,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _coreFitOnly = false);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Show all roles'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _coreFitOnly = true);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Apply match filter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Resume? _sourceResume(AppState state) {
    for (final resume in state.resumes) {
      if (resume.type == ResumeType.master) return resume;
    }
    return state.resumes.isEmpty ? null : state.resumes.first;
  }

  /// The public board a live role came from, shown on the job sheet
  /// so it's clear where "Apply" will take the user.
  String? _sourceHost(JobOpening job) {
    final uri = Uri.tryParse(job.url?.trim() ?? '');
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.host.replaceFirst(RegExp(r'^www\.'), '');
  }

  /// Opens the posting inside the app so the user can sign in there and
  /// submit their application with profile autofill.
  Future<void> _applyOnSite(BuildContext sheetContext, JobOpening job) async {
    Navigator.of(sheetContext).pop();
    await Navigator.of(sheetContext).push(
      MaterialPageRoute<void>(
        builder: (_) => JobSiteBrowserScreen(job: job),
      ),
    );
  }

  void _showJob(BuildContext context, AppState state, JobOpening job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .78,
          minChildSize: .58,
          maxChildSize: .94,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyAvatar(name: job.companyName, size: 50),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.title,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 5),
                        Text(job.companyName,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: job.saved ? 'Remove saved job' : 'Save job',
                    onPressed: () {
                      state.toggleJobSaved(job.id);
                      Navigator.of(sheetContext).pop();
                    },
                    icon: Icon(job.saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                      icon: Icons.location_on_outlined, label: job.location),
                  _MetaPill(icon: Icons.schedule_rounded, label: job.workMode),
                  _MetaPill(
                      icon: Icons.work_outline_rounded,
                      label: job.employmentType),
                  if (_sourceHost(job) != null)
                    _MetaPill(
                        icon: Icons.link_rounded,
                        label: 'via ${_sourceHost(job)}'),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurfaceSubtle
                      : AppColors.sageSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    MatchRing(score: job.matchScore, size: 50, stroke: 4),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Strong profile match',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 3),
                          Text(
                            'Based on evidence already in your career profile.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Text('About the role',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 9),
              Text(job.description,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 23),
              Text('Skills in this role',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in job.skills) Chip(label: Text(skill))
                ],
              ),
              const SizedBox(height: 23),
              FilledButton.tonalIcon(
                onPressed: () => _applyOnSite(sheetContext, job),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Apply on company site'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        state.trackJob(job);
                        Navigator.of(sheetContext).pop();
                        widget.onNavigate(3);
                      },
                      child: const Text('Save to tracker'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        pushRouteOnce(
                          context,
                          (_) => TailorFlow(
                            initialResume: _sourceResume(state),
                            initialJobDescription:
                                '${job.title} — ${job.companyName}\n\n${job.description}\n\nSkills: ${job.skills.join(', ')}',
                            job: job,
                          ),
                        );
                      },
                      child: const Text('Tailor resume'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3 Interactive Insight Circles Row
// ---------------------------------------------------------------------------

/// Horizontal "status circles" strip — a WhatsApp-Status-style entry point
/// into the existing Influencer flow. Tapping a circle opens the same
/// [InfluencerDetailsScreen] used by the dedicated Influencers tab; no new
/// influencer/course/test/certificate system is introduced here.
class _InfluencerStatusRow extends StatelessWidget {
  const _InfluencerStatusRow({required this.influencers});

  final List<Influencer> influencers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: influencers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final influencer = influencers[index];
          return _InfluencerStatusCircle(
            influencer: influencer,
            onTap: () => pushRouteOnce(
              context,
              (_) => InfluencerDetailsScreen(influencer: influencer),
            ),
          );
        },
      ),
    );
  }
}

class _InfluencerStatusCircle extends StatelessWidget {
  const _InfluencerStatusCircle({
    required this.influencer,
    required this.onTap,
  });

  final Influencer influencer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [
                  ...AppColors.prism,
                  ...AppColors.prism,
                ]),
              ),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: InfluencerAvatar(
                  name: influencer.name,
                  size: 56,
                  photoUrl: influencer.profilePhotoUrl,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              influencer.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInterviewBanner extends StatelessWidget {
  const _AiInterviewBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      onTap: onTap,
      color: dark ? AppColors.darkSurfaceSubtle : AppColors.lightBlue,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.mic_rounded,
                size: 22, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Mock Interview',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  'Practice with AI-generated questions for any role.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primaryBlue),
        ],
      ),
    );
  }
}

class _InsightCirclesRow extends StatelessWidget {
  const _InsightCirclesRow({
    required this.state,
    required this.coreFitActive,
    required this.selectedCompany,
    required this.onTapCompanies,
    required this.onTapOpenings,
    required this.onTapCoreMatches,
  });

  final AppState state;
  final bool coreFitActive;
  final String? selectedCompany;
  final VoidCallback onTapCompanies;
  final VoidCallback onTapOpenings;
  final VoidCallback onTapCoreMatches;

  @override
  Widget build(BuildContext context) {
    final jobs = state.jobOpenings;
    final companiesCount =
        jobs.map((job) => job.companyName.toLowerCase()).toSet().length;
    final coreMatchesCount = jobs.where((j) => j.matchScore >= 75).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Circle 1: Companies Count
        Expanded(
          child: _StatCircleButton(
            icon: Icons.business_rounded,
            count: '$companiesCount',
            label: 'Companies',
            hint: 'In the app',
            isActive: selectedCompany != null,
            onTap: onTapCompanies,
          ),
        ),
        const SizedBox(width: 10),

        // Circle 2: Openings Count
        Expanded(
          child: _StatCircleButton(
            icon: Icons.work_outline_rounded,
            count: '${jobs.length}',
            label: 'Openings',
            hint: 'Active roles',
            isActive: !coreFitActive && selectedCompany == null,
            onTap: onTapOpenings,
          ),
        ),
        const SizedBox(width: 10),

        // Circle 3: Core Matches
        Expanded(
          child: _StatCircleButton(
            icon: Icons.auto_awesome_rounded,
            count: '$coreMatchesCount',
            label: 'Core Match',
            hint: 'Fits resume',
            isActive: coreFitActive,
            highlightColor: AppColors.sage,
            onTap: onTapCoreMatches,
          ),
        ),
      ],
    );
  }
}

class _StatCircleButton extends StatelessWidget {
  const _StatCircleButton({
    required this.icon,
    required this.count,
    required this.label,
    required this.hint,
    required this.onTap,
    this.isActive = false,
    this.highlightColor,
  });

  final IconData icon;
  final String count;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool isActive;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        highlightColor ?? (dark ? AppColors.violetSoft : AppColors.sage);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? (dark
                    ? activeColor.withValues(alpha: 0.16)
                    : AppColors.sageSoft)
                : (dark ? AppColors.darkSurface : AppColors.paper),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : (dark ? AppColors.darkBorder : AppColors.line),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circle Avatar with Count
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? activeColor
                      : (dark
                          ? AppColors.darkSurfaceSubtle
                          : AppColors.sageSoft),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 13,
                        color: isActive
                            ? Colors.white
                            : (dark ? AppColors.violetSoft : AppColors.sage),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        count,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: isActive
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? (dark ? AppColors.brightBlue : AppColors.primaryBlue)
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 9.5,
                  color: dark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Amazon / Flipkart Style Product Job Card
// ---------------------------------------------------------------------------

class _JobProductCard extends StatelessWidget {
  const _JobProductCard({
    required this.job,
    required this.onTap,
    required this.onSave,
    required this.onTailor,
  });

  final JobOpening job;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onTailor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isTopMatch = job.matchScore >= 80;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.line,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.22 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Product Logo Banner (135*114 Length/Ratio) with floating badges
              Stack(
                children: [
                  CompanyLogoBanner(
                    name: job.companyName,
                    height: 114,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                  ),

                  // Floating Bookmark / Wishlist button (Amazon / Flipkart heart button)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: (dark ? AppColors.darkSurface : Colors.white)
                          .withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onSave,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            job.saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 17,
                            color: job.saved
                                ? (dark ? AppColors.violetSoft : AppColors.sage)
                                : (dark
                                    ? AppColors.darkMuted
                                    : AppColors.stone),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating Deal / Match Pill (Top left)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isTopMatch
                            ? (dark
                                ? AppColors.success.withValues(alpha: .24)
                                : AppColors.successSubtle)
                            : (dark
                                ? AppColors.darkSurfaceSubtle
                                : AppColors.lightBlue),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isTopMatch
                              ? AppColors.success.withValues(alpha: 0.4)
                              : Colors.transparent,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTopMatch
                                ? Icons.local_fire_department_rounded
                                : Icons.auto_awesome_rounded,
                            size: 10,
                            color: isTopMatch
                                ? AppColors.success
                                : (dark
                                    ? AppColors.brightBlue
                                    : AppColors.primaryBlue),
                          ),
                          const SizedBox(width: 2.5),
                          Text(
                            '${job.matchScore}%',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isTopMatch
                                  ? AppColors.success
                                  : (dark
                                      ? AppColors.brightBlue
                                      : AppColors.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Product Info Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Company & Rating Row
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  job.companyName,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: dark
                                        ? AppColors.darkMuted
                                        : AppColors.stone,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.verified_rounded,
                                size: 12,
                                color: AppColors.primaryBlue,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.warningSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 10,
                                      color: AppColors.warning,
                                    ),
                                    SizedBox(width: 1.5),
                                    Text(
                                      '4.8',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Job Title
                          Text(
                            job.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // Price / Stipend (Amazon Style Bold Price)
                      Text(
                        job.salaryLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Product Specs: Location & Work mode
                      Text(
                        '${job.location} · ${job.workMode}',
                        style: TextStyle(
                          fontSize: 10,
                          color: dark ? AppColors.darkMuted : AppColors.stone,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Action Button (Tailor)
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: OutlinedButton(
                          onPressed: onTailor,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(
                              color:
                                  dark ? AppColors.darkBorder : AppColors.line,
                            ),
                          ),
                          child: Text(
                            'Tailor resume',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: dark
                                  ? AppColors.brightBlue
                                  : AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark hero card promoting the newest role in the feed.
class _FeaturedProductBanner extends StatelessWidget {
  const _FeaturedProductBanner({required this.job, required this.onTap});

  final JobOpening job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.darkBlue, AppColors.primaryBlue],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 11, color: AppColors.sageSoft),
                        SizedBox(width: 5),
                        Text(
                          'FEATURED ROLE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                            color: AppColors.sageSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 17, color: Colors.white70),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                job.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${job.companyName} · ${job.location} · ${job.salaryLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: .72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top app bar row: brand mark, live-feed pill, refresh and avatar.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.state,
    this.loading = false,
    this.onRefresh,
  });

  final AppState state;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'R',
            style: TextStyle(
              color: Theme.of(context).scaffoldBackgroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text('Resumer',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        if (state.jobsAreLive) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.successSubtle,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_rounded,
                    size: 11, color: AppColors.success),
                SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh job feed',
            onPressed: onRefresh,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceSubtle
                : AppColors.sageSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            state.user.initials,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceSubtle
            : AppColors.canvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.stone),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preferred Location
// ---------------------------------------------------------------------------

/// Banner above the feed. Prompts for a location when none is set; otherwise
/// shows the active nearby filter with change / clear actions.
class _LocationBanner extends StatelessWidget {
  const _LocationBanner({
    required this.location,
    required this.jobCount,
    required this.loading,
    required this.onSelect,
    this.onClear,
  });

  final String? location;
  final int jobCount;
  final bool loading;
  final VoidCallback onSelect;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (location == null) {
      return Material(
        color: dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onSelect,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 20, color: AppColors.sage),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select your preferred location to see jobs near you',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.stone),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurfaceSubtle : AppColors.paper,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark ? Colors.white10 : AppColors.sageSoft,
              shape: BoxShape.circle,
            ),
            child: loading
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.location_on_rounded,
                    size: 16, color: AppColors.sage),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Near $location',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text('$jobCount live roles from JSearch',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.stone,
                        )),
              ],
            ),
          ),
          TextButton(
            onPressed: onSelect,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Change'),
          ),
          IconButton(
            tooltip: 'Show all locations',
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
            iconSize: 17,
            icon: const Icon(Icons.close_rounded, color: AppColors.stone),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet asking the user to pick their preferred location.
/// Supports a structured 3-step hierarchy: State -> District -> City,
/// as well as universal search and remote options.
class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  int _step = 0; // 0 = State, 1 = District, 2 = City
  IndianState? _selectedState;
  IndianDistrict? _selectedDistrict;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onBack() {
    setState(() {
      _query = '';
      _searchController.clear();
      if (_step == 2) {
        _step = 1;
        _selectedDistrict = null;
      } else if (_step == 1) {
        _step = 0;
        _selectedState = null;
      }
    });
  }

  void _selectState(IndianState state) {
    setState(() {
      _selectedState = state;
      _step = 1;
      _query = '';
      _searchController.clear();
    });
  }

  void _selectDistrict(IndianDistrict district) {
    setState(() {
      _selectedDistrict = district;
      _step = 2;
      _query = '';
      _searchController.clear();
    });
  }

  void _finishSelection(String location) {
    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with navigation & title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top navigation row
                  Row(
                    children: [
                      if (_step > 0)
                        IconButton(
                          onPressed: _onBack,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          icon: const Icon(Icons.arrow_back_rounded, size: 22),
                          color: AppColors.sage,
                          tooltip: 'Back',
                        )
                      else
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.sageSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_rounded,
                              size: 19, color: AppColors.sage),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _step == 0
                                  ? 'Select State'
                                  : _step == 1
                                      ? 'Select District in ${_selectedState?.name}'
                                      : 'Select City in ${_selectedDistrict?.name}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _step == 0
                                  ? 'Step 1 of 3 · Choose state first'
                                  : _step == 1
                                      ? 'Step 2 of 3 · Choose district'
                                      : 'Step 3 of 3 · Choose your target city',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.stone,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.stone),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Breadcrumb step pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StepPill(
                          label: _selectedState != null
                              ? _selectedState!.name
                              : '1. State',
                          isActive: _step == 0,
                          isCompleted: _step > 0,
                          onTap: _step > 0
                              ? () {
                                  setState(() {
                                    _step = 0;
                                    _selectedDistrict = null;
                                    _query = '';
                                    _searchController.clear();
                                  });
                                }
                              : null,
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.stone),
                        _StepPill(
                          label: _selectedDistrict != null
                              ? _selectedDistrict!.name
                              : '2. District',
                          isActive: _step == 1,
                          isCompleted: _step > 1,
                          onTap: _step > 1
                              ? () {
                                  setState(() {
                                    _step = 1;
                                    _query = '';
                                    _searchController.clear();
                                  });
                                }
                              : null,
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.stone),
                        _StepPill(
                          label: '3. City',
                          isActive: _step == 2,
                          isCompleted: false,
                          onTap: null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Search Field
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _finishSelection(value.trim());
                      }
                    },
                    decoration: InputDecoration(
                      hintText: _step == 0
                          ? 'Search state, district, or city...'
                          : _step == 1
                              ? 'Search district in ${_selectedState?.name}...'
                              : 'Search city in ${_selectedDistrict?.name}...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content List based on step & search
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
                children: [
                  // If user has typed a query, show matching items or universal search
                  if (query.isNotEmpty) ...[
                    _buildSearchResults(query, context, isDark),
                  ] else ...[
                    // Step-specific views
                    if (_step == 0) _buildStateStep(context),
                    if (_step == 1 && _selectedState != null)
                      _buildDistrictStep(_selectedState!, context),
                    if (_step == 2 &&
                        _selectedDistrict != null &&
                        _selectedState != null)
                      _buildCityStep(
                          _selectedState!, _selectedDistrict!, context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 0: State Selection List
  Widget _buildStateStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Shortcuts
        const _SectionHeader(title: 'QUICK OPTIONS'),
        _LocationTile(
          icon: Icons.public_rounded,
          title: 'Remote · Work from Anywhere',
          subtitle: 'Search remote & distributed roles globally',
          onTap: () => _finishSelection('Remote · Anywhere'),
        ),
        _LocationTile(
          icon: Icons.flag_rounded,
          title: 'All India · Pan-India Roles',
          subtitle: 'Search across all Indian tech hubs',
          onTap: () => _finishSelection('India'),
        ),

        const SizedBox(height: 12),
        const _SectionHeader(title: 'STATES & UNION TERRITORIES'),
        for (final state in IndianLocationData.states)
          _LocationTile(
            icon: Icons.map_rounded,
            title: state.name,
            subtitle:
                '${state.districts.length} districts · ${state.allCities.length} tech hubs',
            onTap: () => _selectState(state),
            trailingIcon: Icons.arrow_forward_ios_rounded,
          ),
      ],
    );
  }

  /// Step 1: District Selection List
  Widget _buildDistrictStep(IndianState state, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'STATEWIDE SEARCH'),
        _LocationTile(
          icon: Icons.travel_explore_rounded,
          title: 'Entire ${state.name}',
          subtitle: 'Search all roles across all districts in ${state.name}',
          onTap: () => _finishSelection('${state.name}, India'),
          highlight: true,
        ),
        const SizedBox(height: 12),
        _SectionHeader(title: 'DISTRICTS IN ${state.name.toUpperCase()}'),
        for (final district in state.districts)
          _LocationTile(
            icon: Icons.apartment_rounded,
            title: district.name,
            subtitle: district.cities.isNotEmpty
                ? '${district.cities.length} cities (${district.cities.take(3).join(', ')}...)'
                : '${district.cities.length} cities',
            onTap: () => _selectDistrict(district),
            trailingIcon: Icons.arrow_forward_ios_rounded,
          ),
      ],
    );
  }

  /// Step 2: City Selection List
  Widget _buildCityStep(
      IndianState state, IndianDistrict district, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'DISTRICT-WIDE SEARCH'),
        _LocationTile(
          icon: Icons.travel_explore_rounded,
          title: 'All of ${district.name}',
          subtitle: 'Search all roles in ${district.name}, ${state.name}',
          onTap: () => _finishSelection('${district.name}, ${state.name}'),
          highlight: true,
        ),
        const SizedBox(height: 12),
        _SectionHeader(
            title: 'CITIES & TECH HUBS IN ${district.name.toUpperCase()}'),
        for (final city in district.cities)
          _LocationTile(
            icon: Icons.location_city_rounded,
            title: city,
            subtitle: '${district.name}, ${state.name}',
            onTap: () => _finishSelection('$city, ${state.name}'),
            trailingIcon: Icons.check_circle_outline_rounded,
          ),
      ],
    );
  }

  /// Universal search results when typing in search box
  Widget _buildSearchResults(String query, BuildContext context, bool isDark) {
    // 1. Direct custom search option
    final customTile = _LocationTile(
      icon: Icons.edit_location_alt_rounded,
      title: 'Use “${_query.trim()}”',
      subtitle: 'Custom location search',
      onTap: () => _finishSelection(_query.trim()),
      highlight: true,
    );

    // 2. Search based on active step
    if (_step == 1 && _selectedState != null) {
      final matchingDistricts = _selectedState!.districts
          .where((d) => d.name.toLowerCase().contains(query))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          customTile,
          const SizedBox(height: 10),
          _SectionHeader(
              title:
                  'MATCHING DISTRICTS IN ${_selectedState!.name.toUpperCase()}'),
          for (final d in matchingDistricts)
            _LocationTile(
              icon: Icons.apartment_rounded,
              title: d.name,
              subtitle:
                  '${d.cities.length} cities (${d.cities.take(3).join(', ')}...)',
              onTap: () => _selectDistrict(d),
              trailingIcon: Icons.arrow_forward_ios_rounded,
            ),
          if (matchingDistricts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No district found matching “$query”. You can use the custom location above.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.stone),
              ),
            ),
        ],
      );
    }

    if (_step == 2 && _selectedDistrict != null && _selectedState != null) {
      final matchingCities = _selectedDistrict!.cities
          .where((c) => c.toLowerCase().contains(query))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          customTile,
          const SizedBox(height: 10),
          _SectionHeader(
              title:
                  'MATCHING CITIES IN ${_selectedDistrict!.name.toUpperCase()}'),
          for (final c in matchingCities)
            _LocationTile(
              icon: Icons.location_city_rounded,
              title: c,
              subtitle: '${_selectedDistrict!.name}, ${_selectedState!.name}',
              onTap: () => _finishSelection('$c, ${_selectedState!.name}'),
              trailingIcon: Icons.check_circle_outline_rounded,
            ),
          if (matchingCities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No city found matching “$query”. You can use the custom location above.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.stone),
              ),
            ),
        ],
      );
    }

    // Step 0: Universal search across States, Districts, and Cities
    final searchResults = IndianLocationData.search(query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        customTile,
        const SizedBox(height: 10),
        _SectionHeader(title: 'SEARCH RESULTS (${searchResults.length})'),
        for (final res in searchResults.take(25))
          _LocationTile(
            icon: res.type == 'state'
                ? Icons.map_rounded
                : res.type == 'district'
                    ? Icons.apartment_rounded
                    : Icons.location_city_rounded,
            title: res.title,
            subtitle: res.subtitle,
            onTap: () {
              if (res.type == 'state') {
                final st = IndianLocationData.states.firstWhere(
                  (s) => s.name.toLowerCase() == res.title.toLowerCase(),
                );
                _selectState(st);
              } else {
                _finishSelection(res.formattedLocation);
              }
            },
            trailingIcon: res.type == 'state'
                ? Icons.arrow_forward_ios_rounded
                : Icons.check_circle_outline_rounded,
          ),
        if (searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No matches found. Use the custom location option above to search anywhere.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.stone),
            ),
          ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.label,
    required this.isActive,
    required this.isCompleted,
    this.onTap,
  });

  final String label;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isActive
        ? AppColors.sage
        : isCompleted
            ? (isDark
                ? AppColors.sageSoft.withValues(alpha: 0.15)
                : AppColors.sageSoft)
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.canvas);

    final textColor = isActive
        ? Colors.white
        : isCompleted
            ? AppColors.sage
            : AppColors.stone;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCompleted) ...[
                  const Icon(Icons.check_rounded,
                      size: 13, color: AppColors.sage),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive || isCompleted
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: textColor,
                  ),
                ),
                if (onTap != null && isCompleted) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.edit_rounded, size: 11, color: textColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.stone,
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingIcon,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = highlight
        ? (isDark
            ? AppColors.sageSoft.withValues(alpha: 0.12)
            : AppColors.sageSoft.withValues(alpha: 0.6))
        : (isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.canvas);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: highlight
                        ? AppColors.sage.withValues(alpha: 0.15)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.sageSoft.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                      size: 18,
                      color: highlight
                          ? AppColors.sage
                          : (isDark ? Colors.white70 : AppColors.sage)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              highlight ? FontWeight.w700 : FontWeight.w600,
                          color:
                              highlight && !isDark ? AppColors.darkBlue : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.stone, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  trailingIcon ?? Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: highlight ? AppColors.sage : AppColors.stone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
