import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class gameMain extends StatefulWidget {
  const gameMain({super.key});

  @override
  State<gameMain> createState() => _gameMainState();
}

class _gameMainState extends State<gameMain> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text("data"),
      
    );
  }
}

