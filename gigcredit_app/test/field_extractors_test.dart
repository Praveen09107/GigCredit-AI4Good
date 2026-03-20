import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/field_extractors.dart';
import 'package:gigcredit_app/models/enums/document_type.dart';

void main() {
  group('FieldExtractors utility parsing', () {
    test('extracts TANGEDCO electricity receipt fields', () {
      const text =
          'Tamil Nadu Power Distribution Corporation Limited E-Receipt '
          'Name : RAKIMMA BEEVI '
          'S.C.Number: 0119400742 '
          'Receipt No : PGIBP2801862359 '
          'Date : 05/11/2025 23:27:40 '
          'S.NO Bill Details 23100-CC Charges 905.00 Total 905.00';

      final parsed = FieldExtractors.parse(DocumentType.electricityBill, text);

      expect(parsed.isValid, isTrue);
      expect(parsed.fields['consumer_number'], '0119400742');
      expect(parsed.fields['bill_amount'], '905.00');
      expect(parsed.fields['bill_date'], '05/11/2025');
    });

    test('extracts LPG invoice fields from sample format', () {
      const text =
          'PADMA GAS SERVICES (0000117615) '
          'Order Date 15/02/2026 11:21:42 '
          'Tax Invoice Date 15/02/2026 11:21:44 '
          'Consumer No 31211 '
          'Consumer Category Domestic '
          'Final Price 868.5 '
          'Amount Paid ( Cash ) 868.5';

      final parsed = FieldExtractors.parse(DocumentType.lpgBill, text);

      expect(parsed.isValid, isTrue);
      expect(parsed.fields['consumer_id'], '31211');
      expect(parsed.fields['amount'], '868.5');
      expect(parsed.fields['delivery_date'], '15/02/2026');
      expect((parsed.fields['provider'] ?? '').toUpperCase(), contains('PADMA GAS SERVICES'));
    });
  });

  group('FieldExtractors bank statement parsing', () {
    test('extracts account, ifsc and transactions from axis-like OCR text', () {
      const text =
          'Customer ID :970069607 '
          'IFSC Code :UTIB0000345 '
          '16-07-2025 UPI/P2A/519739896895/SHANTHI /State Ban/UPI/ 200.00 204.03 345 '
          '16-07-2025 UPI/P2M/556340591698/Mr Gokul Pandi M /UPI/YES BANK LIMITED YBS 44.00 160.03 345 '
          '17-07-2025 UPI/P2M/556405213888/M S K PROTEINS /UPI/HDFC BANK LTD 180.00 30.03 345';

      final parsed = FieldExtractors.parse(DocumentType.bankStatement, text);

      expect(parsed.isValid, isTrue);
      expect(parsed.fields['ifsc'], 'UTIB0000345');
      expect(int.parse(parsed.fields['transaction_count'] ?? '0') > 0, isTrue);
      expect((parsed.fields['transactions_json'] ?? ''), isNotEmpty);
    });
  });
}
