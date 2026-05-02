import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import '../models/listing_model.dart';
import 'car_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool isEmbedded;
  const SearchScreen({super.key, this.isEmbedded = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Filter states
  double _minPrice = 0;
  double _maxPrice = 50000;
  bool _withDriverOnly = false;
  bool _insuredOnly = false;
  String? _selectedCity;
  
  List<ListingModel> _filteredListings = [];
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    // Load listings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ListingProvider>();
      provider.loadAllListings().then((_) {
        setState(() {
          _filteredListings = provider.allListings;
        });
      });
    });
    
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final provider = context.read<ListingProvider>();
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredListings = provider.allListings.where((listing) {
        // Text search
        final matchesSearch = query.isEmpty ||
            listing.carName.toLowerCase().contains(query) ||
            listing.brand.toLowerCase().contains(query) ||
            listing.model.toLowerCase().contains(query);
        
        // Price filter
        final matchesPrice = listing.pricePerDay >= _minPrice && 
                            listing.pricePerDay <= _maxPrice;
        
        // Feature filters
        final matchesDriver = !_withDriverOnly || listing.withDriver;
        final matchesInsurance = !_insuredOnly || listing.hasInsurance;
        
        // City filter
        final matchesCity = _selectedCity == null || 
                           listing.city == _selectedCity;
        
        return matchesSearch && matchesPrice && matchesDriver && 
               matchesInsurance && matchesCity;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _minPrice = 0;
      _maxPrice = 50000;
      _withDriverOnly = false;
      _insuredOnly = false;
      _selectedCity = null;
      _searchController.clear();
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildBody(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Cars'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        // Embedded mode Filter Toggle since no AppBar maps it
        if (widget.isEmbedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                  icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
                  label: Text(_showFilters ? 'Hide Filters' : 'Show Filters'),
                ),
              ],
            ),
          ),
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by car name, brand, or model...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          
          // Filters Section
          if (_showFilters)
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _resetFilters,
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Price Range
                    const Text(
                      'Price Range (PKR/day)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    RangeSlider(
                      values: RangeValues(_minPrice, _maxPrice),
                      min: 0,
                      max: 50000,
                      divisions: 50,
                      labels: RangeLabels(
                        _minPrice.toStringAsFixed(0),
                        _maxPrice.toStringAsFixed(0),
                      ),
                      onChanged: (values) {
                        setState(() {
                          _minPrice = values.start;
                          _maxPrice = values.end;
                        });
                        _performSearch();
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Feature Filters
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('With Driver'),
                          selected: _withDriverOnly,
                          onSelected: (selected) {
                            setState(() {
                              _withDriverOnly = selected;
                            });
                            _performSearch();
                          },
                        ),
                        FilterChip(
                          label: const Text('Insured'),
                          selected: _insuredOnly,
                          onSelected: (selected) {
                            setState(() {
                              _insuredOnly = selected;
                            });
                            _performSearch();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          // Results Count
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${_filteredListings.length} cars found',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Results List
          Expanded(
            child: _filteredListings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No cars found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredListings.length,
                    itemBuilder: (context, index) {
                      final listing = _filteredListings[index];
                      return _SearchResultCard(listing: listing);
                    },
                  ),
          ),
        ],
      );
  }
}

class _SearchResultCard extends StatelessWidget {
  final ListingModel listing;

  const _SearchResultCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CarDetailScreen(listing: listing),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              if (listing.images.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    listing.images.first,
                    width: 100,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car, size: 40),
                ),
              
              const SizedBox(width: 12),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.carName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.year} • ${listing.engineSize}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payments, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'PKR ${listing.pricePerDay.toStringAsFixed(0)}/day',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
