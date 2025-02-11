import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BlogDetailScreen extends StatefulWidget {
  final Map<String, dynamic> blog;
  final String blogId;

  const BlogDetailScreen({
    super.key,
    required this.blog,
    required this.blogId,
  });

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeLikeStatus();
  }

  Future<void> _initializeLikeStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get like status
      final likedByDoc = await FirebaseFirestore.instance
          .collection('blogs')
          .doc(widget.blogId)
          .collection('likedBy')
          .doc(user.uid)
          .get();

      // Get like count
      final blogDoc = await FirebaseFirestore.instance
          .collection('blogs')
          .doc(widget.blogId)
          .get();

      if (mounted) {
        setState(() {
          _isLiked = likedByDoc.exists;
          _likeCount = blogDoc.data()?['likes'] ?? 0;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like blogs')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final blogRef = FirebaseFirestore.instance
          .collection('blogs')
          .doc(widget.blogId);
      
      final likedByRef = blogRef
          .collection('likedBy')
          .doc(user.uid);

      if (_isLiked) {
        // Unlike
        await likedByRef.delete();
        await blogRef.update({
          'likes': FieldValue.increment(-1),
        });
        setState(() {
          _isLiked = false;
          _likeCount--;
        });
      } else {
        // Like
        await likedByRef.set({
          'timestamp': FieldValue.serverTimestamp(),
        });
        await blogRef.update({
          'likes': FieldValue.increment(1),
        });
        setState(() {
          _isLiked = true;
          _likeCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.blog['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: widget.blog['imageUrl'] != null ? 300.0 : 0.0,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.blog['imageUrl'] != null
                  ? Image.network(
                      widget.blog['imageUrl'],
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.blog['title']?.toString() ?? 'Untitled',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          (widget.blog['authorName']?[0] ?? 'A').toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.blog['authorName']?.toString() ?? 'Anonymous',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('MMMM d, yyyy').format(date),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    widget.blog['content']?.toString() ?? 'No content available',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.blog['views']?.toString() ?? '0'} views',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: Icon(
                                    _isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: _isLiked ? Colors.red : Colors.grey[600],
                                  ),
                                  onPressed: _toggleLike,
                                ),
                          Text(
                            '$_likeCount likes',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 