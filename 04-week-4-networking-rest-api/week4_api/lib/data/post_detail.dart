import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/post.dart';
import 'paged_posts.dart';
import 'providers.dart';

class PostDetailNotifier extends AsyncNotifier<Post> {
  PostDetailNotifier(this.postId);

  final int postId;

  @override
  Future<Post> build() async {
    // Pakai data dari list yang sudah dimuat (paged/non-paged) agar
    // tidak perlu request ulang saat dibuka dari halaman list.
    final cached = _findCachedPost();
    if (cached != null) return cached;
    // Dibuka langsung (mis. deep link): ambil via repository.
    final repository = ref.watch(postRepositoryProvider);
    return repository.fetchPost(postId);
  }

  Post? _findCachedPost() {
    for (final post in ref.read(pagedPostsProvider).items) {
      if (post.id == postId) return post;
    }
    final listPosts = ref.read(postListProvider).value;
    if (listPosts != null) {
      for (final post in listPosts) {
        if (post.id == postId) return post;
      }
    }
    return null;
  }
}

final postDetailProvider =
    AsyncNotifierProvider.family<PostDetailNotifier, Post, int>(
        PostDetailNotifier.new,
        retry: (retryCount, error) => null);