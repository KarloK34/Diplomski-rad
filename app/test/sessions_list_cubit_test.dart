import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/blocs/sessions_list/sessions_list_cubit.dart';
import 'package:gait_sense/blocs/sessions_list/sessions_list_state.dart';
import 'package:gait_sense/utils/sessions_filter.dart';

void main() {
  group('SessionsListCubit', () {
    test('starts on the all filters at one page', () {
      final cubit = SessionsListCubit();
      addTearDown(cubit.close);

      expect(cubit.state.period, SessionsPeriodFilter.all);
      expect(cubit.state.activity, SessionsActivityFilter.all);
      expect(cubit.state.visibleCount, sessionsListPageSize);
    });

    test('showMore reveals one more page each call', () {
      final cubit = SessionsListCubit();
      addTearDown(cubit.close);

      cubit.showMore();
      expect(cubit.state.visibleCount, sessionsListPageSize * 2);

      cubit.showMore();
      expect(cubit.state.visibleCount, sessionsListPageSize * 3);
    });

    test('showLess collapses back to the first page', () {
      final cubit = SessionsListCubit()
        ..showMore()
        ..showMore();
      addTearDown(cubit.close);

      cubit.showLess();

      expect(cubit.state.visibleCount, sessionsListPageSize);
    });

    test('setPeriodFilter switches the period and resets reveal depth', () {
      final cubit = SessionsListCubit()..showMore();
      addTearDown(cubit.close);

      cubit.setPeriodFilter(SessionsPeriodFilter.thisWeek);

      expect(cubit.state.period, SessionsPeriodFilter.thisWeek);
      expect(cubit.state.visibleCount, sessionsListPageSize);
    });

    test('setPeriodFilter leaves the activity filter untouched', () {
      final cubit = SessionsListCubit()
        ..setActivityFilter(SessionsActivityFilter.walking);
      addTearDown(cubit.close);

      cubit.setPeriodFilter(SessionsPeriodFilter.thisMonth);

      expect(cubit.state.activity, SessionsActivityFilter.walking);
    });

    test('setPeriodFilter is a no-op when the period is already active', () {
      final cubit = SessionsListCubit()..showMore();
      addTearDown(cubit.close);
      final stateBefore = cubit.state;

      cubit.setPeriodFilter(SessionsPeriodFilter.all);

      expect(cubit.state, same(stateBefore));
    });

    test('setActivityFilter switches the activity and resets reveal depth', () {
      final cubit = SessionsListCubit()..showMore();
      addTearDown(cubit.close);

      cubit.setActivityFilter(SessionsActivityFilter.walking);

      expect(cubit.state.activity, SessionsActivityFilter.walking);
      expect(cubit.state.visibleCount, sessionsListPageSize);
    });

    test('setActivityFilter leaves the period filter untouched', () {
      final cubit = SessionsListCubit()
        ..setPeriodFilter(SessionsPeriodFilter.thisYear);
      addTearDown(cubit.close);

      cubit.setActivityFilter(SessionsActivityFilter.jogging);

      expect(cubit.state.period, SessionsPeriodFilter.thisYear);
    });

    test(
      'setActivityFilter is a no-op when the activity is already active',
      () {
        final cubit = SessionsListCubit()..showMore();
        addTearDown(cubit.close);
        final stateBefore = cubit.state;

        cubit.setActivityFilter(SessionsActivityFilter.all);

        expect(cubit.state, same(stateBefore));
      },
    );
  });
}
