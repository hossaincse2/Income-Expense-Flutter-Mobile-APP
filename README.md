# Expense Tracker App

A beautiful and intuitive Flutter application for tracking personal income and expenses with advanced filtering capabilities and smooth animations.

## 📱 Features

### Core Functionality
- **Add Transactions**: Record income and expenses with customizable categories
- **Balance Tracking**: Real-time calculation of current balance (income - expenses)
- **Transaction Management**: View, filter, and delete transactions
- **Cross-Platform**: Works on both mobile devices and web browsers

### Advanced Features
- **Smart Filtering**: Filter transactions by type (income/expense), category, and date range
- **Multiple Categories**:
    - Income: Salary, Freelance, Business, Investment, Other Income
    - Expense: Food, Transportation, Shopping, Bills, Entertainment, Healthcare, Education, Other
- **Date Range Selection**: Filter transactions within specific time periods
- **Monthly Statistics**: Track current month's income, expenses, and transaction count

### User Experience
- **Smooth Animations**: Fade and slide transitions for enhanced user experience
- **Modern UI**: Clean, gradient-based design with card layouts
- **Responsive Design**: Adapts to different screen sizes and orientations
- **Empty States**: Helpful messages when no transactions are found
- **Filter Chips**: Quick access to common filter options

## 🛠️ Technical Stack

- **Framework**: Flutter
- **Database**: SQLite (mobile) / In-memory storage (web)
- **State Management**: StatefulWidget with setState
- **Architecture**: Clean separation between UI and data layers
- **Animations**: Flutter's built-in animation system with AnimationController

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point and main app configuration
├── models/
│   └── Transaction          # Transaction data model
├── database/
│   └── DatabaseHelper       # Database operations and web storage fallback
├── screens/
│   └── HomeScreen          # Main screen with transaction list and stats
└── widgets/
    ├── AddTransactionModal # Modal for adding new transactions
    └── FilterModal         # Modal for filtering transactions
```

## 📋 Prerequisites

Before running this application, ensure you have:

- Flutter SDK (3.0 or higher)
- Dart SDK (2.17 or higher)
- Android Studio / VS Code with Flutter extensions
- For mobile: Android emulator or iOS simulator
- For web: Chrome browser

## 🚀 Installation & Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd expense-tracker-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**

   For mobile:
   ```bash
   flutter run
   ```

   For web:
   ```bash
   flutter run -d chrome
   ```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0        # SQLite database for mobile
  path: ^1.8.3           # Path manipulation utilities
```

## 🎯 Usage Guide

### Adding Transactions

1. Tap the **"Add Transaction"** floating action button
2. Choose between **Income** or **Expense**
3. Enter transaction details:
    - Title/Description
    - Amount
    - Category (automatically filtered based on income/expense type)
4. Tap **"Add Transaction"** to save

### Filtering Transactions

1. Tap the **filter icon** in the app bar or use the **filter chips**
2. Set your preferences:
    - **Transaction Type**: All, Income, or Expense
    - **Category**: Select from available categories
    - **Date Range**: Choose start and end dates
3. Apply filters to see filtered results

### Managing Transactions

- **View**: All transactions are displayed in a scrollable list
- **Delete**: Tap the delete icon on any transaction card
- **Filter**: Use the filter options to find specific transactions

## 🌐 Platform Compatibility

### Mobile (Android/iOS)
- Uses SQLite database for persistent storage
- Full feature set available
- Optimized touch interactions

### Web
- Uses in-memory storage (data persists during session)
- All features available except persistent storage
- Responsive design for desktop browsers

## 🎨 Design Features

- **Gradient Backgrounds**: Modern blue gradient theme
- **Card-based Layout**: Clean, organized transaction cards
- **Smooth Animations**: Fade-in effects and slide transitions
- **Color-coded Transactions**: Green for income, red for expenses
- **Material Design**: Following Flutter's Material Design principles

## 🔧 Customization

### Adding New Categories

To add new transaction categories, modify the `allCategories` list in `HomeScreen`:

```dart
final List<String> allCategories = [
  'All',
  // Income categories
  'Salary', 'Freelance', 'Business', 'Investment', 'Other Income',
  // Expense categories  
  'Food', 'Transportation', 'Shopping', 'Bills', 'Entertainment',
  'Healthcare', 'Education', 'Other',
  'Your New Category', // Add here
];
```

### Modifying Colors

The app uses a blue theme. To change colors, modify the `ThemeData` in `ExpenseTrackerApp`:

```dart
theme: ThemeData(
  primarySwatch: Colors.blue, // Change primary color
  // ... other theme properties
```

## 🐛 Known Issues

- **Web Storage**: Data is not persistent on web (refreshing the page will clear data)
- **SQLite Web**: SQLite is not supported on web browsers, falls back to in-memory storage

## 🚀 Future Enhancements

- [ ] Data export/import functionality
- [ ] Recurring transactions
- [ ] Budget setting and tracking
- [ ] Charts and visual analytics
- [ ] Multi-currency support
- [ ] Cloud synchronization
- [ ] Transaction categories with icons
- [ ] Receipt photo attachments

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

If you encounter any issues or have questions:

1. Check the existing issues in the repository
2. Create a new issue with detailed description
3. Include screenshots if applicable
4. Specify your Flutter version and platform

---

**Built with ❤️ using Flutter**