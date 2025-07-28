// This is a Flutter widget test for the Income & Expense Tracker app.
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:income_expense_app/main.dart';

void main() {
  testWidgets('Expense Tracker app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ExpenseTrackerApp());

    // Verify that the app title is displayed
    expect(find.text('Expense Tracker'), findsOneWidget);

    // Verify that the initial balance is $0.00
    expect(find.text('\$0.00'), findsWidgets);

    // Verify that the "No transactions yet" message is displayed
    expect(find.text('No transactions yet'), findsOneWidget);

    // Verify that the floating action button is present
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Add transaction modal opens when FAB is tapped', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ExpenseTrackerApp());

    // Tap the floating action button
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify that the modal is opened
    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
  });

  testWidgets('Can switch between Income and Expense in modal', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ExpenseTrackerApp());

    // Open the add transaction modal
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Initially should be on Income (assuming Income is default)
    // Tap on Expense
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();

    // Should now show expense categories
    expect(find.text('Food'), findsOneWidget);

    // Switch back to Income
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // Should now show income categories
    expect(find.text('Salary'), findsOneWidget);
  });

  testWidgets('Can add a transaction', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ExpenseTrackerApp());

    // Open the add transaction modal
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Fill in the form
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Test Expense');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '50.00');

    // Make sure it's set to Expense
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();

    // Submit the transaction
    await tester.tap(find.text('Add Transaction'));
    await tester.pumpAndSettle();

    // Verify the transaction was added
    expect(find.text('Test Expense'), findsOneWidget);
    expect(find.text('-\$50.00'), findsOneWidget);

    // Verify balance updated
    expect(find.text('\$-50.00'), findsOneWidget);
  });

  testWidgets('Can delete a transaction', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ExpenseTrackerApp());

    // Add a transaction first
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Test Transaction');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '25.00');
    await tester.tap(find.text('Add Transaction'));
    await tester.pumpAndSettle();

    // Verify transaction exists
    expect(find.text('Test Transaction'), findsOneWidget);

    // Delete the transaction
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Verify transaction was deleted
    expect(find.text('Test Transaction'), findsNothing);
    expect(find.text('No transactions yet'), findsOneWidget);
  });
}