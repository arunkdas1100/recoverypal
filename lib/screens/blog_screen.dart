import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'create_blog_screen.dart';
import 'blog_detail_screen.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  String _sortBy = 'latest'; // 'latest' or 'random'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blogs'),
        actions: [
          // Sort dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'latest',
                child: Text('Latest First'),
              ),
              const PopupMenuItem(
                value: 'random',
                child: Text('Random'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _sortBy == 'latest'
            ? FirebaseFirestore.instance
                .collection('blogs')
                .orderBy('timestamp', descending: true)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('blogs')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final blogs = snapshot.data!.docs;
          
          if (blogs.isEmpty) {
            return const Center(
              child: Text('No blogs yet. Be the first to write one!'),
            );
          }

          // If random is selected, shuffle the blogs
          if (_sortBy == 'random') {
            blogs.shuffle();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: blogs.length,
            itemBuilder: (context, index) {
              final blog = blogs[index].data() as Map<String, dynamic>;
              return _BlogCard(
                blog: blog,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BlogDetailScreen(
                      blog: blog,
                      blogId: blogs[index].id,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateBlogScreen()),
          );
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final Map<String, dynamic> blog;
  final VoidCallback onTap;

  const _BlogCard({
    required this.blog,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Safely get timestamp
    final timestamp = blog['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();
    
    // Safely get content preview
    final content = blog['content']?.toString() ?? 'No content';
    final previewLength = min(content.length, 100);
    final contentPreview = content.substring(0, previewLength);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                blog['title']?.toString() ?? 'Untitled',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMMM d, yyyy').format(date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                contentPreview,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (content.length > 100) 
                const Text('...'),
            ],
          ),
        ),
      ),
    );
  }
} 