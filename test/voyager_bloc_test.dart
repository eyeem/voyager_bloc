import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voyager/voyager.dart';

import 'package:voyager_bloc/voyager_bloc.dart';

class ParentBloc extends Bloc {

  ParentBloc() : super(null);

  @override
  Stream mapEventToState(event) {
    return event;
  }
}

class StrangerBloc extends Bloc {

  StrangerBloc() : super(null);

  @override
  Stream mapEventToState(event) {
    return event;
  }
}

class ChildBloc extends ParentBloc {

  ChildBloc() : super();


  @override
  Stream mapEventToState(event) {
    return event;
  }
}

class CounterBloc extends Bloc {
  final int? initialValue;

  CounterBloc({this.initialValue}) : super(initialValue);

  @override
  Stream mapEventToState(event) {
    return event;
  }
}

void main() {
  late VoyagerContext mockVoyagerContext;

  setUp(() {
    mockVoyagerContext = VoyagerContext(path: '', params: {}, router: VoyagerRouter());
  });

  test('bloc builder basic API', () {
    final builder = BlocsPluginBuilder()
        .addBaseBloc<ParentBloc>((context, config, repository) => ParentBloc())
        .addBaseBloc<CounterBloc>((context, config, repository) =>
            CounterBloc(initialValue: int.parse(config.toString())))
        .addBloc<ChildBloc, ParentBloc>(
            (context, config, repository) => ChildBloc())
        .addBaseBloc<StrangerBloc>(
            (context, config, repository) => StrangerBloc());

    final blocPlugin = builder.build();

    final output = Voyager(config: {}, path: "", pathParams: {});
    blocPlugin.outputFor(
        mockVoyagerContext,
        [
          "ParentBloc@mom",
          "ParentBloc@dad",
          "ChildBloc",
          "StrangerBloc",
          {"CounterBloc": 5}
        ],
        output);
    output.lock();
    final blocRepository = output["blocs"];

    expect(blocRepository, isInstanceOf<BlocRepository>());
    final parentBloc = blocRepository.find<ParentBloc>();
    expect(parentBloc, isInstanceOf<ParentBloc>());
    expect(parentBloc, isInstanceOf<ChildBloc>());
    expect(blocRepository.find<ChildBloc>(), isInstanceOf<ChildBloc>());
    expect(blocRepository.find<StrangerBloc>(), isInstanceOf<StrangerBloc>());
    expect(blocRepository.find<ParentBloc>(name: "mom"),
        isInstanceOf<ParentBloc>());
    expect(blocRepository.find<ParentBloc>(name: "dad"),
        isInstanceOf<ParentBloc>());
    expect(blocRepository.find<ChildBloc>(name: "dad"), isNull);

    final counterBloc = blocRepository.find<CounterBloc>();
    expect(counterBloc, isInstanceOf<CounterBloc>());
    expect((counterBloc as CounterBloc).state, 5);

    output.dispose();
  });

  test('bloc builder basic API - errors', () {
    expect(
        () => BlocsPluginBuilder().addBaseBloc(null),
        throwsA(allOf(
            isArgumentError,
            predicate((dynamic e) =>
                e.message ==
                'BlocType must be a subclass of BlocParentType'))));

    expect(
        () => BlocsPluginBuilder().addBloc<ChildBloc, Bloc>(null),
        throwsA(allOf(
            isArgumentError,
            predicate((dynamic e) =>
                e.message == 'BlocParentType must be a subclass of Bloc'))));
  });

  test('bloc too many @@@', () {
    final builder = BlocsPluginBuilder()
        .addBaseBloc<ParentBloc>((context, config, repository) => ParentBloc());

    final blocPlugin = builder.build();

    final output = Voyager(config: {}, path: "", pathParams: {});
    expect(
        () => blocPlugin.outputFor(
            mockVoyagerContext,
            [
              "ParentBloc@@mom",
            ],
            output),
        throwsA(allOf(
            isArgumentError,
            predicate((dynamic e) =>
                e.message == 'Too many @ sings in the key of the Bloc'))));
  });

  test('bloc missing builder', () {
    final builder = BlocsPluginBuilder();

    final blocPlugin = builder.build();

    final output = Voyager(config: {}, path: "", pathParams: {});
    expect(
        () => blocPlugin.outputFor(
            mockVoyagerContext,
            [
              "ParentBloc",
            ],
            output),
        throwsA(allOf(isUnimplementedError,
            predicate((dynamic e) => e.message == 'No bloc builder for ParentBloc'))));
  });

  test('bloc additive builders', () {
    final builderA = BlocsPluginBuilder()
        .addBaseBloc<ParentBloc>((context, config, repository) => ParentBloc())
        .addBaseBloc<CounterBloc>((context, config, repository) =>
            CounterBloc(initialValue: int.parse(config.toString())));

    final builderB = BlocsPluginBuilder()
        .addBloc<ChildBloc, ParentBloc>(
            (context, config, repository) => ChildBloc())
        .addBaseBloc<StrangerBloc>(
            (context, config, repository) => StrangerBloc());

    final builder =
        BlocsPluginBuilder().addBuilder(builderA).addBuilder(builderB);

    final blocPlugin = builder.build();

    final output = Voyager(config: {}, path: "", pathParams: {});
    blocPlugin.outputFor(
        mockVoyagerContext,
        [
          "ParentBloc@mom",
          "ParentBloc@dad",
          "ChildBloc",
          "StrangerBloc",
          {"CounterBloc": 5}
        ],
        output);
    output.lock();
    final blocRepository = output["blocs"];

    expect(blocRepository, isInstanceOf<BlocRepository>());
    final parentBloc = blocRepository.find<ParentBloc>();
    expect(parentBloc, isInstanceOf<ParentBloc>());
    expect(parentBloc, isInstanceOf<ChildBloc>());
    expect(blocRepository.find<ChildBloc>(), isInstanceOf<ChildBloc>());
    expect(blocRepository.find<StrangerBloc>(), isInstanceOf<StrangerBloc>());
    expect(blocRepository.find<ParentBloc>(name: "mom"),
        isInstanceOf<ParentBloc>());
    expect(blocRepository.find<ParentBloc>(name: "dad"),
        isInstanceOf<ParentBloc>());
    expect(blocRepository.find<ChildBloc>(name: "dad"), isNull);

    final counterBloc = blocRepository.find<CounterBloc>();
    expect(counterBloc, isInstanceOf<CounterBloc>());
    expect((counterBloc as CounterBloc).state, 5);

    output.dispose();
  });
}
