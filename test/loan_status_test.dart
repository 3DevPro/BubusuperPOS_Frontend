import 'package:app/features/turbo/loan_status_screen.dart';
import 'package:app/features/turbo/turbo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

LoanApplicationEventDto _event({String? from, required String to}) => LoanApplicationEventDto(
  id: 'e',
  fromStatus: from,
  toStatus: to,
  actorName: '-',
  actorKind: 'system',
  note: null,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('isTerminalLoanStatus', () {
    test('approved/rejected/disbursed are terminal — nothing moves them without a user action', () {
      for (final status in ['approved', 'rejected', 'disbursed']) {
        expect(isTerminalLoanStatus(status), isTrue, reason: status);
      }
    });

    test('every review stage keeps polling', () {
      for (final status in ['submitted', 'doc_review', 'collateral_check', 'under_review']) {
        expect(isTerminalLoanStatus(status), isFalse, reason: status);
      }
    });
  });

  group('isReviewInProgress', () {
    test('true only for the 4 stages the clock can still move', () {
      for (final status in ['submitted', 'doc_review', 'collateral_check', 'under_review']) {
        expect(isReviewInProgress(status), isTrue, reason: status);
      }
    });

    test('false for approved/rejected/disbursed', () {
      for (final status in ['approved', 'rejected', 'disbursed']) {
        expect(isReviewInProgress(status), isFalse, reason: status);
      }
    });
  });

  group('reachedIndexAtRejection', () {
    test('rejected straight from submitted only reaches index 0', () {
      final events = [_event(to: 'submitted'), _event(from: 'submitted', to: 'rejected')];
      expect(reachedIndexAtRejection(events), 0);
    });

    test('rejected from doc_review reaches index 1 (doc_review)', () {
      final events = [
        _event(to: 'submitted'),
        _event(from: 'submitted', to: 'doc_review'),
        _event(from: 'doc_review', to: 'rejected'),
      ];
      expect(reachedIndexAtRejection(events), 1);
    });

    test('rejected from under_review reaches index 3', () {
      final events = [
        _event(to: 'submitted'),
        _event(from: 'submitted', to: 'doc_review'),
        _event(from: 'doc_review', to: 'collateral_check'),
        _event(from: 'collateral_check', to: 'under_review'),
        _event(from: 'under_review', to: 'rejected'),
      ];
      expect(reachedIndexAtRejection(events), 3);
    });
  });

  test('forwardLoanStages is the 5-step path the timeline renders, in order', () {
    expect(forwardLoanStages, ['submitted', 'doc_review', 'collateral_check', 'under_review', 'approved']);
  });
}
