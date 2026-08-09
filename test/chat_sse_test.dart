import 'dart:convert';

import 'package:app/features/chat/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<List<int>> _chunks(List<String> parts) async* {
  for (final part in parts) {
    yield utf8.encode(part);
  }
}

void main() {
  group('parseSseEvents', () {
    test('parses a complete multi-event stream delivered as one chunk', () async {
      const raw =
          'data: {"type":"tool","name":"get_sales_summary"}\n\n'
          'data: {"type":"token","text":"ยอดขาย"}\n\n'
          'data: {"type":"done","message_id":"m1","conversation_id":"c1"}\n\n';
      final events = await parseSseEvents(_chunks([raw])).toList();

      expect(events, hasLength(3));
      expect((events[0] as ChatToolEvent).name, 'get_sales_summary');
      expect((events[1] as ChatTokenEvent).text, 'ยอดขาย');
      final done = events[2] as ChatDoneEvent;
      expect(done.messageId, 'm1');
      expect(done.conversationId, 'c1');
    });

    test('reassembles a JSON line split mid-frame across chunks', () async {
      // The transport can cut a chunk anywhere, including mid-JSON — this is
      // the classic SSE bug: naive per-chunk decoding would try (and fail)
      // to json-decode a half line like 'data: {"typ'.
      const line = 'data: {"type":"token","text":"สวัสดี"}\n';
      final splitPoint = line.indexOf('token');
      final events = await parseSseEvents(
        _chunks([line.substring(0, splitPoint), line.substring(splitPoint)]),
      ).toList();

      expect(events, hasLength(1));
      expect((events.single as ChatTokenEvent).text, 'สวัสดี');
    });

    test('reassembles a multi-byte UTF-8 character split at the byte level', () async {
      const line = 'data: {"type":"token","text":"กาแฟ"}\n';
      final bytes = utf8.encode(line);
      // Cut in the middle of "กาแฟ"'s UTF-8 encoding (Thai characters are
      // 3 bytes each) — not on a line boundary, or even a character one.
      final cut = bytes.length - 5;
      final events = await parseSseEvents(
        Stream.fromIterable([bytes.sublist(0, cut), bytes.sublist(cut)]),
      ).toList();

      expect(events, hasLength(1));
      expect((events.single as ChatTokenEvent).text, 'กาแฟ');
    });

    test('parses an action_proposed event', () async {
      const raw =
          'data: {"type":"action_proposed","action_id":"a1","action_type":"stock_adjust",'
          '"summary":"จะปรับสต็อกกาแฟ +10 ชิ้น (purchase) ยืนยันไหมครับ"}\n\n';
      final events = await parseSseEvents(_chunks([raw])).toList();

      expect(events, hasLength(1));
      final proposed = events.single as ChatActionProposedEvent;
      expect(proposed.actionId, 'a1');
      expect(proposed.actionType, 'stock_adjust');
      expect(proposed.summary, 'จะปรับสต็อกกาแฟ +10 ชิ้น (purchase) ยืนยันไหมครับ');
    });

    test('ignores keep-alive comment lines and blank lines', () async {
      const raw = ': keep-alive\n\ndata: {"type":"token","text":"ok"}\n\n';
      final events = await parseSseEvents(_chunks([raw])).toList();
      expect(events, hasLength(1));
      expect((events.single as ChatTokenEvent).text, 'ok');
    });

    test('throws on an unknown event type', () {
      const raw = 'data: {"type":"mystery"}\n\n';
      expect(parseSseEvents(_chunks([raw])).toList(), throwsFormatException);
    });
  });
}
