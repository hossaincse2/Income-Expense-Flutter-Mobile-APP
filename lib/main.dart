import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database factory for web
  if (kIsWeb) {
    // For web, we'll use in-memory storage instead of SQLite
    // since SQLite doesn't work on web
  }

  runApp(ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 16, // Smaller font size
            fontWeight: FontWeight.bold,
            color: Colors.white, // White text color
          ),
          toolbarHeight: 48, // Reduced app bar height
          centerTitle: false, // Align left
          elevation: 0, // Remove shadow if desired
        ),
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Transaction {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isIncome;
  final String category;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isIncome,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'isIncome': isIncome ? 1 : 0,
      'category': category,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      isIncome: map['isIncome'] == 1,
      category: map['category'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;
  static List<Transaction> _webTransactions = []; // For web storage

  Future<Database?> get database async {
    if (kIsWeb) {
      return null; // Use in-memory storage for web
    }
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) throw UnsupportedError('SQLite not supported on web');

    String dbPath = path.join(await getDatabasesPath(), 'transactions.db');
    return await openDatabase(dbPath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        isIncome INTEGER NOT NULL,
        category TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertTransaction(Transaction transaction) async {
    if (kIsWeb) {
      final newTransaction = Transaction(
        id: _webTransactions.length + 1,
        title: transaction.title,
        amount: transaction.amount,
        date: transaction.date,
        isIncome: transaction.isIncome,
        category: transaction.category,
      );
      _webTransactions.add(newTransaction);
      return newTransaction.id!;
    }

    final db = await database;
    return await db!.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getTransactions({
    String? category,
    bool? isIncome,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (kIsWeb) {
      List<Transaction> filtered = List.from(_webTransactions);

      if (category != null && category != 'All') {
        filtered = filtered.where((tx) => tx.category == category).toList();
      }

      if (isIncome != null) {
        filtered = filtered.where((tx) => tx.isIncome == isIncome).toList();
      }

      if (startDate != null) {
        filtered = filtered
            .where(
              (tx) => tx.date.isAfter(startDate.subtract(Duration(days: 1))),
            )
            .toList();
      }

      if (endDate != null) {
        filtered = filtered
            .where((tx) => tx.date.isBefore(endDate.add(Duration(days: 1))))
            .toList();
      }

      filtered.sort((a, b) => b.date.compareTo(a.date));
      return filtered;
    }

    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    List<String> conditions = [];

    if (category != null && category != 'All') {
      conditions.add('category = ?');
      whereArgs.add(category);
    }

    if (isIncome != null) {
      conditions.add('isIncome = ?');
      whereArgs.add(isIncome ? 1 : 0);
    }

    if (startDate != null) {
      conditions.add('date >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      conditions.add('date <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')}';
    }

    final List<Map<String, dynamic>> maps = await db!.rawQuery(
      'SELECT * FROM transactions $whereClause ORDER BY date DESC',
      whereArgs,
    );

    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<void> deleteTransaction(int id) async {
    if (kIsWeb) {
      _webTransactions.removeWhere((tx) => tx.id == id);
      return;
    }

    final db = await database;
    await db!.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getMonthlyStats() async {
    if (kIsWeb) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final monthlyTransactions = _webTransactions
          .where(
            (tx) =>
                tx.date.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
                tx.date.isBefore(endOfMonth.add(Duration(days: 1))),
          )
          .toList();

      double totalIncome = monthlyTransactions
          .where((tx) => tx.isIncome)
          .fold(0.0, (sum, tx) => sum + tx.amount);
      double totalExpense = monthlyTransactions
          .where((tx) => !tx.isIncome)
          .fold(0.0, (sum, tx) => sum + tx.amount);

      return {'totalIncome': totalIncome, 'totalExpense': totalExpense};
    }

    final db = await database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final result = await db!.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN isIncome = 1 THEN amount ELSE 0 END) as totalIncome,
        SUM(CASE WHEN isIncome = 0 THEN amount ELSE 0 END) as totalExpense
      FROM transactions 
      WHERE date >= ? AND date <= ?
    ''',
      [startOfMonth.millisecondsSinceEpoch, endOfMonth.millisecondsSinceEpoch],
    );

    return {
      'totalIncome': (result.first['totalIncome'] as num?)?.toDouble() ?? 0.0,
      'totalExpense': (result.first['totalExpense'] as num?)?.toDouble() ?? 0.0,
    };
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();

}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Transaction> transactions = [];
  List<Transaction> filteredTransactions = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String selectedCategory = 'All';
  String selectedType = 'All'; // All, Income, Expense
  DateTimeRange? selectedDateRange;

  double totalIncome = 0.0;
  double totalExpense = 0.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> allCategories = [
    'All',
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Food',
    'Transportation',
    'Shopping',
    'Bills',
    'Entertainment',
    'Healthcare',
    'Education',
    'Other Income',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadTransactions();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get balance => totalIncome - totalExpense;

  Future<void> _loadTransactions() async {
    bool? isIncomeFilter;
    if (selectedType == 'Income') isIncomeFilter = true;
    if (selectedType == 'Expense') isIncomeFilter = false;

    final loadedTransactions = await _dbHelper.getTransactions(
      category: selectedCategory,
      isIncome: isIncomeFilter,
      startDate: selectedDateRange?.start,
      endDate: selectedDateRange?.end,
    );

    final allTransactions = await _dbHelper.getTransactions();

    setState(() {
      transactions = allTransactions;
      filteredTransactions = loadedTransactions;
      totalIncome = transactions
          .where((tx) => tx.isIncome)
          .fold(0.0, (sum, tx) => sum + tx.amount);
      totalExpense = transactions
          .where((tx) => !tx.isIncome)
          .fold(0.0, (sum, tx) => sum + tx.amount);
    });
  }

  void _addTransaction(
    String title,
    double amount,
    bool isIncome,
    String category,
  ) async {
    final newTx = Transaction(
      title: title,
      amount: amount,
      date: DateTime.now(),
      isIncome: isIncome,
      category: category,
    );

    await _dbHelper.insertTransaction(newTx);
    _loadTransactions();
  }

  void _deleteTransaction(int id) async {
    await _dbHelper.deleteTransaction(id);
    _loadTransactions();
  }

  void _showAddTransactionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionModal(_addTransaction),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FilterModal(
        selectedCategory: selectedCategory,
        selectedType: selectedType,
        selectedDateRange: selectedDateRange,
        categories: allCategories,
        onApplyFilter: (category, type, dateRange) {
          setState(() {
            selectedCategory = category;
            selectedType = type;
            selectedDateRange = dateRange;
          });
          _loadTransactions();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 50,
            collapsedHeight: 50,
            floating: false,
            pinned: true,
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            title: Text(
              'Expense Tracker',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 6.0,
                    color: Colors.black45,
                    offset: Offset(1.5, 1.5),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: Icon(Icons.filter_list, size: 22),
                  onPressed: _showFilterModal,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            toolbarHeight: 50,
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildBalanceCard(),
                  _buildFilterChips(),
                  _buildQuickStats(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    '${filteredTransactions.length} items',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          filteredTransactions.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final tx = filteredTransactions[index];
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Interval(
                                (index / filteredTransactions.length) * 0.5,
                                ((index + 1) / filteredTransactions.length) *
                                        0.5 +
                                    0.5,
                                curve: Curves.easeOut,
                              ),
                            ),
                          ),
                      child: _buildTransactionCard(tx),
                    );
                  }, childCount: filteredTransactions.length),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionModal,
        icon: Icon(Icons.add),
        label: Text('Add Transaction'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Current Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '\$${balance.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Income',
                totalIncome,
                Colors.green,
                Icons.trending_up,
              ),
              Container(height: 40, width: 1, color: Colors.white24),
              _buildSummaryItem(
                'Expense',
                totalExpense,
                Colors.red,
                Icons.trending_down,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('All Types', selectedType == 'All', () {
            setState(() => selectedType = 'All');
            _loadTransactions();
          }),
          _buildFilterChip('Income', selectedType == 'Income', () {
            setState(() => selectedType = 'Income');
            _loadTransactions();
          }),
          _buildFilterChip('Expense', selectedType == 'Expense', () {
            setState(() => selectedType = 'Expense');
            _loadTransactions();
          }),
          if (selectedDateRange != null)
            _buildFilterChip('Date Range', true, () {
              setState(() => selectedDateRange = null);
              _loadTransactions();
            }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue[600],
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue[600] : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'This Month',
              '\$${(totalIncome - totalExpense).toStringAsFixed(0)}',
              Icons.calendar_today,
              Colors.purple,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Transactions',
              '${transactions.length}',
              Icons.receipt_long,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Text(
          "\$${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          ),
          SizedBox(height: 24),
          Text(
            'No transactions found',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first transaction or adjust filters',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction tx) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Add transaction details view
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tx.isIncome ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tx.isIncome ? Icons.trending_up : Icons.trending_down,
                    color: tx.isIncome ? Colors.green[600] : Colors.red[600],
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tx.category,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,  // Aligns content to the right
                    crossAxisAlignment: CrossAxisAlignment.center,  // Centers vertically
                    children: [
                      // Amount Text
                      Text(
                        "${tx.isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: tx.isIncome ? Colors.green[600] : Colors.red[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      // Delete Icon (with proper spacing)
                      SizedBox(width: 8),  // Adds spacing between text and icon
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                        onPressed: () => _deleteTransaction(tx.id!),
                        constraints: BoxConstraints(),  // Removes default padding
                        padding: EdgeInsets.zero,      // Removes internal padding
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FilterModal extends StatefulWidget {
  final String selectedCategory;
  final String selectedType;
  final DateTimeRange? selectedDateRange;
  final List<String> categories;
  final Function(String, String, DateTimeRange?) onApplyFilter;

  FilterModal({
    required this.selectedCategory,
    required this.selectedType,
    required this.selectedDateRange,
    required this.categories,
    required this.onApplyFilter,
  });

  @override
  _FilterModalState createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  late String _selectedCategory;
  late String _selectedType;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedType = widget.selectedType;
    _selectedDateRange = widget.selectedDateRange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Transactions',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 20),

          Text(
            'Transaction Type',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['All', 'Income', 'Expense'].map((type) {
              return ChoiceChip(
                label: Text(type),
                selected: _selectedType == type,
                onSelected: (selected) {
                  setState(() => _selectedType = type);
                },
              );
            }).toList(),
          ),

          SizedBox(height: 20),
          Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: widget.categories.map((category) {
              return DropdownMenuItem(value: category, child: Text(category));
            }).toList(),
            onChanged: (value) => setState(() => _selectedCategory = value!),
          ),

          SizedBox(height: 20),
          Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.date_range),
            label: Text(
              _selectedDateRange == null
                  ? 'Select Date Range'
                  : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
            ),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _selectedDateRange,
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
              }
            },
          ),

          if (_selectedDateRange != null)
            TextButton(
              onPressed: () => setState(() => _selectedDateRange = null),
              child: Text('Clear Date Range'),
            ),

          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'All';
                      _selectedType = 'All';
                      _selectedDateRange = null;
                    });
                  },
                  child: Text('Clear All'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApplyFilter(
                      _selectedCategory,
                      _selectedType,
                      _selectedDateRange,
                    );
                    Navigator.pop(context);
                  },
                  child: Text('Apply Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddTransactionModal extends StatefulWidget {
  final Function(String, double, bool, String) addTransaction;

  AddTransactionModal(this.addTransaction);

  @override
  _AddTransactionModalState createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isIncome = false;
  String _selectedCategory = 'Food';

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Other Income',
  ];

  final List<String> _expenseCategories = [
    'Food',
    'Transportation',
    'Shopping',
    'Bills',
    'Entertainment',
    'Healthcare',
    'Education',
    'Other',
  ];

  List<String> get _categories =>
      _isIncome ? _incomeCategories : _expenseCategories;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateCategoryOnToggle(bool isIncome) {
    setState(() {
      _isIncome = isIncome;
      _selectedCategory = isIncome
          ? _incomeCategories[0]
          : _expenseCategories[0];
    });
  }

  void _submitData() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text);

    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter valid title and amount'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.addTransaction(title, amount, _isIncome, _selectedCategory);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _slideAnimation.value) * 300),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Transaction',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Income/Expense Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _updateCategoryOnToggle(true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _isIncome
                                  ? Colors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  color: _isIncome
                                      ? Colors.white
                                      : Colors.grey[600],
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Income',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isIncome
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _updateCategoryOnToggle(false),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: !_isIncome
                                  ? Colors.red
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.trending_down,
                                  color: !_isIncome
                                      ? Colors.white
                                      : Colors.grey[600],
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Expense',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !_isIncome
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Transaction Title',
                    hintText: 'Enter transaction description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: Icon(Icons.description_outlined),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),

                SizedBox(height: 16),

                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: Icon(Icons.attach_money),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),

                SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _categories.contains(_selectedCategory)
                      ? _selectedCategory
                      : _categories[0],
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: Icon(Icons.category_outlined),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),

                SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submitData,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 20),
                            SizedBox(width: 8),
                            Text('Add Transaction'),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isIncome
                              ? Colors.green
                              : Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
