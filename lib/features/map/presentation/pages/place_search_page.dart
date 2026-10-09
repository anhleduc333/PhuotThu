import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/place_search_providers.dart';
import '../../domain/place_result.dart';

class PlaceSearchPage extends ConsumerStatefulWidget {
  const PlaceSearchPage({super.key});

  @override
  ConsumerState<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends ConsumerState<PlaceSearchPage> {
  final _searchController = TextEditingController();

  List<PlaceResult> _results = const [];

  bool _isSearching = false;

  String? _message;

  Future<void> _search() async {
    if (_isSearching) {
      return;
    }

    final query = _searchController.text.trim();

    if (query.length < 2) {
      setState(() {
        _message = 'Nhập ít nhất 2 ký tự để tìm kiếm.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _message = null;
    });

    try {
      final results = await ref
          .read(placeSearchServiceProvider)
          .searchPlaces(query);

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;

        if (results.isEmpty) {
          _message = 'Không tìm thấy địa điểm phù hợp.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _results = const [];
        _message =
            'Không thể tìm kiếm địa điểm. '
            'Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _selectPlace(PlaceResult place) {
    context.pop<PlaceResult>(place);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm địa điểm')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        labelText: 'Tên địa điểm',
                        hintText: 'Ví dụ: Hồ Hoàn Kiếm',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        _search();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSearching ? null : _search,
                    child: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tìm'),
                  ),
                ],
              ),
            ),

            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!, textAlign: TextAlign.center),
              ),

            Expanded(
              child: _results.isEmpty
                  ? const _InitialSearchView()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (context, index) {
                        return const Divider();
                      },
                      itemBuilder: (context, index) {
                        final place = _results[index];

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.location_on_outlined),
                          ),
                          title: Text(place.name),
                          subtitle: Text(
                            place.displayName,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _selectPlace(place);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialSearchView extends StatelessWidget {
  const _InitialSearchView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore, size: 64),
            SizedBox(height: 16),
            Text(
              'Tìm địa điểm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Nhập tên địa điểm, địa danh hoặc '
              'địa chỉ rồi bấm Tìm.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
