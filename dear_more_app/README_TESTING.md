# Flutter Testing Guide

## Running Tests

### All Tests
```bash
flutter test
```

### Specific Test File
```bash
flutter test test/services/memory_engine_test.dart
```

### With Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Integration Tests
```bash
flutter test integration_test/app_test.dart
```

### Watch Mode (Auto-run on changes)
```bash
flutter test --watch
```

## Test Structure

```
test/
├── widget_test.dart                 # Main app test
├── models/
│   └── context_snapshot_test.dart   # Data model tests
├── services/
│   ├── memory_engine_test.dart      # Memory engine tests
│   └── feature_extractor_test.dart  # Feature extractor tests
└── ui/
    └── home_screen_test.dart        # Widget tests

integration_test/
└── app_test.dart                    # End-to-end tests
```

## Test Types

### Unit Tests
Test individual functions and classes:
```dart
test('calculates cosine distance correctly', () {
  final engine = MemoryEngine();
  final distance = engine.cosineDistance(v1, v2);
  expect(distance, closeTo(0.0, 0.001));
});
```

### Widget Tests
Test UI components:
```dart
testWidgets('shows status card', (WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: HomeScreen()));
  expect(find.byType(Card), findsWidgets);
});
```

### Integration Tests
Test app workflows:
```dart
testWidgets('can navigate between screens', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Memory'));
  expect(find.text('Memory Bank'), findsOneWidget);
});
```

## Mathematical Verification Tests

Tests verify TDD specifications:

### Genesis Inequality (τ=0.15)
```dart
test('genesis threshold constant is correct', () {
  expect(MemoryEngine.genesisThreshold, 0.15);
});
```

### Hebbian Plasticity (α=0.05)
```dart
test('fast learning rate constant is correct', () {
  expect(MemoryEngine.fastLearningRate, 0.05);
});
```

### L2 Normalization
```dart
test('L2 normalization produces unit vectors', () {
  final normalized = extractor.l2Normalize(vector);
  final magnitude = sqrt(normalized.fold(0.0, (sum, v) => sum + v * v));
  expect(magnitude, closeTo(1.0, 0.001));
});
```

### Z-Score Normalization
```dart
test('applies z-score normalization correctly', () {
  final tensorInput = snapshot.toTensorInput(normStats);
  // (value - mean) / std = (2.0 - 0.0) / 2.0 = 1.0
  expect(tensorInput[0], closeTo(1.0, 0.01));
});
```

## Coverage Requirements

Target: **80%+ code coverage**

Check coverage:
```bash
flutter test --coverage
lcov --summary coverage/lcov.info
```

## Mocking

For tests that require dependencies:
```dart
class MockFeatureExtractor extends Mock implements FeatureExtractor {}

test('uses mocked extractor', () {
  final mock = MockFeatureExtractor();
  when(mock.extractEmbedding(any, any))
    .thenAnswer((_) async => List.filled(64, 0.5));
});
```

## Testing Best Practices

1. **Isolate tests** - Each test should be independent
2. **Use descriptive names** - `test('calculates cosine distance correctly')`
3. **Arrange-Act-Assert** - Set up, execute, verify
4. **Test edge cases** - Zero vectors, empty lists, null values
5. **Verify mathematical correctness** - Use `closeTo()` for floats

## Running on CI/CD

GitHub Actions example:
```yaml
- name: Run Flutter tests
  run: flutter test --coverage

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    files: coverage/lcov.info
```

## Troubleshooting

### Test Timeouts
Increase timeout:
```dart
testWidgets('long test', (tester) async {
  // ...
}, timeout: Timeout(Duration(minutes: 2)));
```

### Widget Not Found
Use `pumpAndSettle()` for async widgets:
```dart
await tester.pumpWidget(MyWidget());
await tester.pumpAndSettle();
```

### Database Tests
For database tests, use in-memory database:
```dart
setUp(() async {
  await AppDatabase.initialize(inMemory: true);
});
```
