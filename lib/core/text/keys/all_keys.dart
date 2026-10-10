import '../text_key.dart';
import 'orders_after_collection.dart';

/// Every key the app declares, by catalogue. The manifest test reads this list; a stage adds
/// its catalogue here (backend spec 019 R14).
const List<TextKey> allTextKeys = [
  ...OrdersAfterCollectionKeys.all,
];
