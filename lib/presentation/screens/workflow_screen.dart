import 'package:flutter/material.dart';
import '../../core/database/services/services.dart';
import '../../core/database/models/models.dart';
import '../widgets/spec_input_form.dart';
import '../widgets/spec_list_view.dart';

class WorkflowScreen extends StatefulWidget {
  const WorkflowScreen({super.key});

  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _specService = SpecService.instance;

  List<Specification> _specifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSpecifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSpecifications() async {
    setState(() => _isLoading = true);
    try {
      final specs = await _specService.getAllSpecifications();
      setState(() => _specifications = specs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading specifications: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onSpecificationCreated(Specification spec) async {
    await _loadSpecifications();
    _tabController.animateTo(1); // Switch to specifications list tab
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Workflow Assistant',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                    ),
                    Text(
                      'Convert natural language specifications into structured git actions',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.add_circle_outline),
                  text: 'New Specification',
                ),
                Tab(
                  icon: Icon(Icons.list_alt),
                  text: 'Specifications',
                ),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // New Specification Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: SpecInputForm(
                    onSpecificationCreated: _onSpecificationCreated,
                  ),
                ),

                // Specifications List Tab
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SpecListView(
                        specifications: _specifications,
                        onRefresh: _loadSpecifications,
                        onSpecificationUpdated: _loadSpecifications,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
