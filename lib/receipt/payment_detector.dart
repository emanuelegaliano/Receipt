import '../data/database.dart';
import 'categorizer.dart';

/// Indovina dal testo dello scontrino se si è pagato con carta o contanti.
/// Restituisce null se non ci sono indizi.
AccountKind? detectPaymentKind(String ocrText) {
  final t = ' ${normalizeText(ocrText)} ';
  const card = [
    'PAGAMENTO ELETTRONICO', 'CARTA DI CREDITO', 'CARTA DI DEBITO', 'BANCOMAT', 'PAGOBANCOMAT', ' POS ',
    'VISA', 'MASTERCARD', 'MAESTRO', 'AMEX', 'CREDIT CARD', 'DEBIT CARD', 'CONTACTLESS', 'APPLE PAY', 'GOOGLE PAY',
  ];
  const cash = [' CONTANTI ', ' CONTANTE ', 'PAGAMENTO CONTANTE', ' CASH ', ' TUNAI ', ' RESTO '];
  final isCard = card.any(t.contains);
  final isCash = cash.any(t.contains);
  if (isCard && !isCash) return AccountKind.card;
  if (isCash && !isCard) return AccountKind.cash;
  return null;
}
