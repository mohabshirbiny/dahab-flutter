import '../models/piece.dart';

/// `ITEMS` from the prototype, extended with enough fields to search and
/// filter on.
const mockPieces = <Piece>[
  Piece(id: 'p1', title: 'Gold ring, 21K', price: 58200, karat: 21, weight: 8.00, kind: 'ring', specLine: '21K, 8.00 g', feeLine: 'Making charge 250 per gram', makingPerGram: 250),
  Piece(
    id: 'p2',
    title: 'Gold bracelet, 18K',
    price: 32270,
    karat: 18,
    weight: 5.20,
    kind: 'bracelet',
    specLine: '18K, 5.20 g',
    feeLine: 'Making charge 180 per gram',
    makingPerGram: 180,
    mine: true,
  ),
  Piece(
    id: 'p3',
    title: 'Gold bangle, 21K',
    price: 253050,
    karat: 21,
    weight: 30.00,
    kind: 'bangle',
    specLine: '21K, 30.00 g',
    feeLine: 'Making charge 400 per gram',
    makingPerGram: 400,
  ),
  Piece(
    id: 'p4',
    title: 'Earrings with stones',
    price: 80150,
    karat: 21,
    weight: 6.10,
    kind: 'earrings',
    specLine: '21K gold and diamond, 6.10 g',
    feeLine: 'Set price',
    hasStones: true,
  ),
  Piece(
    id: 'p5',
    title: 'Gold necklace, 21K',
    price: 92240,
    karat: 21,
    weight: 12.40,
    kind: 'necklace',
    specLine: '21K, 12.40 g',
    feeLine: 'Making charge 300 per gram',
    makingPerGram: 300,
    mine: true,
  ),
  Piece(
    id: 'p6',
    title: 'Gold chain, 21K',
    price: 45900,
    karat: 21,
    weight: 6.30,
    kind: 'chain',
    specLine: '21K, 6.30 g',
    feeLine: 'Making charge 220 per gram',
    makingPerGram: 220,
  ),
];

/// The piece the prototype's detail screen shows.
final mockPieceDetail = PieceDetail(
  piece: mockPieces.first,
  photoCount: 5,
  views: 312,
  requests: 2,
  daysListed: 12,
  queueAhead: 2,
  goldRate: 6975,
  goldValue: 55800,
  makingValue: 2000,
  commission: 400,
  deposit: 11640,
  origin: 'Italian',
  description: 'Worn a few times and kept in its box. Small scratch on the inner band, visible in the third photo. Bought in 2021, original receipt available.',
  sellerName: 'Seller 4417',
);

/// Detail for any piece. The gold ring uses the prototype's exact numbers;
/// the others are derived the same way (pay rate × weight + making charge +
/// commission, 20% deposit).
PieceDetail mockDetailFor(String id) {
  if (id == mockPieceDetail.piece.id) return mockPieceDetail;
  final piece = mockPieces.firstWhere((p) => p.id == id, orElse: () => mockPieces.first);
  const payRates = {18: 5982, 21: 6975, 24: 7968};
  final rate = payRates[piece.karat]!;
  final gold = (rate * piece.weight).round();
  final making = ((piece.makingPerGram ?? 0) * piece.weight).round();
  return PieceDetail(
    piece: piece,
    photoCount: 4,
    views: 96 + piece.price % 200,
    requests: piece.price % 3,
    daysListed: 3 + piece.price % 11,
    queueAhead: 1,
    goldRate: rate,
    goldValue: gold,
    makingValue: making,
    commission: piece.price - gold - making,
    deposit: (piece.price * 0.2).round(),
    origin: 'Egyptian',
    description: 'Kept in its box and worn on special occasions. No repairs. Original invoice available.',
    sellerName: 'Seller 2210',
  );
}

/// Saved pieces shown on the Saved screen (`ITEMS.slice(1,3)`).
final mockSavedPieceIds = ['p2', 'p3'];
