import 'package:carnet_chantier/models.dart';
import 'package:carnet_chantier/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('le tag de type de note affiche son libellé', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Tag.noteType(NoteType.idee))));
    expect(find.text('IDÉE'), findsOneWidget);
  });
}
