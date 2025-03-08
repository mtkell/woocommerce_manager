import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WooCommerce Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthScreen(),
    );
  }
}

class AuthScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("User signed in: ${userCredential.user?.uid}");
    } catch (e) {
      print("Sign-in failed: $e");
    }
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    String role,
    String organization,
    List<Map<String, String>> stores,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'email': email,
        'role': role,
        'organization': organization,
        'stores': stores,
      });
      print("User registered with role: $role in organization: $organization");
    } catch (e) {
      print("Sign-up failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Authentication")),
      body: Center(child: Text("Login and Signup UI")),
    );
  }
}

class ProductScreen extends StatefulWidget {
  @override
  _ProductScreenState createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<dynamic> _products = [];
  String? userRole;
  String? userOrganization;
  List<Map<String, String>>? stores;
  Map<String, String>? selectedStore;

  Future<void> fetchUserDetails() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();
      setState(() {
        userRole = userDoc['role'];
        userOrganization = userDoc['organization'];
        stores = List<Map<String, String>>.from(userDoc['stores']);
        if (stores != null && stores!.isNotEmpty) {
          selectedStore = stores![0];
        }
      });
      fetchProducts();
    }
  }

  Future<void> fetchProducts() async {
    if (selectedStore == null) return;
    final url = Uri.parse(
      '${selectedStore!['woocommerce_url']}/wp-json/wc/v3/products',
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization':
            'Basic ' +
            base64Encode(
              utf8.encode(
                '${selectedStore!['consumer_key']}:${selectedStore!['consumer_secret']}',
              ),
            ),
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _products = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load products');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("WooCommerce Products")),
      body: Column(
        children: [
          if (stores != null)
            DropdownButton<Map<String, String>>(
              value: selectedStore,
              items:
                  stores!.map((store) {
                    return DropdownMenuItem(
                      value: store,
                      child: Text(store['woocommerce_url']!),
                    );
                  }).toList(),
              onChanged: (store) {
                setState(() {
                  selectedStore = store;
                });
                fetchProducts();
              },
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_products[index]['name']),
                  subtitle: Text("Price: \$${_products[index]['price']}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
